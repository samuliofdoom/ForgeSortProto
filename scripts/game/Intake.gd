extends Area2D

signal metal_received(metal_id: String, amount: float)
# intake_entered was a dead signal — no handler ever connected to it.
# The actual metal routing happens via FlowController's registered
# area_entered handler (registered in register_intake). If a visual
# or audio cue is needed on intake entry, connect to metal_received instead.
# signal intake_entered(area: Area2D)

@export var intake_id: String = "intake_a"

var flow_controller: Node
var is_active: bool = true
var current_metal: String = ""

# Visual children
var _glow_sprite: ColorRect
var _glow_tween: Tween

func _ready():
	flow_controller = get_node_or_null("/root/FlowController")
	area_entered.connect(_on_area_entered)

	var collision = get_node_or_null("CollisionShape2D")
	if collision and collision.shape == null:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(40, 30)
		collision.shape = shape

	if flow_controller and flow_controller.has_method("register_intake"):
		flow_controller.register_intake(intake_id, self)

	# Listen to FlowController routing signals to know when metal passes through
	if flow_controller:
		flow_controller.flow_routed.connect(_on_flow_routed)

	_setup_visuals()

func _setup_visuals():
	# Glow rect overlay on intake
	_glow_sprite = ColorRect.new()
	_glow_sprite.name = "IntakeGlow"
	_glow_sprite.size = Vector2(50, 40)
	_glow_sprite.position = Vector2(-25, -20)
	_glow_sprite.modulate = Color(1, 1, 1, 0)  # start invisible
	add_child(_glow_sprite)

func _on_area_entered(area: Area2D):
	if not is_active:
		return

	if area.has_method("get_metal_id"):
		var metal_id = area.get_metal_id()
		var amount = area.get_metal_amount() if area.has_method("get_metal_amount") else 1.0
		current_metal = metal_id
		metal_received.emit(metal_id, amount)
		_trigger_intake_glow(metal_id)

func _on_flow_routed(intake_id_from_signal: String, _mold_id: String, _metal_id: String, _amount: float):
	if intake_id_from_signal == intake_id:
		_trigger_intake_glow(_metal_id)

func _trigger_intake_glow(metal_id: String):
	if not _glow_sprite:
		return

	# Cancel any existing tween
	if _glow_tween:
		_glow_tween.kill()

	var color = _get_metal_color(metal_id)
	_glow_sprite.modulate = Color(color.r, color.g, color.b, 0.7)

	# Secondary pulse: oscillate 0.7→0.4→0.7, then fade to 0 over 0.8s
	_glow_tween = create_tween()
	_glow_tween.set_parallel(true)
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.4, 0.15)
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.7, 0.15).set_delay(0.15)
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.0, 0.8).set_delay(0.3)

	# Particle burst on metal entry
	_spawn_particle_burst(color)

func _spawn_particle_burst(color: Color):
	var particles = CPUParticles2D.new()
	particles.name = "IntakeParticles"
	particles.emitting = true
	particles.amount = 24
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.randomness = 0.3
	particles.fraction_dead = 0.2
	particles.one_shot = true
	particles.speed_scale = 1.5
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.flatness = 0.2
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0, 200)
	particles.color = Color(color.r, color.g, color.b, 0.8)

	var tex = _get_circle_texture()
	if tex:
		particles.texture = tex

	particles.position = Vector2(0, 0)
	add_child(particles)

	# Destroy after burst completes
	particles.finished.connect(_on_particles_finished.bind(particles))

func _on_particles_finished(particles: CPUParticles2D):
	if particles and is_instance_valid(particles):
		particles.queue_free()

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

func get_intake_id() -> String:
	return intake_id

func set_active(active: bool):
	is_active = active

func _get_metal_color(metal_id: String) -> Color:
	# MetalDefinition.get_color returns sRGB Colors — no conversion needed.
	return MetalDefinition.get_color(metal_id)
