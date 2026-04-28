##name: TestMoldStates
##desc: Headless test for Mold state transitions — extends SceneTree, wires Mold's deps.
##tags: [test, mold, states, contamination]
##run: godot --headless --path . --script scripts/dev/test_mold_states.gd --quit-after 10

extends SceneTree

func _init():
	print("=== MOLD STATE TRANSITIONS TEST ===")

	var MoldClass        = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass    = load("res://scripts/data/GameData.gd")

	var score_manager  = ScoreManagerClass.new()

	# Minimal game_data so OrderManager operations work
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0
	order_manager.current_order = null

	# Create a Mold instance directly
	var mold = MoldClass.new()
	mold.mold_id = "blade"
	mold.name    = "BladeMold"
	mold.order_manager = order_manager
	mold.score_manager = score_manager

	# Capture signals
	var signals_fired: Array[String] = []
	mold.mold_filled.connect(func(_mid, _fp): signals_fired.append("filled"))
	mold.mold_completed.connect(func(_mid):      signals_fired.append("completed"))
	mold.mold_contaminated.connect(func(_mid):   signals_fired.append("contaminated"))
	mold.mold_cleared.connect(func(_mid):        signals_fired.append("cleared"))
	mold.mold_tapped.connect(func(_mid):        signals_fired.append("tapped"))
	mold.part_produced.connect(func(_pid, _mid): signals_fired.append("produced"))

	var failures = 0

	# ── Test 1: empty → filling → complete (correct metal) ──────────────────
	print("\n[Test 1] empty→filling→complete (iron)")
	if mold.current_fill != 0.0:             print("  FAIL: initial fill != 0");             failures += 1
	if mold.is_complete:                     print("  FAIL: initially complete");           failures += 1
	if mold.is_contaminated:                 print("  FAIL: initially contaminated");       failures += 1

	mold.receive_metal("iron", 50.0)
	if mold.current_fill != 50.0:                   print("  FAIL: fill != 50 after 50 iron");  failures += 1
	if not signals_fired.has("filled"):             print("  FAIL: mold_filled not fired");    failures += 1

	signals_fired.clear()
	mold.receive_metal("iron", 50.0)
	if mold.current_fill < 100.0:              print("  FAIL: fill < 100");               failures += 1
	if not mold.is_complete:                  print("  FAIL: not complete");              failures += 1
	if not signals_fired.has("completed"):    print("  FAIL: mold_completed not fired");   failures += 1
	if not signals_fired.has("produced"):     print("  FAIL: part_produced not fired");    failures += 1
	if score_manager.contamination_count != 0: print("  FAIL: contamination != 0");        failures += 1
	print("  PASS")

	# ── Test 2: filling → contaminated (wrong metal mid-fill) ──────────────
	print("\n[Test 2] filling→contaminated (wrong gold mid-fill)")
	mold.clear_mold()
	signals_fired.clear()

	mold.receive_metal("iron", 30.0)
	if mold.current_fill != 30.0:             print("  FAIL: fill != 30");                 failures += 1
	if mold.is_contaminated:                 print("  FAIL: contaminated early");           failures += 1

	mold.receive_metal("gold", 50.0)
	if not mold.is_contaminated:             print("  FAIL: not contaminated after wrong metal"); failures += 1
	if mold.current_metal != "gold":         print("  FAIL: current_metal != gold");        failures += 1
	if not signals_fired.has("contaminated"):print("  FAIL: mold_contaminated not fired");  failures += 1
	if score_manager.contamination_count < 1: print("  FAIL: contamination_count not incremented"); failures += 1
	print("  PASS")

	# ── Test 3: complete → wrong metal → contaminated ─────────────────────
	print("\n[Test 3] complete→contaminated (wrong metal on full mold)")
	mold.clear_mold()
	signals_fired.clear()
	mold.receive_metal("iron", 100.0)
	if not mold.is_complete: print("  FAIL: not complete"); failures += 1

	mold.receive_metal("gold", 10.0)
	if not mold.is_contaminated:                   print("  FAIL: not contaminated after wrong metal on full mold"); failures += 1
	if not signals_fired.has("contaminated"):     print("  FAIL: mold_contaminated not fired on full mold"); failures += 1
	print("  PASS")

	# ── Test 4: complete → correct metal → overflow waste ─────────────────
	print("\n[Test 4] complete→overflow waste (correct metal on full mold)")
	mold.clear_mold()
	mold.receive_metal("iron", 100.0)
	var waste_before = score_manager.waste_units
	mold.receive_metal("iron", 20.0)
	if score_manager.waste_units <= waste_before: print("  FAIL: waste not incremented"); failures += 1
	print("  PASS (waste=%.1f)" % score_manager.waste_units)

	# ── Test 5: contaminated → cleared → empty (tap to clear) ─────────────
	print("\n[Test 5] contaminated→cleared→empty (tap to clear)")
	mold.clear_mold()
	mold.receive_metal("iron", 30.0)
	mold.receive_metal("gold", 50.0)
	if not mold.is_contaminated: print("  FAIL: not contaminated"); failures += 1

	signals_fired.clear()
	mold._on_mold_tapped()
	if mold.is_contaminated:              print("  FAIL: still contaminated after clear");    failures += 1
	if mold.current_fill != 0.0:          print("  FAIL: fill != 0 after clear");           failures += 1
	if mold.current_metal != "":         print("  FAIL: current_metal != '' after clear"); failures += 1
	if not signals_fired.has("cleared"): print("  FAIL: mold_cleared not fired");           failures += 1
	print("  PASS")

	# ── Test 6: locked mold blocks receive_metal ────────────────────────────
	print("\n[Test 6] locked mold blocks receive_metal")
	mold.clear_mold()
	mold.is_locked = true
	var waste_before_locked = score_manager.waste_units
	mold.receive_metal("iron", 100.0)
	if mold.current_fill != 0.0:                            print("  FAIL: locked mold accepted metal");      failures += 1
	if score_manager.waste_units <= waste_before_locked:   print("  FAIL: locked mold metal not → waste");   failures += 1
	print("  PASS")

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if failures == 0:
		print("==========================================")
		print("  MOLD STATE TRANSITIONS TESTS PASSED")
		print("==========================================")
	else:
		print("==========================================")
		print("  MOLD TESTS FAILED: %d assertion(s)" % failures)
		print("==========================================")

	quit(failures)
