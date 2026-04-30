extends Node2D

signal part_produced(part_id: String, mold_id: String)
signal mold_filled(mold_id: String, fill_percent: float)
signal mold_contaminated(mold_id: String)
signal mold_completed(mold_id: String)
signal mold_cleared(mold_id: String)
signal mold_tapped(mold_id: String)
signal metal_rejected(mold_id: String, metal_id: String)  # fires when mid-fill metal switch is rejected

var _blob_catcher: Area2D = null

enum MoldState { IDLE, FILLING, COMPLETE, HARDENING, CONTAMINATED, LOCKED }

const HARDENING_SHRINK_SCALE: Vector2 = Vector2(0.95, 0.95)

@export var mold_id: String = "blade"
@export var part_type: String = "blade"
@export var required_metal: String = "iron"
@export var fill_amount: float = 100.0

var current_fill: float = 0.0
var is_contaminated: bool = false
var is_complete: bool = false
var current_metal: String = ""
var is_filling: bool = false
var is_locked: bool = false  # true between order complete and next order starting
var mold_state: MoldState = MoldState.IDLE

var _hardening_timer: Timer = null
var _display_tween: Tween = null  # kills previous before creating new to prevent tween accumulation
var _hardening_tween: Tween = null
var _complete_settle_tween: Tween = null
var _complete_effect_tween: Tween = null
var _contamination_effect_tween: Tween = null
var _wrong_metal_flash_tween: Tween = null
var _receiving_glow_tween: Tween = null
var _rejection_tween: Tween = null
var _clear_effect_tween: Tween = null

@onready var fill_bar: ProgressBar = $FillBar
@onready var state_label: Label = $StateLabel
@onready var mold_sprite: ColorRect = $MoldSprite
var _glow_overlay: ColorRect  # nullable - fill-driven halo overlay created in _ready
var padlock: Node = null  # programmatic padlock icon for locked state
var _padlock_pulse_tween: Tween = null

var order_manager: Node
var score_manager: Node
var game_data: Node
var metal_flow: Node
var part_pop_effect: Node
var _glow_active: bool = false

func _ready():
	# Allow test injection before add_child() — don't clobber if already set.
	if not order_manager:
		order_manager = get_node("/root/OrderManager")
	if not score_manager:
		score_manager = get_node("/root/ScoreManager")
	if not game_data:
		game_data = get_node("/root/GameData")
	if not metal_flow:
		metal_flow = get_node("/root/MetalFlow")
	part_pop_effect = get_node_or_null("/root/Main/PartPopEffect")

	if metal_flow and metal_flow.has_method("register_mold"):
		metal_flow.register_mold(mold_id, self)
	if order_manager:
		order_manager.order_completed.connect(_on_order_completed)
		order_manager.order_started.connect(_on_order_started)

	# Create programmatic padlock icon (hidden by default)
	_create_padlock_icon()
	# FEATURE-008: fill-driven glow overlay — a separate semi-transparent ColorRect
	# layered above the mold sprite, driven by fill percent instead of sine-wave brightness
	_glow_overlay = ColorRect.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.z_index = 5
	_glow_overlay.color = Color(0.0, 0.0, 0.0, 0.0)  # fully transparent initially
	# Slightly larger than mold_sprite so it bleeds outward as a halo
	_glow_overlay.offset_left = -48
	_glow_overlay.offset_top = -38
	_glow_overlay.offset_right = 48
	_glow_overlay.offset_bottom = 38
	mold_sprite.add_child(_glow_overlay)
	_setup_blob_catcher()
	_update_display()

func _input(event):
	if event is InputEventMouseButton:
		# Use get_global_mouse_position() — event.position is screen-space but
		# _is_click_on_mold() uses world-space (global_position). Using screen-space
		# coords would give wrong results when the viewport is scrolled or the
		# MoldArea is not at origin.
		if event.pressed and _is_click_on_mold(get_global_mouse_position()):
			_on_mold_tapped()

func _is_click_on_mold(click_pos: Vector2) -> bool:
	var rect = Rect2(global_position - Vector2(40, 30), Vector2(80, 60))
	return rect.has_point(click_pos)

