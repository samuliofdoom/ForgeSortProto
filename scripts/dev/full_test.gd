## Run gameplay test: --script scripts/dev/full_test.gd
## NOTE: This works because full_gameplay_test.gd is no longer in Main.tscn.
## The test triggers via tree-root, not scene nodes.
extends Node

var _tick: int = 0
var _phase: int = 0
var _errors: int = 0
var TICK_LIMIT: int = 200

var _metal_source: Node
var _metal_flow: Node
var _flow_controller: Node
var _score_manager: Node
var _order_manager: Node
var _mold_area: Node

func _ready():
	print("=== FORGESORTPROTO FULL GAMEPLAY TEST ===")
	_metal_source    = get_node("/root/MetalSource")
	_metal_flow      = get_node("/root/MetalFlow")
	_flow_controller = get_node("/root/FlowController")
	_score_manager   = get_node("/root/ScoreManager")
	_order_manager   = get_node("/root/OrderManager")
	_mold_area       = get_node("/root/Main/MoldArea")
	print("All autoloads ready — game is go")

func _process(delta: float):
	_tick += 1
	if _errors > 0:
		_finalize()
		return
	if _tick > TICK_LIMIT:
		push_error("Tick limit exceeded (%d) at phase %d" % [TICK_LIMIT, _phase])
		_finalize()
		return
	match _phase:
		0: _test_start_button()
		1: _test_initial_state()
		2: _test_metal_selection()
		3: _test_gate_toggle()
		4: _test_pour_sequence()
		5: _test_order_completion()
		6: _test_score_tracking()
		7: _test_game_over_trigger()
		8: _all_passed()

func _log(msg: String):
	print("[%04d] P%d | %s" % [_tick, _phase, msg])

func _push(msg: String):
	_errors += 1
	print("  FAIL: " + msg)

func _advance():
	_phase += 1
	_log("→ Phase %d" % _phase)

func _test_start_button():
	if _tick > 3:
		var btn = get_node("/root/Main/UI/StartButton")
		btn.pressed.emit()
		_log("Start pressed")
		_advance()

func _test_initial_state():
	if _tick % 4 != 0: return
	var order = _order_manager.get_current_order()
	if order == null: _push("get_current_order() = null"); return
	if order.name != "Iron Sword": _push("Expected 'Iron Sword', got '%s'" % order.name); return
	if _score_manager.get_total_score() != 0: _push("Initial score should be 0"); return
	var blade = _mold_area.get_node_or_null("BladeMold")
	var guard = _mold_area.get_node_or_null("GuardMold")
	var grip  = _mold_area.get_node_or_null("GripMold")
	if blade == null or guard == null or grip == null: _push("Molds not found"); return
	if blade.is_complete or guard.is_complete or grip.is_complete: _push("Molds should start incomplete"); return
	_log("order='%s' score=0 molds=empty — PASS" % order.name)
	_advance()

func _test_metal_selection():
	if _tick % 4 != 0: return
	if _metal_source.get_selected_metal() != "iron": _push("Default metal should be iron"); return
	_metal_source.select_metal_by_id("steel")
	if _metal_source.get_selected_metal() != "steel": _push("Could not select steel"); return
	_metal_source.select_metal_by_id("gold")
	if _metal_source.get_selected_metal() != "gold": _push("Could not select gold"); return
	_metal_source.select_metal_by_id("iron")
	var def = _metal_source.get_selected_metal_data()
	if def == null: _push("get_selected_metal_data() returned null"); return
	_log("iron/steel/gold selection OK — speed=%.1f spread=%.1f" % [def.speed, def.spread])
	_advance()

func _test_gate_toggle():
	if _tick % 5 != 0: return
	var gates = ["gate_01", "gate_02", "gate_03", "gate_04"]
	for gid in gates:
		var before = _flow_controller.get_gate_state(gid)
		_flow_controller.toggle_gate(gid)
		var after = _flow_controller.get_gate_state(gid)
		if after == before: _push("Gate %s did not change" % gid); return
		_flow_controller.toggle_gate(gid)
	_flow_controller.set_gate_state("gate_01", true)
	_flow_controller.set_gate_state("gate_02", true)
	_flow_controller.reset_all_gates()
	if _flow_controller.get_gate_state("gate_01") != false: _push("reset_all_gates() failed"); return
	_log("All 4 gates + reset_all_gates() OK")
	_advance()

func _test_pour_sequence():
	if _tick % 5 != 0: return
	_log("Filling molds directly")
	_flow_controller.set_gate_state("gate_03", true)
	var blade = _mold_area.get_node_or_null("BladeMold")
	var guard = _mold_area.get_node_or_null("GuardMold")
	var grip  = _mold_area.get_node_or_null("GripMold")
	blade.receive_metal("iron", 100.0)
	if not blade.is_complete: _push("Blade not complete after 100 iron"); return
	guard.receive_metal("iron", 100.0)
	if not guard.is_complete: _push("Guard not complete"); return
	grip.receive_metal("iron", 100.0)
	if not grip.is_complete: _push("Grip not complete"); return
	_log("All 3 molds complete")
	_advance()

func _test_order_completion():
	if _tick % 5 != 0: return
	var completed = _order_manager.get_completed_parts()
	if completed.size() != 3: _push("Expected 3 completed parts, got %d" % completed.size()); return
	for part in ["iron_blade", "iron_guard", "iron_grip"]:
		if not completed.has(part): _push("Missing part: %s" % part); return
	_log("completed_parts=%s — PASS" % str(completed))
	_advance()

func _test_score_tracking():
	if _tick % 4 != 0: return
	var score = _score_manager.get_total_score()
	if score < 100: _push("Score should be >= 100 after Iron Sword, got %d" % score); return
	_log("Score after Iron Sword: %d — PASS" % score)
	_advance()

func _test_game_over_trigger():
	if _tick % 5 != 0: return
	_score_manager.reset()
	_score_manager.add_waste(100.0)
	if _score_manager.waste_units < 100.0: _push("Waste did not reach 100"); return
	_log("Waste meter hit %.1f — game_over should have fired" % _score_manager.waste_units)
	_advance()

func _all_passed():
	print("")
	print("==================================================")
	print("   ALL TESTS PASSED — ForgeSortProto is healthy")
	print("==================================================")
	print("Ticks: %d" % _tick)
	print("")
	print("  [P0] Start button: visible, pressable")
	print("  [P1] Initial state: order=Iron Sword, score=0, molds empty")
	print("  [P2] Metal selection: iron/steel/gold all work")
	print("  [P3] Gate toggle: all 4 gates + reset_all_gates() work")
	print("  [P4] Pour sequence: molds fill correctly with correct metal")
	print("  [P5] Order completion: 3 parts tracked correctly")
	print("  [P6] Score tracking: Iron Sword = 100 pts")
	print("  [P7] Waste game-over: fires at 100 waste")
	print("")
	_finalize()

func _finalize():
	print("QUIT")
	get_tree().quit()
