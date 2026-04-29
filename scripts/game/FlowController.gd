extends Node

signal gate_toggled(gate_id: String, state: bool)
signal flow_routed(intake_id: String, mold_id: String, metal_id: String, amount: float)

var gate_states: Dictionary = {}

var intakes: Dictionary = {}
var molds: Dictionary = {}
var game_controller: Node = null

const INTAKE_TO_MOLD: Dictionary = {
	"intake_a": "blade",
	"intake_b": "guard",
	"intake_c": "grip"
}

const GATE_ROUTING: Dictionary = {
	"gate_01": ["intake_a", "intake_b"],
	"gate_02": ["intake_b", "intake_c"],
	# G3 no longer covers all 3 — that trivially bypassed Order 1 routing challenge.
	# Now G3 covers A+C, requiring G1/G2/G4 combos for full coverage.
	"gate_03": ["intake_a", "intake_c"],
	"gate_04": ["intake_c"]
}

func _ready():
	_setup_gates()
	game_controller = get_node("/root/GameController")
	# Note: stream_entered_intake signal was never declared — removed spurious connect

func _setup_gates():
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		gate_states[gate_id] = false

func register_intake(intake_id: String, intake_node: Node):
	intakes[intake_id] = intake_node
	intake_node.area_entered.connect(_on_intake_area_entered.bind(intake_id))

func register_mold(_mold_id: String, mold_node: Node):
	molds[_mold_id] = mold_node

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
	# BUG-018 fix: first, check if any open gate covers intake_id directly.
	# If so, route to that intake's mold — no collecting from other gates.
	for gate_id in GATE_ROUTING.keys():
		if get_gate_state(gate_id):
			var gated_intakes = GATE_ROUTING[gate_id]
			if intake_id in gated_intakes:
				return INTAKE_TO_MOLD.get(intake_id, "")

	# No gate covers this intake — metal cannot be routed; warn and return empty
	push_warning("FlowController: intake '%s' has no open gate covering it; metal will not route" % intake_id)
	return ""

func route_metal_to_mold(intake_id: String, mold_id: String, metal_id: String, amount: float):
	if molds.has(mold_id) and molds[mold_id]:
		molds[mold_id].receive_metal(metal_id, amount)
		flow_routed.emit(intake_id, mold_id, metal_id, amount)

func _on_intake_area_entered(area: Area2D, intake_id: String):
	if area.has_method("get_metal_id"):
		var metal_id = area.get_metal_id()
		var amount = area.get_metal_amount() if area.has_method("get_metal_amount") else 1.0
		route_metal_through_intake(intake_id, metal_id, amount)

func route_metal_through_intake(intake_id: String, metal_id: String, amount: float):
	var target_mold = get_mold_for_intake(intake_id)
	if target_mold != "":
		route_metal_to_mold(intake_id, target_mold, metal_id, amount)

func reset_all_gates():
	for gate_id in gate_states.keys():
		gate_states[gate_id] = false
		gate_toggled.emit(gate_id, false)

# Returns {mold_id: String, intake_id: String} for a pour at world_position.
# mold_id is non-empty when a gate opens a route to a mold.
# intake_id is non-empty when the pour position targets a blocked intake (waste).
# Both empty = pour was outside all intake zones (fallback routing).
func get_mold_for_pour_position(world_position: Vector2) -> Dictionary:
	var mold_area = game_controller.get_mold_area() if game_controller else null
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
	# NEW-001 fix: use pour_intake directly, not active_gates[0].
	# This fixes wrong-mold routing when multiple gates are open:
	# with G1(A,B)+G2(B,C) both open, pouring at intake_b now correctly
	# returns guard (mold for intake_b), not blade (mold for intake_a).
	for gate_id in GATE_ROUTING.keys():
		if get_gate_state(gate_id):
			var gated_intakes = GATE_ROUTING[gate_id]
			if pour_intake in gated_intakes:
				var mold_id = INTAKE_TO_MOLD.get(pour_intake, "")
				return {"mold_id": mold_id, "intake_id": ""}

	# No open gate covers this intake — the pour is wasted (blocked intake)
	if pour_intake != "":
		return {"mold_id": "", "intake_id": pour_intake}

	# Pour was outside all intake zones entirely
	return {"mold_id": "", "intake_id": ""}
