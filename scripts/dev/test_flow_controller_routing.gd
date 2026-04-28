##name: TestFlowControllerRouting
##desc: Headless test for FlowController gate routing — single, multi, and no-gate scenarios
##tags: [test, flow, routing]

extends Node2D

var _tick: int = 0
var _errors: int = 0
var TICK_LIMIT: int = 60

var _flow_controller: Node

# Gate routing map (from FlowController):
# gate_01 → [intake_a, intake_b]
# gate_02 → [intake_b, intake_c]
# gate_03 → [intake_a, intake_c]
# gate_04 → [intake_c]
#
# INTAKE_TO_MOLD:
# intake_a → blade
# intake_b → guard
# intake_c → grip

func _ready():
	print("=== FLOW CONTROLLER ROUTING TEST ===")
	_flow_controller = get_node("/root/FlowController")
	_flow_controller.reset_all_gates()
	print("FlowController ready — testing gate routing")

func _process(_delta: float):
	_tick += 1
	if _errors > 0 or _tick > TICK_LIMIT:
		_finalize()
		return

	match _tick:
		5:  _test_single_gate_gate01()
		10: _test_single_gate_gate02()
		15: _test_single_gate_gate04()
		20: _test_two_gates_01_and_02()
		25: _test_two_gates_01_and_03()
		30: _test_two_gates_02_and_04()
		35: _test_two_gates_03_and_04()
		40: _test_all_gates_closed()
		45: _test_all_gates_open()
		50: _test_gate_03_routes_a_and_c()
		55: _all_passed()

func _log(msg: String):
	print("[%04d] %s" % [_tick, msg])

func _push(msg: String):
	_errors += 1
	print("  FAIL: " + msg)

func _assert(condition: bool, msg: String):
	if not condition:
		_push(msg)

# ── Single gate open ──────────────────────────────────────────────────────────

func _test_single_gate_gate01():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_01", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	_assert(mold_a == "blade", "gate_01 open → intake_a should route to blade, got '%s'" % mold_a)
	_assert(mold_b == "guard", "gate_01 open → intake_b should route to guard, got '%s'" % mold_b)
	# intake_c not covered by gate_01 → fallback to INTAKE_TO_MOLD
	_assert(mold_c == "grip", "gate_01 open → intake_c fallback should be grip, got '%s'" % mold_c)
	_log("SINGLE gate_01: a→blade b→guard c→grip(fallback) — PASS")

func _test_single_gate_gate02():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_02", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	_assert(mold_a == "blade", "gate_02 open → intake_a should be blade (fallback), got '%s'" % mold_a)
	_assert(mold_b == "guard", "gate_02 open → intake_b should route to guard, got '%s'" % mold_b)
	_assert(mold_c == "grip", "gate_02 open → intake_c should route to grip, got '%s'" % mold_c)
	_log("SINGLE gate_02: a→blade(fallback) b→guard c→grip — PASS")

func _test_single_gate_gate04():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_04", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	_assert(mold_a == "blade", "gate_04 open → intake_a fallback → blade, got '%s'" % mold_a)
	_assert(mold_b == "guard", "gate_04 open → intake_b fallback → guard, got '%s'" % mold_b)
	_assert(mold_c == "grip", "gate_04 open → intake_c should route to grip, got '%s'" % mold_c)
	_log("SINGLE gate_04: a→blade b→guard c→grip — PASS")

# ── Two gates open ────────────────────────────────────────────────────────────

