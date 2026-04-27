extends Control

signal gate_toggled(gate_id: String)

@onready var gate_01_btn: Button = $Gate01Button
@onready var gate_02_btn: Button = $Gate02Button
@onready var gate_03_btn: Button = $Gate03Button
@onready var gate_04_btn: Button = $Gate04Button

var flow_controller: Node
var gate_buttons: Dictionary = {}

func _ready():
	flow_controller = get_node_or_null("/root/FlowController")
	if flow_controller:
		flow_controller.gate_toggled.connect(_on_gate_toggled)

	gate_buttons = {
		"gate_01": gate_01_btn,
		"gate_02": gate_02_btn,
		"gate_03": gate_03_btn,
		"gate_04": gate_04_btn
	}

	for btn in gate_buttons.values():
		if btn:
			btn.toggled.connect(_on_gate_button_toggled.bind(btn))

	_update_button_states()

func _on_gate_button_toggled(toggled: bool, button: Button):
	var gate_id = _get_gate_id_for_button(button)
	if gate_id != "" and flow_controller:
		flow_controller.toggle_gate(gate_id)

func _get_gate_id_for_button(button: Button) -> String:
	for gate_id in gate_buttons:
		if gate_buttons[gate_id] == button:
			return gate_id
	return ""

func _on_gate_toggled(gate_id: String, is_open: bool):
	_update_button_states()

func _update_button_states():
	for gate_id in gate_buttons:
		var btn = gate_buttons[gate_id]
		if btn:
			var is_open = flow_controller.get_gate_state(gate_id) if flow_controller else false
			btn.button_pressed = is_open
			if is_open:
				btn.modulate = Color.GREEN
			else:
				btn.modulate = Color.WHITE
