extends Area2D

signal metal_received(metal_id: String, amount: float)
signal intake_entered(area: Area2D)

@export var intake_id: String = "intake_a"

var flow_controller: Node
var is_active: bool = true
var current_metal: String = ""

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

func _on_area_entered(area: Area2D):
	if not is_active:
		return

	if area.has_method("get_metal_id"):
		var metal_id = area.get_metal_id()
		var amount = area.get_metal_amount() if area.has_method("get_metal_amount") else 1.0
		current_metal = metal_id
		metal_received.emit(metal_id, amount)
		intake_entered.emit(area)

func get_intake_id() -> String:
	return intake_id

func set_active(active: bool):
	is_active = active
