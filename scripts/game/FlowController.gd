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

const INTAKE_OFFSET_LOW: float = -60.0
const INTAKE_OFFSET_MID: float = 60.0

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
	game_controller = get_node_or_null("/root/GameController")
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
	# Returns the mold_id for a given intake, checking gate routing first.
	# Gate routing takes priority — if a gate covers this intake, metal routes
	# there directly (no collecting from other gates).
	var routed = _gate_routing_mold_id(intake_id)
	if routed != "":
		return routed
	# No gate covers this intake — warn and return empty
	push_warning("FlowController: intake '%s' has no open gate covering it; metal will not route" % intake_id)
	return ""


# ── Internal helpers ──────────────────────────────────────────────────────────

# Maps world-position offset (relative to mold center) to an intake id.
func _intake_for_x_offset(offset_x: float) -> String:
	if offset_x < INTAKE_OFFSET_LOW:
		return "intake_a"
	elif offset_x < INTAKE_OFFSET_MID:
		return "intake_b"
	else:
		return "intake_c"


# Direct INTAKE_TO_MOLD lookup — no gate check.
func _mold_id_for_intake(intake_id: String) -> String:
	return INTAKE_TO_MOLD.get(intake_id, "")


# Iterates open gates in priority order; returns mold_id if any gate covers
# intake_id. Returns "" when no open gate covers the intake.
func _gate_routing_mold_id(intake_id: String) -> String:
	for gate_id in GATE_ROUTING.keys():
		if get_gate_state(gate_id):
			var gated_intakes = GATE_ROUTING[gate_id]
			if intake_id in gated_intakes:
				return _mold_id_for_intake(intake_id)
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
	if not game_controller:
		return {"mold_id": "", "intake_id": ""}
	var mold_area = game_controller.get_mold_area()
	if not mold_area:
		return {"mold_id": "", "intake_id": ""}

	var offset_x = world_position.x - mold_area.global_position.x
	var pour_intake = _intake_for_x_offset(offset_x)

	# Check which open gate covers this intake
	var mold_id = _gate_routing_mold_id(pour_intake)
	if mold_id != "":
		return {"mold_id": mold_id, "intake_id": ""}

	# No open gate covers this intake — the pour is wasted (blocked intake)
	if pour_intake != "":
		return {"mold_id": "", "intake_id": pour_intake}

	# Pour was outside all intake zones entirely
	return {"mold_id": "", "intake_id": ""}
