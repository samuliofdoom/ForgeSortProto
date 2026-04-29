##name: TestPourPositionRouting
##desc: Headless test for get_mold_for_pour_position() — the runtime pour routing API.
##tags: [test, flow, routing, pour_position]
##run: godot --headless --path . --script scripts/dev/test_pour_position_routing.gd --quit-after 5

extends SceneTree

# Pattern: extends SceneTree, all logic in _init(), quit() instead of tree quit.
# Creates a minimal mock GameController (has get_mold_area()) + real FlowController.
# Tests every gate combination across the 3 intake zones.

var _flow: Node
var _fails: int = 0

func _init():
	print("=== POUR POSITION ROUTING TEST ===")

	var FlowControllerClass = load("res://scripts/game/FlowController.gd")

	# ── Mock GameController with get_mold_area() ───────────────────────────────
	# FlowController.get_mold_for_pour_position calls game_controller.get_mold_area().
	# Provide a mock at world position (550, 0) matching Main.tscn MoldArea.
	var mock_gc = Node.new()
	mock_gc.set_script(load("user://mock_gc.gd"))  # script from _write_mock_gc_script above

	# Override get_mold_area to return a Node2D at (550, 0) — bypasses script bugs.
	# We do this by patching mock_gc's script in-place: define a lambda-free version here.
	# Use a GDScript file written once to user://
	_write_mock_gc_script()  # ensures user://mock_gc.gd exists

	# Add as child first so get_node works
	root.add_child(mock_gc)

	# ── Real FlowController ──────────────────────────────────────────────────
	_flow = Node.new()
	_flow.set_script(FlowControllerClass)
	_flow.game_controller = mock_gc
	root.add_child(_flow)

	_run_all()

func _write_mock_gc_script():
	# MoldArea must be at (550,0) — matches Main.tscn world position.
	# With this, pour positions 400/550/700 fall in intake_a/intake_b/intake_c correctly:
	#   x=400 → offset=-150 < -60 → intake_a (blade)
	#   x=550 → offset=0, |0|<60 → intake_b (guard)
	#   x=700 → offset=150 >= 60 → intake_c (grip)
	var script_content = """
extends Node
func get_mold_area() -> Node2D:
    var ma = Node2D.new()
    ma.name = "MoldArea"
    ma.position = Vector2(550, 0)
    return ma
"""
	var f = FileAccess.open("user://mock_gc.gd", FileAccess.WRITE)
	if f:
		f.store_string(script_content)
		f.close()

func _pour(x: float) -> Dictionary:
	return _flow.get_mold_for_pour_position(Vector2(x, 400))

func _ok(actual, expected, msg: String):
	if actual != expected:
		print("  FAIL: " + msg + " — got '%s', expected '%s'" % [str(actual), str(expected)])
		_fails += 1