func _setup_blob_catcher() -> void:
	# Area2D that catches falling MetalBlob RigidBody2Ds.
	# The Area2D is positioned above the mold so blobs entering it
	# triggers receive_metal — blobs pile up via physics above the mold.
	_blob_catcher = Area2D.new()
	_blob_catcher.name = "BlobCatcher"
	_blob_catcher.position = Vector2(0, -30)
	# Collision: monitor layer 1 (blobs) for entry detection
	# Must have monitoring=true to detect body_entered events
	_blob_catcher.collision_mask = 0b0001  # layer 1 = blobs
	_blob_catcher.monitoring = true

	var shape = RectangleShape2D.new()
	shape.size = Vector2(70, 20)

	var col = CollisionShape2D.new()
	col.name = "CatcherShape"
	col.shape = shape
	col.position = Vector2(0, 0)

	_blob_catcher.add_child(col)
	add_child(_blob_catcher)

	# Monitor blob entries — each blob in calls receive_metal once
	_blob_catcher.body_entered.connect(_on_blob_catcher_entered.bind(_blob_catcher))

func _on_blob_catcher_entered(body: Node2D) -> void:
	# A MetalBlob landed in this mold's catcher zone
	if body is RigidBody2D and body.has_method("get_metal_id"):
		var metal_id = body.get_metal_id()
		# Each blob = 1 unit of metal for fill purposes
		receive_metal(metal_id, 1.0)

func _on_mold_tapped():
	mold_tapped.emit(mold_id)
	if is_contaminated:
		clear_mold()

func receive_metal(metal_id: String, amount: float, penalize: bool = true):
	# Guard: locked mold — discard metal and penalize
	if is_locked:
		if penalize:
			score_manager.add_waste(amount)
		return

	# Guard: hardening — no more metal accepted
	if mold_state == MoldState.HARDENING:
		if penalize:
			score_manager.add_waste(amount)
		return

	# Guard: mold already complete — handle wrong metal vs correct metal
	if is_complete:
		if metal_id != required_metal and not is_contaminated:
			_trigger_wrong_metal_flash(metal_id)
			_trigger_contamination(metal_id, amount)
		else:
			if penalize:
				score_manager.add_waste(amount)
		return

	# Guard: overfilled (shouldn't receive more)
	if not is_contaminated and current_fill >= fill_amount:
		if penalize:
			score_manager.add_waste(amount)
		return

	# Establish current metal type on first pour
	if current_metal == "":
		current_metal = metal_id

	# Guard: metal type mismatch mid-fill — reject with feedback
	# Only fires when mold already has metal established (not on first pour)
	if current_metal != "" and metal_id != current_metal:
		_trigger_rejection_feedback()
		metal_rejected.emit(mold_id, metal_id)
		if penalize:
			score_manager.add_waste(amount)
		return

	# Guard: wrong metal type — contamination
	if metal_id != required_metal and not is_contaminated:
		_trigger_wrong_metal_flash(metal_id)
		_trigger_contamination(metal_id, amount)
		return

	# Process fill
	is_filling = true
	mold_state = MoldState.FILLING
	current_fill += amount
	_create_receiving_glow(metal_id)
	_spawn_splatter_burst(metal_id)  # FEATURE-007: splatter burst on mold impact
	_update_display()
	mold_filled.emit(mold_id, get_fill_percent())

	if current_fill >= fill_amount and not is_complete:
		_trigger_complete()

func _trigger_contamination(wrong_metal: String, amount: float):
	is_contaminated = true
	current_metal = wrong_metal
	mold_state = MoldState.CONTAMINATED
	score_manager.add_contamination()
	score_manager.add_waste(amount)
	_update_display()
	mold_contaminated.emit(mold_id)
	_create_contamination_effect()

func _trigger_complete():
	is_complete = true
	is_filling = false
	mold_state = MoldState.HARDENING
	_update_display()
	# Emit mold_completed at START of hardening so order knows part is coming
	mold_completed.emit(mold_id)
	_animate_hardening()
	_start_hardening_timer()
	# Do NOT call _produce_part() here — that happens after hardening

func _start_hardening_timer():
	_hardening_timer = Timer.new()
	_hardening_timer.wait_time = 2.0
	_hardening_timer.one_shot = true
	_hardening_timer.timeout.connect(_on_hardening_complete)
	add_child(_hardening_timer)
	_hardening_timer.start()

