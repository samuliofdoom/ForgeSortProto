extends Area2D

signal pour_started(world_pos: Vector2)
signal pour_position_changed(world_pos: Vector2)
signal pour_ended()

@export var zone_width: float = 380.0
@export var base_stream_width: float = 8.0
@export var base_particle_interval: float = 0.04
@export var particle_speed: float = 500.0

var is_pouring: bool = false
var pour_origin: Vector2 = Vector2.ZERO
var target_mold: Node = null  # set by MetalFlow when routing determines target mold
var metal_source: Node
var metal_flow: Node

# Visual children
var _stream_line: Line2D
var _glow_line: Line2D        # FEATURE-007: halo glow behind stream
var _glow_rect: ColorRect
var _particle_container: Node2D
var _pour_origin_ghost: ColorRect  # FEATURE-007: ghost indicator at pour origin
var _last_particle_time: float = 0.0
var _active_metal: String = "iron"
var _last_pour_metal: String = "iron"  # tracks metal type at pour start for accumulator flush on gate toggle
var _screen_height: float = 720.0
var _pour_zone_bg: ColorRect  # scene reference for pulsing border effect
var _pulsing_tween: Tween = null  # stored to prevent accumulation on re-call
var _ghost_tween: Tween = null  # FEATURE-007: ghost pulse tween

# Dynamic pour params driven by metal definition
var _current_stream_width: float = 8.0
var _current_particle_interval: float = 0.04

func _ready():
	metal_source = get_node_or_null("/root/MetalSource")
	metal_flow = get_node_or_null("/root/MetalFlow")
	var flow_controller = get_node_or_null("/root/FlowController")
	if flow_controller:
		flow_controller.gate_toggled.connect(_on_gate_toggled)
	if metal_flow:
		metal_flow.waste_routed.connect(_on_waste_routed)
		metal_flow.pour_routing_decided.connect(_on_pour_routing_decided)
	_setup_visuals()

func _setup_visuals():
	# Stream line from top of screen down to pour point
	_stream_line = Line2D.new()
	_stream_line.name = "StreamLine"
	_stream_line.width = _current_stream_width
	_stream_line.default_color = _get_metal_color(_active_metal)
	_stream_line.round_precision = 8
	_stream_line.visible = false
	add_child(_stream_line)

	# FEATURE-007: StreamGlowLine — wide halo behind stream
	_glow_line = Line2D.new()
	_glow_line.name = "StreamGlowLine"
	_glow_line.width = _current_stream_width * 4
	_glow_line.default_color = _get_metal_glow_color(_active_metal)
	_glow_line.round_precision = 8
	_glow_line.visible = false
	# Glow goes behind stream line
	_stream_line.z_index = 1
	_glow_line.z_index = 0
	add_child(_glow_line)

	# Glow rect at pour point
	_glow_rect = ColorRect.new()
	_glow_rect.name = "StreamGlow"
	_glow_rect.color = _get_metal_color(_active_metal)
	_glow_rect.size = Vector2(_current_stream_width * 3, _current_stream_width * 3)
	_glow_rect.position = Vector2(-_current_stream_width * 1.5, -_current_stream_width * 1.5)
	_glow_rect.visible = false
	add_child(_glow_rect)

	# Particle container
	_particle_container = Node2D.new()
	_particle_container.name = "ParticleContainer"
	add_child(_particle_container)

	# FEATURE-007: Pour-origin ghost indicator — dim outline shown at pour point
	_pour_origin_ghost = ColorRect.new()
	_pour_origin_ghost.name = "PourOriginGhost"
	_pour_origin_ghost.color = _get_metal_glow_color(_active_metal)
	_pour_origin_ghost.size = Vector2(_current_stream_width * 2.5, _current_stream_width * 2.5)
	_pour_origin_ghost.position = Vector2(-_current_stream_width * 1.25, -_current_stream_width * 1.25)
	_pour_origin_ghost.modulate.a = 0.0
	_pour_origin_ghost.visible = false
	add_child(_pour_origin_ghost)

	# Get reference to PourZoneBG for pulsing border effect
	_pour_zone_bg = get_node_or_null("PourZoneBG")
	if _pour_zone_bg:
		_setup_pulsing_border()

	# Metal selection changes → update stream color and properties
	if metal_source:
		metal_source.metal_selected.connect(_on_metal_selected)

