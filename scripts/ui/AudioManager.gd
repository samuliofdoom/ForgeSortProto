extends Node

## Fantasy Forge Procedural Audio System
## All sounds generated in-memory using AudioStreamWAV with PCM data

const SAMPLE_RATE := 44100

## Master volume for all sound effects (0.0 to 1.0)
const SOUND_VOLUME := 0.2

# Pour hum state
var _pour_player: AudioStreamPlayer = null
var _pour_volume := 0.0
var _target_pour_volume := 0.0
var _pour_fade_speed := 0.0

func _ready() -> void:
	_connect_to_signals()

func _connect_to_signals() -> void:
	# MetalFlow signals
	var metal_flow = get_node_or_null("/root/MetalFlow")
	if metal_flow:
		if metal_flow.metal_poured.get_connections().is_empty():
			metal_flow.metal_poured.connect(_on_metal_poured)
		if metal_flow.waste_routed.get_connections().is_empty():
			metal_flow.waste_routed.connect(_on_waste_routed)

	# FlowController signals
	var flow_controller = get_node_or_null("/root/FlowController")
	if flow_controller:
		if flow_controller.gate_toggled.get_connections().is_empty():
			flow_controller.gate_toggled.connect(_on_gate_toggled)

	# OrderManager signals
	var order_manager = get_node_or_null("/root/OrderManager")
	if order_manager:
		if order_manager.order_completed.get_connections().is_empty():
			order_manager.order_completed.connect(_on_order_completed)

	# ScoreManager signals
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		if score_manager.game_over.get_connections().is_empty():
			score_manager.game_over.connect(_on_game_over)

	# Connect to mold signals via FlowController
	_connect_mold_signals()

func _connect_mold_signals() -> void:
	var flow_controller = get_node_or_null("/root/FlowController")
	if not flow_controller:
		return
	
	var molds = flow_controller.get_molds()
	for mold in molds.values():
		if mold == null:
			continue
		if not (mold is Node):
			continue
		if not mold.has_signal("mold_filled"):
			continue
		if mold.mold_filled.get_connections().is_empty():
			mold.mold_filled.connect(_on_mold_filled)
		if mold.has_signal("mold_contaminated") and mold.mold_contaminated.get_connections().is_empty():
			mold.mold_contaminated.connect(_on_mold_contaminated)
		if mold.has_signal("mold_completed") and mold.mold_completed.get_connections().is_empty():
			mold.mold_completed.connect(_on_mold_completed)
		if mold.has_signal("part_produced") and mold.part_produced.get_connections().is_empty():
			mold.part_produced.connect(_on_part_produced)

func _process(delta: float) -> void:
	# Handle pour hum fade in/out
	if _pour_player and abs(_pour_volume - _target_pour_volume) > 0.01:
		_pour_volume = move_toward(_pour_volume, _target_pour_volume, _pour_fade_speed * delta)
		_pour_player.volume_db = linear_to_db(_pour_volume)
	# Re-check mold signals each frame to catch dynamically-added molds
	_connect_mold_signals()

# ============================================================================
# Sound Generation Helpers
# ============================================================================

func _create_wav_buffer(samples: PackedFloat32Array, sample_rate: int = SAMPLE_RATE) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s = samples[i]
		s = clamp(s, -1.0, 1.0)
		var i16 = int(s * 32767.0)
		bytes[i * 2] = i16 & 0xFF
		bytes[i * 2 + 1] = (i16 >> 8) & 0xFF
	stream.data = bytes
	stream.mix_rate = sample_rate
	return stream

