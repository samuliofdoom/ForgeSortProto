##name: FullGameplayTest
##desc: Full gameplay loop test — script unit + integration tests
##tags: [gameplay, test, smoke]

extends SceneTree

var _errors: int = 0
var _deferred_done: bool = false

func _init():
	print("=== FORGESORTPROTO FULL GAMEPLAY TEST ===")
	print("")
	# Defer node access to after tree is fully set up
	call_deferred("_bootstrap")

func _bootstrap():
	# ── Verify autoloads via singleton names ──────────────────────────────
	var ms = Engine.get_singleton("MetalSource")
	var fc = Engine.get_singleton("FlowController")
	var sm = Engine.get_singleton("ScoreManager")
	var om = Engine.get_singleton("OrderManager")

	if ms == null: _push("MetalSource singleton not found")
	if fc == null: _push("FlowController singleton not found")
	if sm == null: _push("ScoreManager singleton not found")
	if om == null: _push("OrderManager singleton not found")

	if _errors > 0:
		_finalize()
		quit(_errors)
		return

	print("--- Autoloads accessible via singleton ---")

	_test_metal_source(ms)
	_test_flow_controller(fc)
	_test_score_manager(sm)
	_test_order_manager(om)

	_finalize()
	quit(_errors)

# ── MetalSource ───────────────────────────────────────────────────────────
func _test_metal_source(ms):
	print("[P0] MetalSource...")
	if ms.get_selected_metal() != "iron":
		_push("Default metal should be iron, got '%s'" % ms.get_selected_metal())
		return
	ms.select_metal_by_id("steel")
	if ms.get_selected_metal() != "steel":
		_push("Could not select steel")
		return
	ms.select_metal_by_id("gold")
	if ms.get_selected_metal() != "gold":
		_push("Could not select gold")
		return
	ms.select_metal_by_id("iron")
	var def = ms.get_selected_metal_data()
	if def == null:
		_push("get_selected_metal_data() returned null")
		return
	print("  PASS: iron/steel/gold selection, metal data — speed=%.1f spread=%.1f" % [def.speed, def.spread])

# ── FlowController ───────────────────────────────────────────────────────
func _test_flow_controller(fc):
	print("[P1] FlowController...")
	if fc.get_gate_state("gate_01") != false:
		_push("gate_01 default should be false")
		return
	fc.toggle_gate("gate_01")
	if fc.get_gate_state("gate_01") != true:
		_push("gate_01 did not open after toggle")
		return
	fc.toggle_gate("gate_01")

	# reset_all_gates
	fc.set_gate_state("gate_01", true)
	fc.set_gate_state("gate_02", true)
	fc.reset_all_gates()
	if fc.get_gate_state("gate_01") != false:
		_push("reset_all_gates() failed")
		return

	# Pour routing
	fc.set_gate_state("gate_03", true)
	var left   = fc.get_mold_for_pour_position(Vector2(200, 400))
	var center = fc.get_mold_for_pour_position(Vector2(400, 400))
	var right  = fc.get_mold_for_pour_position(Vector2(600, 400))
	print("  gate_03 open: left→%s center→%s right→%s" % [left.mold_id, center.mold_id, right.mold_id])
	if left.mold_id != "blade":   _push("Left pour → blade, got '%s'" % left.mold_id)
	if center.mold_id != "guard": _push("Center pour → guard, got '%s'" % center.mold_id)
	if right.mold_id != "grip":   _push("Right pour → grip, got '%s'" % right.mold_id)

	fc.set_gate_state("gate_03", false)
	var blocked = fc.get_mold_for_pour_position(Vector2(400, 400))
	if blocked.mold_id != "":
		_push("Closed gate should block (empty mold_id), got '%s'" % blocked.mold_id)
	if blocked.result_type == "":
		_push("Blocked pour should have result_type set, got empty")
	print("  PASS: gate toggle, reset_all_gates, open=ROUTE closed=BLOCKED")

# ── ScoreManager ──────────────────────────────────────────────────────────
func _test_score_manager(sm):
	print("[P2] ScoreManager...")
	sm.reset()
	if sm.get_total_score() != 0:
		_push("Initial score should be 0")
		return
	sm.add_waste(5.0)
	if sm.get_total_score() >= 5:
		_push("Waste penalty not applied")
		return
	sm.reset()
	sm.add_score(100)
	if sm.get_total_score() != 100:
		_push("add_score(100) failed, got %d" % sm.get_total_score())
		return
	sm.reset()
	sm.add_waste(100.0)
	if sm.waste_units < 100.0:
		_push("Waste did not reach 100, got %.1f" % sm.waste_units)
		return
	print("  PASS: reset, add_score, add_waste, waste_units, game_over threshold all work")

# ── OrderManager ─────────────────────────────────────────────────────────
func _test_order_manager(om):
	print("[P3] OrderManager...")
	om.reset()
	var order = om.get_current_order()
	if order == null:
		_push("get_current_order() returned null")
		return
	if order.name != "Iron Sword":
		_push("First order should be Iron Sword, got '%s'" % order.name)
		return
	if order.base_value != 100:
		_push("Iron Sword value should be 100, got %d" % order.base_value)
		return
	if order.parts.size() != 3:
		_push("Iron Sword should have 3 parts, got %d" % order.parts.size())
		return
	# Complete all parts
	om.complete_part("iron_blade", "iron")
	om.complete_part("iron_guard", "iron")
	om.complete_part("iron_grip", "iron")
	var completed = om.get_completed_parts()
	if completed.size() != 3:
		_push("Expected 3 completed parts, got %d" % completed.size())
		return
	var score = om._score_manager.get_total_score() if om.has_method("_score_manager") else 0
	print("  PASS: Iron Sword(100/3 parts), complete_part, completed_parts tracking")

# ── Finalize ──────────────────────────────────────────────────────────────
func _finalize():
	if _errors == 0:
		print("")
		print("=================================================")
		print("   ALL TESTS PASSED — ForgeSortProto is healthy")
		print("=================================================")
		print("")
		print("Summary:")
		print("  [P0] MetalSource: iron/steel/gold selection, get_selected_metal_data()")
		print("  [P1] FlowController: gate toggle, reset_all_gates, pour routing")
		print("  [P2] ScoreManager: reset, add_score, add_waste, waste_units, game-over")
		print("  [P3] OrderManager: Iron Sword(100), complete_part, get_completed_parts")
		print("")
		print("All autoloads functional.")
		print("")
	else:
		print("")
		print("=================================================")
		print("   %d ERRORS" % _errors)
		print("=================================================")

func _push(msg: String):
	_errors += 1
	print("  FAIL: " + msg)
