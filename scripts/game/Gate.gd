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
	# Gate state is synced via FlowController.toggle_gate() + gate_toggled signal

	gate_toggled.connect(_on_gate_toggled, CONNECT_ONE_SHOT)

func toggle():
	is_open = not is_open
	_update_visual()
	# Use toggle_gate to centralize state + signal in FlowController
	# FlowController.toggle_gate() emits gate_toggled on FlowController
	# (Gate's own gate_toggled signal is for internal use only, e.g. self-updates)
	if flow_controller:
		flow_controller.toggle_gate(gate_id)

func _on_gate_toggled(p_gate_id: String, open: bool):
	if p_gate_id == self.gate_id:
		is_open = open
		_update_visual()

func _update_visual():
	if visual:
		# Stop any running tweens to prevent conflicts
		visual.remove_meta("_tween")

		# Animated tween: elastic ease rotation + color fade white<->green
		var tween = visual.create_tween()
		tween.set_parallel(true)

		var target_rotation = PI / 4 if is_open else 0
		var target_color = Color.GREEN * 0.8 if is_open else Color.WHITE * 0.8

		tween.tween_property(visual, "rotation", target_rotation, 0.25)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)

		tween.tween_property(visual, "modulate", target_color, 0.25)

		visual.set_meta("_tween", tween)

		# Add/remove glow light based on open state
		if is_open:
			if not visual.has_node("GateLight"):
				var light = PointLight2D.new()
				light.name = "GateLight"
				light.color = Color.GREEN
				light.energy = 0.6
				light.texture_scale = 2.0
				light.height = 1.0
				visual.add_child(light)
		else:
			if visual.has_node("GateLight"):
				visual.get_node("GateLight").queue_free()

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