func _on_hardening_complete():
	mold_state = MoldState.COMPLETE
	_produce_part()
	_animate_complete_settle()

func _produce_part():
	var metal_prefix = current_metal
	var part_id = metal_prefix + "_" + part_type
	part_produced.emit(part_id, mold_id)
	order_manager.complete_part(part_id)

	if part_pop_effect and part_pop_effect.has_method("spawn_part_pop"):
		part_pop_effect.spawn_part_pop(part_id, global_position)

func clear_mold():
	# Cancel any active hardening timer
	if _hardening_timer:
		_hardening_timer.stop()
		_hardening_timer.queue_free()
		_hardening_timer = null

	current_fill = 0.0
	is_contaminated = false
	is_complete = false
	current_metal = ""
	is_filling = false
	mold_state = MoldState.IDLE
	_update_display()
	mold_cleared.emit(mold_id)
	_create_clear_effect()

func get_fill_percent() -> float:
	return clamp(current_fill / fill_amount, 0.0, 1.0)

func get_mold_id() -> String:
	return mold_id

func get_part_type() -> String:
	return part_type

func _on_order_completed(_completed_order: OrderDefinition, _score: int):
	is_locked = true

func _on_order_started(new_order: OrderDefinition):
	# Cancel any active hardening timer if order changes mid-hardening
	if _hardening_timer:
		_hardening_timer.stop()
		_hardening_timer.queue_free()
		_hardening_timer = null

	if score_manager and score_manager.has_method("reset_order"):
		score_manager.reset_order()
	is_locked = false
	mold_state = MoldState.IDLE
	# Always clear mold at order start — fixes BUG-003: partial fills
	# that were neither complete nor contaminated would leak into next order
	clear_mold()
	if new_order.part_requests.has(part_type):
		required_metal = new_order.part_requests[part_type]
	_update_display()

func _update_display():
	_update_fill_bar()
	_update_mold_sprite()
	_update_state_label()
	_update_padlock_visibility()

func _update_fill_bar():
	if not fill_bar:
		return
	var target_val = get_fill_percent() * 100
	# Kill existing tween before creating new to prevent accumulation during rapid fills
	if _display_tween:
		_display_tween.kill()
	_display_tween = create_tween()
	if _display_tween == null:
		return
	_display_tween.tween_property(fill_bar, "value", target_val, 0.25)
	if mold_state == MoldState.HARDENING:
		fill_bar.modulate = Color.ORANGE
	elif is_contaminated:
		fill_bar.modulate = Color.RED
	elif is_complete:
		fill_bar.modulate = Color.GREEN
	elif current_fill > 0:
		fill_bar.modulate = Color.YELLOW
	else:
		fill_bar.modulate = Color.WHITE

func _update_mold_sprite():
	if not mold_sprite:
		return
	if mold_state == MoldState.HARDENING:
		mold_sprite.modulate = Color(0.5, 0.55, 0.6)
	elif is_contaminated:
		mold_sprite.modulate = Color.RED * 0.5
	elif is_complete:
		mold_sprite.modulate = Color.GREEN * 0.5
	elif current_fill > 0:
		mold_sprite.modulate = MetalDefinition.get_color(current_metal) * 0.7
	elif is_locked:
		mold_sprite.modulate = Color.DIM_GRAY * 0.5
	else:
		mold_sprite.modulate = Color.WHITE
	# Apply ambient glow when filling - brighter glow based on fill amount
	_update_fill_glow()

func _update_state_label():
	if not state_label:
		return
	if mold_state == MoldState.HARDENING:
		state_label.text = "Cooling..."
		state_label.modulate = Color.ORANGE
	elif is_complete:
		state_label.text = "Done!"
		state_label.modulate = Color.GREEN
	elif is_contaminated:
		state_label.text = "Tap to Clear"
		state_label.modulate = Color.RED
	elif is_locked:
		state_label.text = "Locked"
		state_label.modulate = Color.DIM_GRAY
	elif current_fill > 0:
		state_label.text = "%.0f%%" % (get_fill_percent() * 100)
		state_label.modulate = Color.YELLOW
	else:
		state_label.text = required_metal.capitalize()
		state_label.modulate = Color.WHITE