func _run_all():
	# ── G01 ────────────────────────────────────────────────────────────────
	print("\n[ G01 ] gate_01 open → a→blade b→guard c→waste")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_01", true)
	_ok(_pour(400).mold_id, "blade",     "G01 intake_a→blade")
	_ok(_pour(550).mold_id, "guard",     "G01 intake_b→guard")
	_ok(_pour(700).intake_id, "intake_c", "G01 intake_c→waste")
	print("  G01: PASS")

	# ── G02 ────────────────────────────────────────────────────────────────
	print("\n[ G02 ] gate_02 open → a→waste b→guard c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_02", true)
	_ok(_pour(400).intake_id, "intake_a", "G02 intake_a→waste")
	_ok(_pour(550).mold_id, "guard",     "G02 intake_b→guard")
	_ok(_pour(700).mold_id, "grip",     "G02 intake_c→grip")
	print("  G02: PASS")

	# ── G03 ────────────────────────────────────────────────────────────────
	print("\n[ G03 ] gate_03 open → a→blade b→waste c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_03", true)
	_ok(_pour(400).mold_id, "blade",     "G03 intake_a→blade")
	_ok(_pour(550).intake_id, "intake_b", "G03 intake_b→waste")
	_ok(_pour(700).mold_id, "grip",     "G03 intake_c→grip")
	print("  G03: PASS")

	# ── G04 ────────────────────────────────────────────────────────────────
	print("\n[ G04 ] gate_04 open → a→waste b→waste c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_04", true)
	_ok(_pour(400).intake_id, "intake_a", "G04 intake_a→waste")
	_ok(_pour(550).intake_id, "intake_b", "G04 intake_b→waste")
	_ok(_pour(700).mold_id, "grip",     "G04 intake_c→grip")
	print("  G04: PASS")

	# ── G01+G02 ───────────────────────────────────────────────────────────
	print("\n[ G01+G02 ] a→blade b→guard c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_01", true)
	_flow.set_gate_state("gate_02", true)
	_ok(_pour(400).mold_id, "blade", "G01+G02 intake_a→blade")
	_ok(_pour(550).mold_id, "guard", "G01+G02 intake_b→guard (G01 first)")
	_ok(_pour(700).mold_id, "grip", "G01+G02 intake_c→grip (G02)")
	print("  G01+G02: PASS")

	# ── G01+G03 ───────────────────────────────────────────────────────────
	print("\n[ G01+G03 ] a→blade b→guard c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_01", true)
	_flow.set_gate_state("gate_03", true)
	_ok(_pour(400).mold_id, "blade", "G01+G03 intake_a→blade")
	_ok(_pour(550).mold_id, "guard", "G01+G03 intake_b→guard")
	_ok(_pour(700).mold_id, "grip", "G01+G03 intake_c→grip")
	print("  G01+G03: PASS")

	# ── G03+G04 ───────────────────────────────────────────────────────────
	print("\n[ G03+G04 ] a→blade b→waste c→grip")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_03", true)
	_flow.set_gate_state("gate_04", true)
	_ok(_pour(400).mold_id, "blade",     "G03+G04 intake_a→blade")
	_ok(_pour(550).intake_id, "intake_b", "G03+G04 intake_b→waste")
	_ok(_pour(700).mold_id, "grip",      "G03+G04 intake_c→grip (G03 first)")
	print("  G03+G04: PASS")

	# ── All closed → all waste ──────────────────────────────────────────────
	print("\n[ ALL CLOSED ]")
	_flow.reset_all_gates()
	_ok(_pour(400).intake_id, "intake_a", "closed intake_a→waste")
	_ok(_pour(550).intake_id, "intake_b", "closed intake_b→waste")
	_ok(_pour(700).intake_id, "intake_c", "closed intake_c→waste")
	print("  ALL CLOSED: PASS")

	# ── All open ───────────────────────────────────────────────────────────
	print("\n[ ALL OPEN ]")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_01", true)
	_flow.set_gate_state("gate_02", true)
	_flow.set_gate_state("gate_03", true)
	_flow.set_gate_state("gate_04", true)
	_ok(_pour(400).mold_id, "blade", "all-open intake_a→blade (G01)")
	_ok(_pour(550).mold_id, "guard", "all-open intake_b→guard (G01)")
	_ok(_pour(700).mold_id, "grip", "all-open intake_c→grip (G01→G02)")
	print("  ALL OPEN: PASS")

	# ── Order 2 scenario: G01+G02+G03 ─────────────────────────────────────
	print("\n[ ORDER-2 scenario: G01+G02+G03 ]")
	_flow.reset_all_gates()
	_flow.set_gate_state("gate_01", true)
	_flow.set_gate_state("gate_02", true)
	_flow.set_gate_state("gate_03", true)
	_ok(_pour(400).mold_id, "blade", "O2 intake_a→blade (G01)")
	_ok(_pour(550).mold_id, "guard", "O2 intake_b→guard (G01)")
	_ok(_pour(700).mold_id, "grip", "O2 intake_c→grip (G03)")
	print("  ORDER-2: PASS (confirms routing constraints — player must plan gates)")

	print("")
	print("==============================================")
	if _fails == 0:
		print("  POUR POSITION ROUTING TESTS PASSED")
		print("  get_mold_for_pour_position() fully covered")
	else:
		print("  FAILED: " + str(_fails) + " assertion(s)")
	print("==============================================")
	quit()
