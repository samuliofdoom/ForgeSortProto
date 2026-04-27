extends Node

signal gate_toggled(gate_id: String, state: bool)
signal flow_routed(intake_id: String, mold_id: String, metal_id: String, amount: float)

var gate_states: Dictionary = {}

var intakes: Dictionary = {}
var molds: Dictionary = {}

const INTAKE_TO_MOLD: Dictionary = {
	"intake_a": "blade",
	"intake_b": "guard",
	"intake_c": "grip"
}

const GATE_ROUTING: Dictionary = {
	"gate_01": ["intake_a", "intake_b"],
	"gate_02": ["intake_b", "intake_c"],
	"gate_03": ["intake_a", "intake_b", "intake_c"],
	"gate_04": ["intake_c"]
}

func _ready():
	_setup_gates()

func _setup_gates():
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		gate_states[gate_id] = false

func register_gate(gate_id: String, gate_node: Node):
	pass

func register_intake(intake_id: String, intake_node: Node):
	intakes[intake_id] = intake_node
	intake_node.area_entered.connect(_on_intake_area_entered.bind(intake_id))

func register_mold(mold_id: String, mold_node: Node):
	molds[mold_id] = mold_node

func get_molds() -> Dictionary:
	return molds

func toggle_gate(gate_id: String):
	if gate_states.has(gate_id):
		gate_states[gate_id] = not gate_states[gate_id]
		gate_toggled.emit(gate_id, gate_states[gate_id])

func set_gate_state(gate_id: String, state: bool):
	gate_states[gate_id] = state
	gate_toggled.emit(gate_id, state)

func get_gate_state(gate_id: String) -> bool:
	return gate_states.get(gate_id, false)

func get_mold_for_intake(intake_id: String) -> String:
	var active_gates = []
	for gate_id in GATE_ROUTING.keys():
		if get_gate_state(gate_id):
			var gated_intakes = GATE_ROUTING[gate_id]
			if intake_id in gated_intakes:
				for g_intake in gated_intakes:
					if not active_gates.has(g_intake):
						active_gates.append(g_intake)

	if active_gates.size() > 0:
		return INTAKE_TO_MOLD.get(active_gates[0], "")
	return INTAKE_TO_MOLD.get(intake_id, "")

func route_metal_to_mold(mold_id: String, metal_id: String, amount: float):
	if molds.has(mold_id) and molds[mold_id]:
		molds[mold_id].receive_metal(metal_id, amount)
		flow_routed.emit("", mold_id, metal_id, amount)

func _on_intake_area_entered(area: Area2D, intake_id: String):
	if area.has_method("get_metal_id"):
		var metal_id = area.get_metal_id()
		var amount = area.get_metal_amount() if area.has_method("get_metal_amount") else 1.0
		route_metal_through_intake(intake_id, metal_id, amount)

func route_metal_through_intake(intake_id: String, metal_id: String, amount: float):
	var target_mold = get_mold_for_intake(intake_id)
	if target_mold != "":
		route_metal_to_mold(target_mold, metal_id, amount)

func reset_all_gates():
	for gate_id in gate_states.keys():
		gate_states[gate_id] = false
		gate_toggled.emit(gate_id, false)

# Returns {mold_id: String, intake_id: String} for a pour at world_position.
# mold_id is non-empty when a gate opens a route to a mold.
# intake_id is non-empty when the pour position targets a blocked intake (waste).
# Both empty = pour was outside all intake zones (fallback routing).
func get_mold_for_pour_position(world_position: Vector2) -> Dictionary:
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if not mold_area:
		return {"mold_id": "", "intake_id": ""}

	var mold_center_x = mold_area.global_position.x
	var offset_x = world_position.x - mold_center_x

	var pour_intake = ""
	if offset_x < -60:
		pour_intake = "intake_a"
	elif offset_x < 60:
		pour_intake = "intake_b"
	else:
		pour_intake = "intake_c"

	# Check which open gates cover this intake
	var active_gates = []
	for gate_id in GATE_ROUTING.keys():
		if get_gate_state(gate_id):
			var gated_intakes = GATE_ROUTING[gate_id]
			if pour_intake in gated_intakes:
				for g_intake in gated_intakes:
					if not active_gates.has(g_intake):
						active_gates.append(g_intake)

	if active_gates.size() > 0:
		# At least one gate is open and covers this intake zone
		# Route to the first available mold
		var mold_id = INTAKE_TO_MOLD.get(active_gates[0], "")
		return {"mold_id": mold_id, "intake_id": ""}

	# No open gate covers this intake — the pour is wasted (blocked intake)
	if pour_intake != "":
		return {"mold_id": "", "intake_id": pour_intake}

	# Pour was outside all intake zones entirely
	return {"mold_id": "", "intake_id": ""}