func _update_fill_glow():
	# FEATURE-008: drive a dedicated overlay ColorRect by fill percent.
	# Alpha ramps from 0 → 0.6 as fill goes 0→100%, scale also grows.
	# This replaces the old sine-wave-only brightness modulation.
	if not is_instance_valid(_glow_overlay):
		return
	if mold_state == MoldState.FILLING:
		var fill_pct = get_fill_percent()
		var metal_color = MetalDefinition.get_color(current_metal)
		var alpha = fill_pct * 0.65
		# Outer glow halo: color × low alpha, larger than base sprite
		_glow_overlay.color = Color(metal_color.r, metal_color.g, metal_color.b, alpha)
		# Scale the overlay up as fill increases (halo grows outward)
		var glow_scale = 1.0 + fill_pct * 0.3
		_glow_overlay.scale = Vector2(glow_scale, glow_scale)
		_glow_overlay.visible = true
	elif mold_state == MoldState.HARDENING:
		_glow_overlay.color.a = 0.3
		_glow_overlay.scale = Vector2(1.15, 1.15)
		_glow_overlay.visible = true
	elif is_complete:
		_glow_overlay.color.a = 0.4
		_glow_overlay.scale = Vector2(1.2, 1.2)
		_glow_overlay.visible = true
	elif is_contaminated:
		_glow_overlay.color = Color(1.0, 0.0, 0.0, 0.35)
		_glow_overlay.scale = Vector2(1.1, 1.1)
		_glow_overlay.visible = true
	else:
		_glow_overlay.visible = false
		_glow_overlay.color.a = 0.0

func _get_metal_color(metal_id: String) -> Color:
	return MetalDefinition.get_color(metal_id)

func _create_padlock_icon():
	# Build a simple padlock from ColorRects: body + shackle arch
	padlock = Node2D.new()
	padlock.name = "Padlock"
	padlock.z_index = 10
	padlock.visible = false
	add_child(padlock)

	# Padlock body (rectangle)
	var body = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(16, 12)
	body.position = Vector2(-8, -2)
	body.color = Color(0.6, 0.6, 0.65)
	body.anchor_left = 0.5
	body.anchor_right = 0.5
	body.anchor_top = 0.5
	body.anchor_bottom = 0.5
	padlock.add_child(body)

	# Shackle (arch made of two vertical rects and a top bar)
	var shackle_left = ColorRect.new()
	shackle_left.name = "ShackleLeft"
	shackle_left.size = Vector2(3, 10)
	shackle_left.position = Vector2(-6, -12)
	shackle_left.color = Color(0.6, 0.6, 0.65)
	shackle_left.anchor_left = 0.5
	shackle_left.anchor_right = 0.5
	shackle_left.anchor_top = 0.5
	shackle_left.anchor_bottom = 0.5
	padlock.add_child(shackle_left)

	var shackle_right = ColorRect.new()
	shackle_right.name = "ShackleRight"
	shackle_right.size = Vector2(3, 10)
	shackle_right.position = Vector2(3, -12)
	shackle_right.color = Color(0.6, 0.6, 0.65)
	shackle_right.anchor_left = 0.5
	shackle_right.anchor_right = 0.5
	shackle_right.anchor_top = 0.5
	shackle_right.anchor_bottom = 0.5
	padlock.add_child(shackle_right)

	var shackle_top = ColorRect.new()
	shackle_top.name = "ShackleTop"
	shackle_top.size = Vector2(12, 3)
	shackle_top.position = Vector2(-6, -14)
	shackle_top.color = Color(0.6, 0.6, 0.65)
	shackle_top.anchor_left = 0.5
	shackle_top.anchor_right = 0.5
	shackle_top.anchor_top = 0.5
	shackle_top.anchor_bottom = 0.5
	padlock.add_child(shackle_top)

func _update_padlock_visibility():
	if not padlock:
		return
	var should_show = is_locked
	if should_show and not padlock.visible:
		padlock.visible = true
		_start_padlock_pulse()
	elif not should_show and padlock.visible:
		_stop_padlock_pulse()
		padlock.visible = false

