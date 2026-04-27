extends Node2D
class_name PourStream

# Visual pour stream that renders below the cursor while pouring.
# Follows pour_origin X and shows metal color + particles.

signal stream_entered_intake(intake_id: String, metal_id: String)

@export var stream_width: float = 8.0
@export var particle_interval: float = 0.05
@export var particle_speed: float = 400.0

var active_metal: String = "iron"
var stream_origin: Vector2 = Vector2.ZERO
var is_streaming: bool = false
var last_particle_time: float = 0.0
var stream_height: float = 0.0

var metal_source: Node
var intake_area: Node
var flow_controller: Node

# Visual nodes (created dynamically)
var stream_line: Line2D
var stream_tween: Tween
var particle_container: Node2D
var glow_sprite: ColorRect

func _ready():
	metal_source = get_node_or_null("/root/MetalSource")
	flow_controller = get_node_or_null("/root/FlowController")

	# Listen to PourZone signals
	var pour_zone = get_node_or_null("/root/Main/PourZone")
	if pour_zone:
		pour_zone.pour_started.connect(_on_pour_started)
		pour_zone.pour_position_changed.connect(_on_pour_position_changed)
		pour_zone.pour_ended.connect(_on_pour_ended)

	_create_stream_visuals()

func _create_stream_visuals():
	# Stream line — follows cursor down from above
	stream_line = Line2D.new()
	stream_line.width = stream_width
	stream_line.default_color = _get_metal_color(active_metal)
	stream_line.begin_cap_mode = Line2D.LINE_CAP_MODE_ROUND
	stream_line.end_cap_mode = Line2D.LINE_CAP_MODE_ROUND
	stream_line.joint_mode = Line2D.LINE_JOINT_MODE_ROUND
	add_child(stream_line)

	# Glow rect at pour point
	glow_sprite = ColorRect.new()
	glow_sprite.color = _get_metal_color(active_metal)
	glow_sprite.size = Vector2(stream_width * 2, stream_width * 2)
	glow_sprite.position = Vector2(-stream_width, -stream_width)
	add_child(glow_sprite)

	# Particle container
	particle_container = Node2D.new()
	particle_container.name = "ParticleContainer"
	add_child(particle_container)

	# Start invisible
	hide_stream()

func _process(delta):
	if not is_streaming:
		return

	# Update stream geometry
	_update_stream()

	# Spawn particles
	last_particle_time += delta
	if last_particle_time >= particle_interval:
		last_particle_time = 0.0
		_spawn_particle()

func _update_stream():
	if not stream_line:
		return

	var top_pos = Vector2(stream_origin.x, 0)
	var bottom_pos = stream_origin

	stream_line.clear_points()
	stream_line.add_point(top_pos)
	stream_line.add_point(bottom_pos)
	stream_line.default_color = _get_metal_color(active_metal)
	stream_line.width = stream_width

	# Glow at bottom follows pour point
	glow_sprite.global_position = bottom_pos + Vector2(-stream_width, -stream_width)
	glow_sprite.color = _get_metal_color(active_metal)
	glow_sprite.modulate.a = 0.6

	# Pulse the glow
	if glow_sprite.modulate.a > 0.8:
		glow_sprite.modulate.a = 0.4

func _spawn_particle():
	if not particle_container:
		return

	var particle = ColorRect.new()
	particle.color = _get_metal_color(active_metal)
	particle.size = Vector2(4, 4)
	particle.position = stream_origin + Vector2(randf_range(-stream_width, stream_width), 0)
	particle_container.add_child(particle)

	# Animate falling
	var target_y = stream_origin.y + stream_height
	var duration = stream_height / particle_speed
	var tween = create_tween()
	tween.tween_property(particle, "position:y", target_y, duration)
	tween.tween_callback(particle.queue_free)

func _on_pour_started(world_pos: Vector2):
	is_streaming = true
	stream_origin = world_pos
	stream_height = world_pos.y  # distance to top of screen
	last_particle_time = 0.0

	# Get active metal from MetalSource
	if metal_source:
		active_metal = metal_source.get_selected_metal()

	show_stream()
	_update_stream()

func _on_pour_position_changed(world_pos: Vector2):
	stream_origin = world_pos
	stream_height = world_pos.y
	if is_streaming:
		_update_stream()

func _on_pour_ended():
	is_streaming = false
	hide_stream()

func show_stream():
	if stream_line:
		stream_line.visible = true
	if glow_sprite:
		glow_sprite.visible = true

func hide_stream():
	if stream_line:
		stream_line.visible = false
	if glow_sprite:
		glow_sprite.visible = false

func _get_metal_color(metal_id: String) -> Color:
	match metal_id:
		"iron":
			return Color(0.6, 0.4, 0.3, 0.8)   # brown
		"steel":
			return Color(0.7, 0.75, 0.8, 0.8)  # silver
		"gold":
			return Color(1.0, 0.85, 0.2, 0.8)   # gold
		_:
			return Color(0.8, 0.6, 0.3, 0.8)