func _setup_pulsing_border():
	# Kill existing tween before creating a new one to prevent accumulation
	if _pulsing_tween:
		_pulsing_tween.kill()
		_pulsing_tween = null
	_pulsing_tween = create_tween().set_loops()
	_pulsing_tween.tween_property(_pour_zone_bg, "modulate:a", 0.5, 1.0)
	_pulsing_tween.tween_property(_pour_zone_bg, "modulate:a", 0.2, 1.0)

func _apply_metal_properties():
	# Read metal definition to update pour feel
	if metal_source:
		var metal_def = metal_source.get_selected_metal_data()
		if metal_def:
			# spread: 1.0 = base width, higher = wider stream
			_current_stream_width = base_stream_width * metal_def.spread
			# speed: 1.0 = base interval, higher = faster particles (shorter interval)
			_current_particle_interval = base_particle_interval / metal_def.speed
		else:
			_current_stream_width = base_stream_width
			_current_particle_interval = base_particle_interval

func _process(delta):
	if not is_pouring:
		return

	# Update stream geometry
	_update_stream_visuals()

	# Spawn particles dripping down
	_last_particle_time += delta
	if _last_particle_time >= _current_particle_interval:
		_last_particle_time = 0.0
		_spawn_drip_particle()

func _update_stream_visuals():
	if not _stream_line:
		return

	# Stream from furnace top down to target mold (if known), else pour_origin
	var top_y = 0.0  # furnace top
	var top_pos = Vector2(pour_origin.x, top_y)
	var end_pos: Vector2
	if target_mold and is_instance_valid(target_mold):
		end_pos = target_mold.global_position
	else:
		end_pos = pour_origin

	_stream_line.clear_points()
	_stream_line.add_point(top_pos)
	_stream_line.add_point(end_pos)
	_stream_line.default_color = _get_metal_color(_active_metal)
	_stream_line.width = _current_stream_width

	# FEATURE-007: StreamGlowLine — wide halo behind stream
	if _glow_line:
		_glow_line.clear_points()
		_glow_line.add_point(top_pos)
		_glow_line.add_point(end_pos)
		_glow_line.default_color = _get_metal_glow_color(_active_metal)
		_glow_line.width = _current_stream_width * 4

	# Glow follows the end of the stream (mold position)
	_glow_rect.global_position = end_pos + Vector2(-_current_stream_width * 1.5, -_current_stream_width * 1.5)
	_glow_rect.color = _get_metal_glow_color(_active_metal)
	_glow_rect.size = Vector2(_current_stream_width * 3, _current_stream_width * 3)

	# Pulse glow alpha
	var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.25 + 0.3
	_glow_rect.modulate.a = pulse

	# FEATURE-007: Pour-origin ghost follows pour point with soft pulse
	if _pour_origin_ghost:
		_pour_origin_ghost.global_position = end_pos + Vector2(-_current_stream_width * 1.25, -_current_stream_width * 1.25)
		_pour_origin_ghost.color = _get_metal_glow_color(_active_metal)
		_pour_origin_ghost.size = Vector2(_current_stream_width * 2.5, _current_stream_width * 2.5)
		var ghost_pulse = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.15 + 0.25
		_pour_origin_ghost.modulate.a = ghost_pulse

