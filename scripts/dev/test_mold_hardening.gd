##name: TestMoldHardening
##desc: Headless test for Mold hardening phase — FILLING → HARDENING → COMPLETE.
##tags: [test, mold, hardening, state]
##run: godot --headless --path . --script scripts/dev/test_mold_hardening.gd --quit-after 10

extends SceneTree

var _errors: int = 0
var _tests_run: int = 0

func _init():
	print("=== MOLD HARDENING TEST ===")

	var MoldClass        = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass    = load("res://scripts/data/GameData.gd")

	var score_manager = ScoreManagerClass.new()

	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0
	order_manager.current_order = null

	var mold = MoldClass.new()
	mold.mold_id = "blade"
	mold.name    = "BladeMold"
	mold.order_manager = order_manager
	mold.score_manager = score_manager

	# Signal tracking
	var signals_fired: Array[String] = []
	var part_produced_id: String = ""
	mold.mold_completed.connect(func(_mid): signals_fired.append("completed"))
	mold.mold_contaminated.connect(func(_mid): signals_fired.append("contaminated"))
	mold.mold_cleared.connect(func(_mid):  signals_fired.append("cleared"))
	mold.part_produced.connect(func(pid, _mid):
		signals_fired.append("produced")
		part_produced_id = pid)

	# ── Test 1: fill to 100% → enters HARDENING state ───────────────────────
	print("\n[Test 1] fill to 100% → mold_state = HARDENING")
	mold.clear_mold()
	signals_fired.clear()

	mold.receive_metal("iron", 50.0)
	_tests_run += 1
	if mold.mold_state != MoldClass.MoldState.FILLING:
		_errors += 1
		print("  FAIL: state should be FILLING after 50/100, got %s" % str(mold.mold_state))
	else:
		print("  PASS (state=FILLING)")

	mold.receive_metal("iron", 50.0)  # triggers _trigger_complete()
	_tests_run += 1
	if mold.mold_state != MoldClass.MoldState.HARDENING:
		_errors += 1
		print("  FAIL: state should be HARDENING after 100/100, got %s" % str(mold.mold_state))
	else:
		print("  PASS (state=HARDENING)")

	_tests_run += 1
	if not signals_fired.has("completed"):
		_errors += 1
		print("  FAIL: mold_completed should fire at start of HARDENING")
	else:
		print("  PASS (mold_completed fired)")

	_tests_run += 1
	if signals_fired.has("produced"):
		_errors += 1
		print("  FAIL: part_produced should NOT fire during HARDENING")
	else:
		print("  PASS (part_produced NOT fired during HARDENING)")

	_tests_run += 1
	if mold.current_metal != "iron":
		_errors += 1
		print("  FAIL: current_metal should be iron, got '%s'" % mold.current_metal)
	else:
		print("  PASS (current_metal=iron)")

	# ── Test 2: 2-second hardening timer → COMPLETE → part_produced ─────────
	print("\n[Test 2] hardening timer → COMPLETE → part_produced")
	# Manually fast-forward by calling _on_hardening_complete() directly
	# (the actual timer is 2s; in headless test we skip real time)
	signals_fired.clear()
	part_produced_id = ""

	var hardening_timer = mold._hardening_timer
	if hardening_timer == null:
		_errors += 1
		print("  FAIL: _hardening_timer should exist during HARDENING")
	else:
		_tests_run += 1
		if abs(hardening_timer.wait_time - 2.0) > 0.01:
			_errors += 1
			print("  FAIL: hardening timer should be 2.0s, got %.2f" % hardening_timer.wait_time)
		else:
			print("  PASS (timer wait_time=2.0)")

		# Simulate the timer firing
		hardening_timer.timeout.emit()

	_tests_run += 1
	if mold.mold_state != MoldClass.MoldState.COMPLETE:
		_errors += 1
		print("  FAIL: state should be COMPLETE after timer fires, got %s" % str(mold.mold_state))
	else:
		print("  PASS (state=COMPLETE)")

	_tests_run += 1
	if not signals_fired.has("produced"):
		_errors += 1
		print("  FAIL: part_produced should fire after hardening complete")
	else:
		print("  PASS (part_produced fired)")

	_tests_run += 1
	if part_produced_id != "iron_blade":
		_errors += 1
		print("  FAIL: part_id should be iron_blade, got '%s'" % part_produced_id)
	else:
		print("  PASS (part_id=iron_blade)")

	# ── Test 3: receive_metal during HARDENING → waste ──────────────────────
	print("\n[Test 3] receive_metal during HARDENING → waste")
	mold.clear_mold()
	signals_fired.clear()
	mold.receive_metal("iron", 50.0)
	mold.receive_metal("iron", 50.0)  # enters HARDENING

	var waste_before = score_manager.waste_units
	mold.receive_metal("iron", 10.0)   # try to add more during hardening

	_tests_run += 1
	if score_manager.waste_units <= waste_before:
		_errors += 1
		print("  FAIL: waste should increase when metal added during HARDENING")
	else:
		print("  PASS (waste increased during HARDENING)")

	# ── Test 4: clear_mold during HARDENING cancels timer ───────────────────
	print("\n[Test 4] clear_mold during HARDENING cancels timer")
	mold.clear_mold()
	mold.receive_metal("iron", 50.0)
	mold.receive_metal("iron", 50.0)  # enters HARDENING

	var timer_before = mold._hardening_timer
	mold.clear_mold()

	_tests_run += 1
	if mold.mold_state != MoldClass.MoldState.IDLE:
		_errors += 1
		print("  FAIL: state should be IDLE after clear during HARDENING, got %s" % str(mold.mold_state))
	else:
		print("  PASS (state=IDLE after clear)")

	_tests_run += 1
	if mold._hardening_timer != null:
		_errors += 1
		print("  FAIL: _hardening_timer should be null after clear, got %s" % str(mold._hardening_timer))
	else:
		print("  PASS (_hardening_timer cancelled)")

	_tests_run += 1
	if not signals_fired.has("cleared"):
		_errors += 1
		print("  FAIL: mold_cleared should fire when cleared during HARDENING")
	else:
		print("  PASS (mold_cleared fired)")

	_tests_run += 1
	if signals_fired.has("produced"):
		_errors += 1
		print("  FAIL: part_produced should NOT fire when cleared before hardening complete")
	else:
		print("  PASS (no part produced after clear)")

	# ── Test 5: order_started during HARDENING cancels timer ─────────────────
	print("\n[Test 5] order_started during HARDENING cancels timer and resets")
	mold.clear_mold()
	mold.receive_metal("iron", 50.0)
	mold.receive_metal("iron", 50.0)  # enters HARDENING

	var order_started_signals: Array[String] = []
	order_manager.order_started.connect(func(o):
		order_started_signals.append(o.name))

	var fake_order = {
		"name": "Steel Sword",
		"part_requests": {"blade": "steel", "guard": "iron", "grip": "iron"},
		"base_value": 150
	}

	var OrderDefinitionClass = load("res://scripts/data/OrderDefinition.gd")
	var order_def = OrderDefinitionClass.new()
	order_def.name = "Steel Sword"
	order_def.part_requests = {"blade": "steel", "guard": "iron", "grip": "iron"}
	order_def.base_value = 150

	order_manager._on_order_started(order_def)

	_tests_run += 1
	if mold.mold_state != MoldClass.MoldState.IDLE:
		_errors += 1
		print("  FAIL: state should be IDLE after order_started during HARDENING, got %s" % str(mold.mold_state))
	else:
		print("  PASS (state=IDLE)")

	_tests_run += 1
	if mold._hardening_timer != null:
		_errors += 1
		print("  FAIL: _hardening_timer should be cancelled by order_started, got %s" % str(mold._hardening_timer))
	else:
		print("  PASS (timer cancelled)")

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if _errors == 0:
		print("==========================================")
		print("  MOLD HARDENING TESTS PASSED — all %d tests" % _tests_run)
		print("==========================================")
		quit(0)
	else:
		print("==========================================")
		print("  MOLD HARDENING TESTS FAILED: %d assertion(s)" % _errors)
		print("==========================================")
		quit(1)