func _start_padlock_pulse():
	if _padlock_pulse_tween:
		_padlock_pulse_tween.kill()
	_padlock_pulse_tween = create_tween()
	if _padlock_pulse_tween == null:
		return
	_padlock_pulse_tween.set_parallel(true)
	_padlock_pulse_tween.tween_property(padlock, "scale", Vector2(1.15, 1.15), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_padlock_pulse_tween.tween_property(padlock, "scale", Vector2(0.9, 0.9), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).from_current()
	_padlock_pulse_tween.set_loops(-1)

func _stop_padlock_pulse():
	if _padlock_pulse_tween:
		_padlock_pulse_tween.kill()
		_padlock_pulse_tween = null

func _create_contamination_effect():
	if mold_sprite:
		if _contamination_effect_tween:
			_contamination_effect_tween.kill()
		_contamination_effect_tween = create_tween()
		if _contamination_effect_tween == null:
			return
		_contamination_effect_tween.tween_property(mold_sprite, "modulate", Color.RED, 0.1)
		_contamination_effect_tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.3)

func _trigger_wrong_metal_flash(_wrong_metal: String):
	# Distinct pre-contamination flash: orange warning before red contamination
	if mold_sprite:
		if _wrong_metal_flash_tween:
			_wrong_metal_flash_tween.kill()
		_wrong_metal_flash_tween = create_tween()
		if _wrong_metal_flash_tween == null:
			return
		_wrong_metal_flash_tween.tween_property(mold_sprite, "modulate", Color.ORANGE, 0.08)
		_wrong_metal_flash_tween.tween_property(mold_sprite, "modulate", Color.RED, 0.08)

func _trigger_rejection_feedback():
	# Mid-fill metal switch rejection: shake the mold sprite + flash state label.
	# Uses existing _rejection_tween var to prevent tween accumulation.
	if mold_sprite:
		if _rejection_tween:
			_rejection_tween.kill()
		_rejection_tween = create_tween()
		if _rejection_tween == null:
			return
		_rejection_tween.tween_property(mold_sprite, "offset:x", -4.0, 0.05)
		_rejection_tween.tween_property(mold_sprite, "offset:x", 4.0, 0.05)
		_rejection_tween.tween_property(mold_sprite, "offset:x", -3.0, 0.05)
		_rejection_tween.tween_property(mold_sprite, "offset:x", 3.0, 0.05)
		_rejection_tween.tween_property(mold_sprite, "offset:x", 0.0, 0.05)
	if state_label:
		state_label.text = "Wrong Metal"
		state_label.modulate = Color.RED

func _create_receiving_glow(metal_id: String):
	# Brief bright flash when metal enters the mold
	if mold_sprite:
		if _receiving_glow_tween:
			_receiving_glow_tween.kill()
		var color = MetalDefinition.get_color(metal_id)
		_receiving_glow_tween = create_tween()
		if _receiving_glow_tween == null:
			return
		_receiving_glow_tween.tween_property(mold_sprite, "modulate", color * 1.5, 0.1)
		_receiving_glow_tween.tween_property(mold_sprite, "modulate", color * 0.7, 0.2)

func _spawn_splatter_burst(metal_id: String):
	# FEATURE-007: particle burst at mold surface on metal impact
	var splatter = CPUParticles2D.new()
	splatter.name = "SplatterBurst"
	splatter.emitting = true
	splatter.amount = 16
	splatter.lifetime = 0.4
	splatter.explosiveness = 0.85
	splatter.randomness = 0.4
	splatter.one_shot = true
	splatter.speed_scale = 1.2
	# Burst upward/outward from mold surface
	splatter.direction = Vector2(0, -1)
	splatter.spread = 70.0
	splatter.initial_velocity_min = 60.0
	splatter.initial_velocity_max = 140.0
	splatter.gravity = Vector2(0, 300)
	var metal_color = _get_metal_color(metal_id)
	splatter.color = Color(metal_color.r, metal_color.g, metal_color.b, 0.85)

	# Circle texture for particles
	var tex = _get_circle_texture()
	if tex:
		splatter.texture = tex

	splatter.position = Vector2(0, -20)
	add_child(splatter)

	# Destroy after burst completes — use tree_exited instead of finished signal.
	# In Godot 4, CPUParticles2D.finished is only emitted naturally when a
	# one-shot completes AND emitting is set to false by the engine; it cannot
	# be triggered manually via call_deferred emit_signal. Relying on it caused
	# orphaned SplatterBurst nodes to accumulate.
	# Use a timer matching the particle lifetime as a reliable cleanup trigger.
	var cleanup_timer = Timer.new()
	cleanup_timer.name = "SplatterCleanupTimer"
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = splatter.lifetime + 0.05
	cleanup_timer.timeout.connect(_on_splatter_cleanup_timer.bind(splatter, cleanup_timer))
	splatter.add_child(cleanup_timer)
	if splatter.is_inside_tree():
		cleanup_timer.start()
	else:
		# Headless / unit-test context: no scene tree → cleanup immediately
		cleanup_timer.queue_free()
		splatter.queue_free()

