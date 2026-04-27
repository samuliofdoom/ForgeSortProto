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
var metal_source: Node
var metal_flow: Node

# Visual children
var _stream_line: Line2D
var _glow_rect: ColorRect
var _particle_container: Node2D
var _last_particle_time: float = 0.0
var _active_metal: String = "iron"
var _screen_height: float = 720.0

# Dynamic pour params driven by metal definition
var _current_stream_width: float = 8.0
var _current_particle_interval: float = 0.04

func _ready():
	metal_source = get_node_or_null("/root/MetalSource")
	metal_flow = get_node_or_null("/root/MetalFlow")
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

	# Metal selection changes → update stream color and properties
	if metal_source:
		metal_source.metal_selected.connect(_on_metal_selected)

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

	# Stream from top of playfield down to pour point
	var top_y = 0.0  # top of window
	var top_pos = Vector2(pour_origin.x, top_y)
	var bottom_pos = pour_origin

	_stream_line.clear_points()
	_stream_line.add_point(top_pos)
	_stream_line.add_point(bottom_pos)
	_stream_line.default_color = _get_metal_color(_active_metal)
	_stream_line.width = _current_stream_width

	# Glow follows pour point
	_glow_rect.global_position = pour_origin + Vector2(-_current_stream_width * 1.5, -_current_stream_width * 1.5)
	_glow_rect.color = _get_metal_color(_active_metal)
	_glow_rect.size = Vector2(_current_stream_width * 3, _current_stream_width * 3)

	# Pulse glow alpha
	var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.25 + 0.3
	_glow_rect.modulate.a = pulse

func _spawn_drip_particle():
	if not _particle_container:
		return

	var drip = ColorRect.new()
	drip.color = _get_metal_color(_active_metal)
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
		var is_in_zone = _is_position_in_zone(event.position)
		if event.pressed and is_in_zone:
			_start_pour(event.position)
		elif not event.pressed and is_pouring:
			_end_pour()
	elif event is InputEventMouseMotion:
		if is_pouring and _is_position_in_zone(event.position):
			_update_pour_position(event.position)

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
		_active_metal = metal_source.get_selected_metal()

	# Apply metal-specific pour properties (speed, spread)
	_apply_metal_properties()

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

func _on_metal_selected(metal_id: String):
	_active_metal = metal_id
	_apply_metal_properties()
	if is_pouring:
		_stream_line.default_color = _get_metal_color(metal_id)
		_glow_rect.color = _get_metal_color(metal_id)

func _show_stream_visuals():
	if _stream_line:
		_stream_line.visible = true
	if _glow_rect:
		_glow_rect.visible = true

func _hide_stream_visuals():
	if _stream_line:
		_stream_line.visible = false
	if _glow_rect:
		_glow_rect.visible = false

func _get_metal_color(metal_id: String) -> Color:
	match metal_id:
		"iron":
			return Color(0.75, 0.45, 0.3, 0.85)   # molten iron brown
		"steel":
			return Color(0.75, 0.8, 0.9, 0.85)   # molten steel blue-silver
		"gold":
			return Color(1.0, 0.85, 0.15, 0.9)   # molten gold yellow
		_:
			return Color(0.85, 0.6, 0.3, 0.85)