func _test_two_gates_01_and_02():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_01", true)
	_flow_controller.set_gate_state("gate_02", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# gate_01 covers a+b, gate_02 covers b+c
	# Priority: first open gate whose routing covers the intake
	_assert(mold_a == "blade", "01+02 → intake_a → blade, got '%s'" % mold_a)
	_assert(mold_b == "guard", "01+02 → intake_b → guard, got '%s'" % mold_b)
	_assert(mold_c == "grip", "01+02 → intake_c → grip, got '%s'" % mold_c)
	_log("TWO gates 01+02: a→blade b→guard c→grip — PASS")

func _test_two_gates_01_and_03():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_01", true)
	_flow_controller.set_gate_state("gate_03", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# gate_01: a,b  gate_03: a,c
	# intake_a: covered by both gates, gate_01 checked first
	# intake_b: covered by gate_01 only
	# intake_c: covered by gate_03 only
	_assert(mold_a == "blade", "01+03 → intake_a → blade (gate_01 priority), got '%s'" % mold_a)
	_assert(mold_b == "guard", "01+03 → intake_b → guard (gate_01), got '%s'" % mold_b)
	_assert(mold_c == "grip", "01+03 → intake_c → grip (gate_03), got '%s'" % mold_c)
	_log("TWO gates 01+03: a→blade b→guard c→grip — PASS")

func _test_two_gates_02_and_04():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_02", true)
	_flow_controller.set_gate_state("gate_04", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# gate_02: b,c  gate_04: c
	_assert(mold_a == "blade", "02+04 → intake_a → blade (fallback), got '%s'" % mold_a)
	_assert(mold_b == "guard", "02+04 → intake_b → guard (gate_02), got '%s'" % mold_b)
	_assert(mold_c == "grip", "02+04 → intake_c → grip (gate_02 then gate_04), got '%s'" % mold_c)
	_log("TWO gates 02+04: a→blade(fallback) b→guard c→grip — PASS")

func _test_two_gates_03_and_04():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_03", true)
	_flow_controller.set_gate_state("gate_04", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# gate_03: a,c  gate_04: c
	_assert(mold_a == "blade", "03+04 → intake_a → blade (gate_03), got '%s'" % mold_a)
	_assert(mold_b == "guard", "03+04 → intake_b → guard (fallback), got '%s'" % mold_b)
	_assert(mold_c == "grip", "03+04 → intake_c → grip (gate_03 first), got '%s'" % mold_c)
	_log("TWO gates 03+04: a→blade b→guard(fallback) c→grip — PASS")

# ── All gates closed ─────────────────────────────────────────────────────────

func _test_all_gates_closed():
	_flow_controller.reset_all_gates()

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# All closed → fallback to INTAKE_TO_MOLD direct mapping
	_assert(mold_a == "blade", "all closed → intake_a → blade, got '%s'" % mold_a)
	_assert(mold_b == "guard", "all closed → intake_b → guard, got '%s'" % mold_b)
	_assert(mold_c == "grip", "all closed → intake_c → grip, got '%s'" % mold_c)
	_log("ALL CLOSED: a→blade b→guard c→grip (fallback) — PASS")

# ── All gates open ───────────────────────────────────────────────────────────

func _test_all_gates_open():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_01", true)
	_flow_controller.set_gate_state("gate_02", true)
	_flow_controller.set_gate_state("gate_03", true)
	_flow_controller.set_gate_state("gate_04", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	# gate_01 takes priority for a and b (it's checked first)
	_assert(mold_a == "blade", "all open → intake_a → blade (gate_01), got '%s'" % mold_a)
	_assert(mold_b == "guard", "all open → intake_b → guard (gate_01), got '%s'" % mold_b)
	_assert(mold_c == "grip", "all open → intake_c → grip (gate_01), got '%s'" % mold_c)
	_log("ALL OPEN: a→blade b→guard c→grip — PASS")

# ── gate_03 specifically routes a+c ────────────────────────────────────────

func _test_gate_03_routes_a_and_c():
	_flow_controller.reset_all_gates()
	_flow_controller.set_gate_state("gate_03", true)

	var mold_a = _flow_controller.get_mold_for_intake("intake_a")
	var mold_b = _flow_controller.get_mold_for_intake("intake_b")
	var mold_c = _flow_controller.get_mold_for_intake("intake_c")

	_assert(mold_a == "blade", "gate_03 → intake_a → blade, got '%s'" % mold_a)
	_assert(mold_b == "guard", "gate_03 → intake_b → guard (fallback), got '%s'" % mold_b)
	_assert(mold_c == "grip", "gate_03 → intake_c → grip, got '%s'" % mold_c)
	_log("SINGLE gate_03: a→blade b→guard(fallback) c→grip — PASS")

# ── Done ─────────────────────────────────────────────────────────────────────

func _all_passed():
	print("")
	print("==============================================")
	print("  FLOW ROUTING TESTS PASSED — all gate combos")
	print("==============================================")
	_finalize()

func _finalize():
	print("QUIT")
	get_tree().quit()