func _on_splatter_finished(particles: CPUParticles2D):
	if particles and is_instance_valid(particles):
		particles.queue_free()

func _on_splatter_cleanup_timer(particles: CPUParticles2D, timer: Timer):
	if is_instance_valid(particles):
		particles.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func _get_circle_texture() -> Texture2D:
	# Generate a simple circle texture for particles
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(8, 8)
	for y in range(16):
		for x in range(16):
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= 6:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var tex = ImageTexture.create_from_image(img)
	return tex

func _animate_hardening():
	# Flash WHITE (0.1s) -> desaturate to gray-blue (0.3s) -> darken to cool steel (0.4s)
	# Scale: slight shrink to 0.95 (0.2s, ease_in)
	if mold_sprite:
		if _hardening_tween:
			_hardening_tween.kill()
		_hardening_tween = create_tween()
		if _hardening_tween == null:
			return
		_hardening_tween.set_parallel(false)
		# Flash white
		_hardening_tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.1)
		# Desaturate to gray-blue
		_hardening_tween.tween_property(mold_sprite, "modulate", Color(0.7, 0.72, 0.75), 0.3)
		# Darken to final cooled color
		_hardening_tween.tween_property(mold_sprite, "modulate", Color(0.5, 0.55, 0.6), 0.4)
		# Scale shrink with ease_in
		var scale_tween = create_tween()
		if scale_tween == null:
			return
		scale_tween.tween_property(mold_sprite, "scale", HARDENING_SHRINK_SCALE, 0.2).set_ease(Tween.EASE_IN)

func _animate_complete_settle():
	# Scale back to 1.0 (0.2s, elastic ease)
	# Label already set to "Done!" in green by _update_display
	if mold_sprite:
		if _complete_settle_tween:
			_complete_settle_tween.kill()
		_complete_settle_tween = create_tween()
		if _complete_settle_tween == null:
			return
		_complete_settle_tween.tween_property(mold_sprite, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _create_complete_effect():
	if mold_sprite:
		if _complete_effect_tween:
			_complete_effect_tween.kill()
		_complete_effect_tween = create_tween()
		if _complete_effect_tween == null:
			return
		_complete_effect_tween.set_parallel(false)
		# Chain: flash (0.1s) -> desaturate (0.2s) -> darken (0.3s) = 0.6s, then scale bounce
		# Flash white
		_complete_effect_tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.1)
		# Desaturate to gray-blue
		_complete_effect_tween.tween_property(mold_sprite, "modulate", Color(0.7, 0.72, 0.75), 0.2)
		# Darken to cool steel
		_complete_effect_tween.tween_property(mold_sprite, "modulate", Color(0.5, 0.55, 0.6), 0.3)
		# Scale bounce (0.2s) with elastic ease
		_complete_effect_tween.tween_property(mold_sprite, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		_complete_effect_tween.tween_property(mold_sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _create_clear_effect():
	if mold_sprite:
		if _clear_effect_tween:
			_clear_effect_tween.kill()
		_clear_effect_tween = create_tween()
		if _clear_effect_tween == null:
			return  # Can't tween outside SceneTree (e.g. headless tests)
		_clear_effect_tween.tween_property(mold_sprite, "modulate", Color.BLUE * 0.3, 0.2)
		_clear_effect_tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.2)