func _spawn_drip_particle():
	if not _particle_container:
		return

	var drip = ColorRect.new()
	# Add size and color variation based on metal type for liquid feel
	var metal_id = _active_metal if _active_metal else "iron"
	match metal_id:
		"iron":
			# Dull orange, smaller drips
			drip.color = Color(0.85, 0.3, 0.05)
			drip.size = Vector2(randf_range(2, 4), randf_range(2, 4))
		"steel":
			# Bright silver-white, medium drips
			drip.color = Color(0.8, 0.85, 0.95)
			drip.size = Vector2(randf_range(3, 5), randf_range(3, 5))
		"gold":
			# Shimmering yellow, larger dripping beads
			drip.color = Color(1.0, 0.9, 0.3)
			drip.size = Vector2(randf_range(4, 7), randf_range(4, 7))
		_:
			drip.color = _get_metal_color(metal_id)
			drip.size = Vector2(3, 3)

	# Start near pour point with slight horizontal scatter
	var scatter = _current_stream_width * 0.5
	var start_x = pour_origin.x + randf_range(-scatter, scatter)
	drip.position = Vector2(start_x, pour_origin.y - _current_stream_width)
	_particle_container.add_child(drip)

	# Fall toward mold area
	var fall_distance = _screen_height - pour_origin.y
	var duration = fall_distance / particle_speed
	var tween = create_tween()
	tween.tween_property(drip, "position:y", pour_origin.y + fall_distance, duration)
	tween.tween_callback(drip.queue_free)

func _input(event):
	if event is InputEventMouseButton:
		# Use get_global_mouse_position() — event.position is screen-space but
		# MetalFlow routing (_get_intake_for_position, _route_fallback) expects
		# world-space coordinates. get_global_mouse_position() handles the
		# screen→world transform automatically.
		var world_pos = get_global_mouse_position()
		var is_in_zone = _is_position_in_zone(world_pos)
		if event.pressed and is_in_zone:
			_start_pour(world_pos)
		elif not event.pressed and is_pouring:
			_end_pour()
	elif event is InputEventMouseMotion:
		if is_pouring and _is_position_in_zone(get_global_mouse_position()):
			_update_pour_position(get_global_mouse_position())

func _is_position_in_zone(pos: Vector2) -> bool:
	var zone_rect = Rect2(
		global_position.x - zone_width / 2,
		global_position.y - 50,
		zone_width,
		100
	)
	return zone_rect.has_point(pos)

func _start_pour(pos: Vector2):
	is_pouring = true
	pour_origin = pos
	_last_particle_time = 0.0

	if metal_source:
		metal_source.start_pour()
		_active_metal = metal_source.get_selected_metal() if metal_source else "iron"
	# Apply metal-specific pour properties (speed, spread)
	_apply_metal_properties()

	# Track metal type so MetalFlow can flush accumulator on gate toggle
	_last_pour_metal = _active_metal
	if metal_flow:
		metal_flow.set_active_stream(self)

	_show_stream_visuals()
	pour_started.emit(global_position)

func _update_pour_position(pos: Vector2):
	pour_origin = pos
	pour_position_changed.emit(pos)

func _end_pour():
	is_pouring = false
	if metal_source:
		metal_source.stop_pour()
	_hide_stream_visuals()
	pour_ended.emit()

func _on_gate_toggled(_gate_id: String, _state: bool):
	# Gate changed mid-pour — flush any accumulated metal via fallback routing
	# so no pour is silently discarded, then stop the pour stream.
	if is_pouring:
		if metal_flow and metal_flow.has_method("flush_accumulator"):
			metal_flow.flush_accumulator(_last_pour_metal, pour_origin)
		is_pouring = false
		_hide_stream_visuals()
		if metal_source:
			metal_source.stop_pour()
		pour_ended.emit()

func _on_pour_routing_decided(_world_pos: Vector2, mold_id: String):
	# Resolve mold node from the routing decision so the stream Line2D
	# can draw from furnace to the actual target mold.
	if mold_id == "":
		target_mold = null
		return
	# Mold nodes are named BladeMold/GuardMold/GripMold; mold_id is "blade"/"guard"/"grip"
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		# Capitalize mold_id to match node naming convention
		var mold_name = mold_id.capitalize().replace(" ", "") + "Mold"
		target_mold = mold_area.get_node_or_null(mold_name)

