##name: TestMoldForPourPositionRouting
##desc: Headless test for FlowController.get_mold_for_pour_position() — NEW-001 fix verification.
##tags: [test, flow, routing, pour_position, NEW-001]
##run: godot --headless --path . --script scripts/dev/test_mold_for_pour_position_routing.gd --quit-after 15

extends Node

# MoldArea is at (200, 450) per Main.tscn.
# RoutingField (parent of intakes) is at (200, 280).
# Intake positions relative to RoutingField: A=(-120,60), B=(-40,60), C=(40,60).
# So absolute intake world positions:
#   intake_a → (80,  340)
#   intake_b → (160, 340)
#   intake_c → (240, 340)
#
# get_mold_for_pour_position() maps world_position.x to intake via:
#   offset_x < -60  → intake_a
#   -60 <= offset_x < 60 → intake_b
#   offset_x >= 60  → intake_c
# where mold_center_x = MoldArea.global_position.x = 200.
#
# Gate routing:
#   gate_01 → [intake_a, intake_b]   (G1)
#   gate_02 → [intake_b, intake_c]   (G2)
#   gate_03 → [intake_a, intake_c]   (G3)
#   gate_04 → [intake_c]             (G4)
#
# INTAKE_TO_MOLD:
#   intake_a → blade
#   intake_b → guard
#   intake_c → grip

var _fc: Node
var _errors: int = 0
var _tests_run: int = 0
var _tick: int = 0

const INTAKE_A_POS = Vector2(80, 340)
const INTAKE_B_POS = Vector2(160, 340)
const INTAKE_C_POS = Vector2(240, 340)

func _ready():
	print("=== MOLD FOR POUR POSITION ROUTING TEST ===")

	# Load Main.tscn so /root/Main/MoldArea exists (needed by get_mold_for_pour_position)
	var main_scene = load("res://scenes/Main.tscn")
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		get_tree().quit(1)
		return
	var main_inst = main_scene.instantiate()
	get_window().add_child(main_inst)
	await Engine.get_main_loop().process_frame

	_fc = get_node("/root/FlowController")
	_fc.reset_all_gates()

	print("Scene loaded, FlowController ready — testing pour position routing")

func _process(_delta: float):
	_tick += 1
	if _errors > 0 or _tick > 120:
		_finalize()
		return

	match _tick:
		5:  _test_g1_only_pour_at_a()
		10: _test_g1_only_pour_at_b()
		15: _test_g2_only_pour_at_b()
		20: _test_g2_only_pour_at_c()
		25: _test_g1_g2_both_open_pour_at_b()  # NEW-001 fix test
		30: _test_g1_g2_both_open_pour_at_c()
		35: _test_all_gates_closed_pour_at_a()
		40: _test_g3_only_pour_at_a()
		45: _test_g3_only_pour_at_c()
		50: _test_g3_g1_both_open_pour_at_b()
		55: _all_passed()

func _reset_gates():
	_fc.reset_all_gates()

func _assert(condition: bool, msg: String):
	_tests_run += 1
	if not condition:
		_errors += 1
		print("  FAIL [%d]: %s" % [_tests_run, msg])

# ── Test 1: Only G1 open, pour at intake_a → blade ─────────────────────────
func _test_g1_only_pour_at_a():
	_reset_gates()
	_fc.set_gate_state("gate_01", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_A_POS)
	_assert(result["mold_id"] == "blade",
		"G1 only, pour at intake_a → blade, got '%s'" % result["mold_id"])
	print("  [1] G1 only, pour at A → blade — PASS")

# ── Test 2: Only G1 open, pour at intake_b → guard ─────────────────────────
func _test_g1_only_pour_at_b():
	_reset_gates()
	_fc.set_gate_state("gate_01", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_B_POS)
	_assert(result["mold_id"] == "guard",
		"G1 only, pour at intake_b → guard, got '%s'" % result["mold_id"])
	print("  [2] G1 only, pour at B → guard — PASS")

# ── Test 3: Only G2 open, pour at intake_b → guard ─────────────────────────
func _test_g2_only_pour_at_b():
	_reset_gates()
	_fc.set_gate_state("gate_02", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_B_POS)
	_assert(result["mold_id"] == "guard",
		"G2 only, pour at intake_b → guard, got '%s'" % result["mold_id"])
	print("  [3] G2 only, pour at B → guard — PASS")

