extends StaticBody2D

signal gate_toggled(gate_id: String, is_open: bool)
signal gate_interacted(gate_id: String)

@export var gate_id: String = "gate_01"
@export var is_open: bool = false

@onready var visual: ColorRect = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

var flow_controller: Node

func _ready():
	input_pickable = true
	flow_controller = get_node_or_null("/root/FlowController")
	if flow_controller and flow_controller.has_method("register_gate"):
		flow_controller.register_gate(gate_id, self)

	gate_toggled.connect(_on_gate_toggled)

func toggle():
	is_open = not is_open
	_update_visual()
	gate_toggled.emit(gate_id, is_open)
	if flow_controller:
		flow_controller.set_gate_state(gate_id, is_open)

func _on_gate_toggled(p_gate_id: String, open: bool):
	if p_gate_id == self.gate_id:
		is_open = open
		_update_visual()

func _update_visual():
	if visual:
		if is_open:
			visual.rotation = PI / 4
			visual.modulate = Color.GREEN * 0.8
		else:
			visual.rotation = 0
			visual.modulate = Color.WHITE * 0.8

func get_gate_id() -> String:
	return gate_id

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			var world_pos = get_global_mouse_position()
			var gate_rect = Rect2(global_position - Vector2(15, 35), Vector2(30, 70))
			if gate_rect.has_point(world_pos):
				toggle()
				gate_interacted.emit(gate_id)