func _on_metal_selected(metal_id: String):
	_active_metal = metal_id
	_apply_metal_properties()
	if is_pouring:
		_stream_line.default_color = _get_metal_color(metal_id)
		_glow_rect.color = _get_metal_glow_color(metal_id)
		# FEATURE-007: mid-stream metal color update for glow line and ghost
		if _glow_line:
			_glow_line.default_color = _get_metal_glow_color(metal_id)
		if _pour_origin_ghost:
			_pour_origin_ghost.color = _get_metal_glow_color(metal_id)

func _on_waste_routed(_metal_id: String, world_pos: Vector2, _amount: float):
	# Brief orange flash/shake at the pour origin to indicate rejection
	_trigger_rejection_effect(world_pos)

func _trigger_rejection_effect(world_pos: Vector2):
	# Brief orange flash/shake at the rejection point.
	# world_pos is in world-space; flash.position is in PourZone's local space.
	# Convert: local = world - global_position.
	var flash = ColorRect.new()
	flash.name = "RejectionFlash"
	flash.color = Color.ORANGE * 0.7
	flash.size = Vector2(20, 20)
	# FIX FEATURE-007: was doing world_pos - global_position - Vector2(10,10)
	# which subtracted an extra 10px incorrectly. Correct: center flash at world_pos.
	flash.position = world_pos - global_position - Vector2(10, 10)
	flash.z_index = 100
	add_child(flash)

	# Shake effect: fade out + expand over 0.5s
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.5)
	tween.tween_callback(flash.queue_free)

func _show_stream_visuals():
	if _stream_line:
		_stream_line.visible = true
	if _glow_line:
		_glow_line.visible = true
	if _glow_rect:
		_glow_rect.visible = true
	if _pour_origin_ghost:
		_pour_origin_ghost.visible = true
		_start_ghost_pulse()

func _hide_stream_visuals():
	if _stream_line:
		_stream_line.visible = false
	if _glow_line:
		_glow_line.visible = false
	if _glow_rect:
		_glow_rect.visible = false
	if _pour_origin_ghost:
		_pour_origin_ghost.visible = false
		_stop_ghost_pulse()

func _start_ghost_pulse():
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.set_parallel(true)
	_ghost_tween.tween_property(_pour_origin_ghost, "scale", Vector2(1.2, 1.2), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ghost_tween.tween_property(_pour_origin_ghost, "scale", Vector2(0.9, 0.9), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).from_current()
	_ghost_tween.set_loops(-1)

func _stop_ghost_pulse():
	if _ghost_tween:
		_ghost_tween.kill()
		_ghost_tween = null

func _get_metal_color(metal_id: String) -> Color:
	# Return molten hot color for the stream: brighter than base metal color.
	# Color() in Godot 4 is sRGB — do NOT call linear_to_srgb() on literals.
	match metal_id:
		"iron":
			# Molten iron: bright dull-orange
			return Color(0.9, 0.35, 0.05)
		"steel":
			# Molten steel: bright silver-white
			return Color(0.85, 0.9, 1.0)
		"gold":
			# Molten gold: bright shimmering yellow
			return Color(1.0, 0.95, 0.3)
		_:
			return MetalDefinition.get_color(metal_id)

func _get_metal_glow_color(metal_id: String) -> Color:
	# Glow color is brighter, more saturated version for the radial glow.
	# Color() literals are already sRGB — no conversion needed.
	match metal_id:
		"iron":
			return Color(1.0, 0.5, 0.1)
		"steel":
			return Color(0.9, 0.95, 1.0)
		"gold":
			return Color(1.0, 0.9, 0.4)
		_:
			return Color(1.0, 0.7, 0.2)

func get_last_pour_metal() -> String:
	return _last_pour_metal