func _generate_sine_samples(freq: float, duration_s: float, volume: float = 0.5, phase: float = 0.0) -> PackedFloat32Array:
	var num_samples = int(duration_s * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase_inc = freq / SAMPLE_RATE
	var current_phase = phase
	for i in num_samples:
		samples[i] = sin(current_phase * TAU) * volume
		current_phase += phase_inc
	return samples

func _generate_sine_with_vibrato(freq: float, duration_s: float, volume: float = 0.5, vibrato_depth: float = 0.005, vibrato_rate: float = 5.0) -> PackedFloat32Array:
	var num_samples = int(duration_s * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase_inc = freq / SAMPLE_RATE
	var current_phase = 0.0
	for i in num_samples:
		var vibrato = 1.0 + sin(i * vibrato_rate * TAU / SAMPLE_RATE) * vibrato_depth
		samples[i] = sin(current_phase * TAU * vibrato) * volume
		current_phase += phase_inc
	return samples

func _generate_noise_samples(duration_s: float, volume: float = 0.3) -> PackedFloat32Array:
	var num_samples = int(duration_s * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	for i in num_samples:
		samples[i] = randf() * 2.0 - 1.0
		samples[i] *= volume
	return samples

func _generate_noise_burst(duration_s: float, volume: float = 0.3) -> PackedFloat32Array:
	var num_samples = int(duration_s * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	for i in num_samples:
		var t = float(i) / num_samples
		var envelope = exp(-t * 20.0)  # Fast decay
		samples[i] = (randf() * 2.0 - 1.0) * volume * envelope
	return samples

func _generate_envelope(samples: PackedFloat32Array, attack: float = 0.01, decay: float = 0.1, sustain: float = 1.0, release: float = 0.1) -> PackedFloat32Array:
	var num_samples = samples.size()
	var result = PackedFloat32Array()
	result.resize(num_samples)
	
	var attack_samples = int(attack * SAMPLE_RATE)
	var decay_samples = int(decay * SAMPLE_RATE)
	var release_samples = int(release * SAMPLE_RATE)
	var sustain_samples = num_samples - attack_samples - decay_samples - release_samples
	
	var idx = 0
	# Attack
	for i in attack_samples:
		result[idx] = samples[idx] * (float(i) / attack_samples)
		idx += 1
	# Decay
	for i in decay_samples:
		var t = float(i) / decay_samples
		var level = 1.0 - (1.0 - sustain) * t
		result[idx] = samples[idx] * level
		idx += 1
	# Sustain
	for i in sustain_samples:
		result[idx] = samples[idx] * sustain
		idx += 1
	# Release
	for i in release_samples:
		var t = float(i) / release_samples
		result[idx] = samples[idx] * sustain * (1.0 - t)
		idx += 1
	
	return result

func _play_sound(stream: AudioStreamWAV, volume: float = 1.0) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	add_child(player)
	player.finished.connect(_on_player_finished.bind(player))
	player.play()

func _on_player_finished(player: AudioStreamPlayer) -> void:
	player.queue_free()

# ============================================================================
# Sound Effects
# ============================================================================

## Gate click: 60ms metallic click with bandpass noise
func play_gate_click() -> void:
	var noise = _generate_noise_burst(0.06, 0.6)
	# Apply bandpass simulation by mixing with a tuned tone
	var click_tone = _generate_sine_samples(2000.0, 0.06, 0.3)
	var combined = PackedFloat32Array()
	combined.resize(noise.size())
	for i in noise.size():
		combined[i] = noise[i] * 0.7 + click_tone[i] * 0.3
	var decay = _generate_noise_burst(0.06, 0.5)
	for i in min(combined.size(), decay.size()):
		combined[i] += decay[i] * 0.3
	var stream = _create_wav_buffer(combined)
	_play_sound(stream, 0.7 * SOUND_VOLUME)

## Fill clank: 40ms metallic impact with 440Hz tone
func play_fill_clank() -> void:
	var noise = _generate_noise_burst(0.04, 0.4)
	var tone = _generate_sine_samples(440.0, 0.04, 0.5)
	var combined = PackedFloat32Array()
	combined.resize(noise.size())
	for i in noise.size():
		combined[i] = noise[i] * 0.5 + tone[i] * 0.5
	var stream = _create_wav_buffer(combined)
	_play_sound(stream, 0.8 * SOUND_VOLUME)

## Contamination: 200ms dissonant buzz
func play_contamination() -> void:
	var t = 0.2
	var freq1 = 220.0
	var freq2 = 233.0
	var num_samples = int(t * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	for i in num_samples:
		var envelope = exp(-float(i) / num_samples * 5.0)
		var beat = sin(i * freq1 * TAU / SAMPLE_RATE) * 0.5 + sin(i * freq2 * TAU / SAMPLE_RATE) * 0.5
		samples[i] = beat * envelope * 0.3
	var stream = _create_wav_buffer(samples)
	_play_sound(stream, 0.5 * SOUND_VOLUME)

## Mold complete: satisfying bell ping at 880Hz with harmonics
func play_mold_complete() -> void:
	var duration = 0.6
	var num_samples = int(duration * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	# Bell-like tone: fundamental + harmonics at 2x and 3x
	var fundamental = 880.0
	var harmonics = [1.0, 2.0, 3.0, 4.01]  # 4.01 avoids perfect alignment
	var amplitudes = [0.5, 0.3, 0.15, 0.05]
	for i in num_samples:
		var t = float(i) / SAMPLE_RATE
		var envelope = exp(-t * 4.0)  # Natural bell decay
		var val = 0.0
		for h in range(harmonics.size()):
			val += sin(TAU * fundamental * harmonics[h] * t) * amplitudes[h]
		samples[i] = val * envelope * 0.6
	var stream = _create_wav_buffer(samples)
	_play_sound(stream, 0.7 * SOUND_VOLUME)

## Order complete fanfare: ascending chord C4-E4-G4 with reverb-like decay
func play_order_complete() -> void:
	var freqs = [262.0, 330.0, 392.0]  # C4, E4, G4
	var duration = 1.0
	var num_samples = int(duration * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	# Play frequencies in quick sequence with overlapping envelopes
	for f in freqs:
		var tone_samples = _generate_sine_samples(f, duration, 0.4)
		var offset = int(0.08 * SAMPLE_RATE)  # 80ms offset between notes
		for i in tone_samples.size():
			var idx = i + offset
			if idx < num_samples:
				var envelope = exp(-float(i) / tone_samples.size() * 3.0)
				samples[idx] += tone_samples[i] * envelope
	
	# Add reverb-like tail using noise
	var reverb = _generate_noise_samples(0.5, 0.05)
	for i in reverb.size():
		var idx = num_samples - reverb.size() + i
		if idx >= 0 and idx < num_samples:
			samples[idx] += reverb[i]
	
	var stream = _create_wav_buffer(samples)
	_play_sound(stream, 0.6 * SOUND_VOLUME)

## Game over: low rumble with descending pitch
func play_game_over() -> void:
	var duration = 1.5
	var num_samples = int(duration * SAMPLE_RATE)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	# Main descending tone from 80Hz to 40Hz
	var phase_inc_start = 80.0 / SAMPLE_RATE
	var phase_inc_end = 40.0 / SAMPLE_RATE
	var current_phase = 0.0
	for i in num_samples:
		var t = float(i) / num_samples
		var freq = lerp(80.0, 40.0, t)
		var envelope = 1.0 - t * 0.7
		samples[i] = sin(current_phase * TAU) * envelope * 0.6
		current_phase += freq / SAMPLE_RATE
	
	# Add noise rumble
	var rumble = _generate_noise_samples(duration, 0.2)
	for i in min(samples.size(), rumble.size()):
		var envelope = exp(-float(i) / samples.size() * 2.0)
		samples[i] += rumble[i] * envelope
	
	var stream = _create_wav_buffer(samples)
	_play_sound(stream, 0.7 * SOUND_VOLUME)

## Part pop: high pitched ting at 880Hz
func play_part_pop() -> void:
	var samples = _generate_sine_samples(880.0, 0.2, 0.5)
	# Apply envelope for quick decay
	var envelope = PackedFloat32Array()
	envelope.resize(samples.size())
	for i in samples.size():
		var t = float(i) / samples.size()
		envelope[i] = exp(-t * 10.0)
		samples[i] *= envelope[i]
	var stream = _create_wav_buffer(samples)
	_play_sound(stream, 0.6 * SOUND_VOLUME)

## Waste drip: short water-like drip sound
func play_waste_drip() -> void:
	var noise = _generate_noise_burst(0.08, 0.3)
	var drip_tone = _generate_sine_samples(800.0, 0.05, 0.2)
	var combined = PackedFloat32Array()
	combined.resize(noise.size())
	for i in noise.size():
		combined[i] = noise[i] * 0.6
	for i in min(drip_tone.size(), combined.size()):
		combined[i] += drip_tone[i] * 0.4
	var stream = _create_wav_buffer(combined)
	_play_sound(stream, 0.5 * SOUND_VOLUME)

# ============================================================================
# Continuous Pour Hum
# ============================================================================

func _ensure_pour_player() -> void:
	if _pour_player == null:
		_pour_player = AudioStreamPlayer.new()
		_pour_player.bus = "Master"
		add_child(_pour_player)
		_pour_volume = 0.0
		_pour_player.volume_db = linear_to_db(_pour_volume)

func start_pour_hum(volume: float = 0.5) -> void:
	_ensure_pour_player()
	_target_pour_volume = volume
	_pour_fade_speed = volume / 0.1  # Fade in over 0.1s
	
	# Generate looping buffer if not playing
	if not _pour_player.playing:
		var hum = _generate_sine_with_vibrato(100.0, 0.5, 0.5, 0.008, 5.5)
		var looped = PackedFloat32Array()
		looped.resize(hum.size() * 4)
		for i in looped.size():
			looped[i] = hum[i % hum.size()]
		var stream = _create_wav_buffer(looped)
		stream.loop = true
		_pour_player.stream = stream
		_pour_player.play()

func stop_pour_hum() -> void:
	_target_pour_volume = 0.0
	_pour_fade_speed = _pour_volume / 0.3  # Fade out over 0.3s

func set_pour_hum_volume(volume: float) -> void:
	if _pour_player:
		_target_pour_volume = volume

# ============================================================================
# Signal Handlers
# ============================================================================

func _on_metal_poured(metal_id: String, world_position: Vector2, amount: float) -> void:
	# Volume scales with pour rate; ignore waste status since we only emit on success
	var vol = clamp(amount / 10.0, 0.1, 0.7)
	start_pour_hum(vol)

func _on_waste_routed(_metal_id: String, _world_pos: Vector2, _amount: float) -> void:
	play_waste_drip()

func _on_gate_toggled(gate_id: String, is_open: bool) -> void:
	play_gate_click()

func _on_order_completed(completed_order: OrderDefinition, order_score: int) -> void:
	play_order_complete()

func _on_game_over(_final_score: int, _waste_percent: float) -> void:
	play_game_over()

func _on_mold_filled(mold_id: String, fill_percent: float) -> void:
	play_fill_clank()

func _on_mold_contaminated(mold_id: String) -> void:
	play_contamination()

func _on_mold_completed(mold_id: String) -> void:
	play_mold_complete()

func _on_part_produced(part_id: String, mold_id: String) -> void:
	play_part_pop()
