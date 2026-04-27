extends Area2D

signal metal_received(metal_id: String, amount: float)
signal intake_entered(area: Area2D)

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
		intake_entered.emit(area)
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

	# Flash and fade
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.0, 0.4)

func get_intake_id() -> String:
	return intake_id

func set_active(active: bool):
	is_active = active

func _get_metal_color(metal_id: String) -> Color:
	match metal_id:
		"iron":
			return Color(0.75, 0.45, 0.3)
		"steel":
			return Color(0.75, 0.8, 0.9)
		"gold":
			return Color(1.0, 0.85, 0.15)
		_:
			return Color(0.85, 0.6, 0.3)