# ── Test 4: Only G2 open, pour at intake_c → grip ─────────────────────────
func _test_g2_only_pour_at_c():
	_reset_gates()
	_fc.set_gate_state("gate_02", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_C_POS)
	_assert(result["mold_id"] == "grip",
		"G2 only, pour at intake_c → grip, got '%s'" % result["mold_id"])
	print("  [4] G2 only, pour at C → grip — PASS")

# ── Test 5: G1+G2 both open, pour at intake_b → guard ─────────────────────
# THIS IS THE NEW-001 BUG FIX TEST.
# Before the fix, this would return "blade" (wrong — first open gate's first intake).
# After the fix, this correctly returns "guard" (the mold for the ACTUAL pour intake).
func _test_g1_g2_both_open_pour_at_b():
	_reset_gates()
	_fc.set_gate_state("gate_01", true)  # G1: A+B
	_fc.set_gate_state("gate_02", true)  # G2: B+C
	var result = _fc.get_mold_for_pour_position(INTAKE_B_POS)
	_assert(result["mold_id"] == "guard",
		"G1+G2, pour at intake_b → guard (NEW-001 fix), got '%s'" % result["mold_id"])
	print("  [5] G1+G2, pour at B → guard (NEW-001 fix) — PASS")

# ── Test 6: G1+G2 both open, pour at intake_c → grip ───────────────────────
func _test_g1_g2_both_open_pour_at_c():
	_reset_gates()
	_fc.set_gate_state("gate_01", true)
	_fc.set_gate_state("gate_02", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_C_POS)
	_assert(result["mold_id"] == "grip",
		"G1+G2, pour at intake_c → grip, got '%s'" % result["mold_id"])
	print("  [6] G1+G2, pour at C → grip — PASS")

# ── Test 7: All gates closed, pour at intake_a → empty (waste) ──────────────
func _test_all_gates_closed_pour_at_a():
	_reset_gates()
	var result = _fc.get_mold_for_pour_position(INTAKE_A_POS)
	_assert(result["mold_id"] == "",
		"all closed, pour at intake_a → waste (empty mold_id), got '%s'" % result["mold_id"])
	_assert(result["intake_id"] == "intake_a",
		"all closed, pour at intake_a → intake_id=intake_a, got '%s'" % result["intake_id"])
	print("  [7] all closed, pour at A → waste — PASS")

# ── Test 8: Only G3 open (A+C), pour at intake_a → blade ─────────────────
func _test_g3_only_pour_at_a():
	_reset_gates()
	_fc.set_gate_state("gate_03", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_A_POS)
	_assert(result["mold_id"] == "blade",
		"G3 only, pour at intake_a → blade, got '%s'" % result["mold_id"])
	print("  [8] G3 only, pour at A → blade — PASS")

# ── Test 9: Only G3 open (A+C), pour at intake_c → grip ─────────────────
func _test_g3_only_pour_at_c():
	_reset_gates()
	_fc.set_gate_state("gate_03", true)
	var result = _fc.get_mold_for_pour_position(INTAKE_C_POS)
	_assert(result["mold_id"] == "grip",
		"G3 only, pour at intake_c → grip, got '%s'" % result["mold_id"])
	print("  [9] G3 only, pour at C → grip — PASS")

# ── Test 10: G3+G1 open, pour at intake_b → guard ────────────────────────
# G2 is not open, so intake_b is only covered by G1.
# G3 covers A+C, not B. So with G1+G3 open, intake_b → guard (G1).
func _test_g3_g1_both_open_pour_at_b():
	_reset_gates()
	_fc.set_gate_state("gate_03", true)  # G3: A+C (no B)
	_fc.set_gate_state("gate_01", true)  # G1: A+B (has B)
	var result = _fc.get_mold_for_pour_position(INTAKE_B_POS)
	_assert(result["mold_id"] == "guard",
		"G3+G1, pour at intake_b → guard (G2 not open, B covered by G1), got '%s'" % result["mold_id"])
	print("  [10] G3+G1, pour at B → guard — PASS")

func _all_passed():
	print("")
	if _errors == 0:
		print("===================================================")
		print("  POUR POSITION ROUTING TESTS PASSED — %d tests" % _tests_run)
		print("===================================================")
	else:
		print("===================================================")
		print("  POUR POSITION ROUTING TESTS FAILED: %d assertion(s)" % _errors)
		print("===================================================")
	_finalize()

func _finalize():
	get_tree().quit(_errors)
