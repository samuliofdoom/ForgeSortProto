##name: TestMoldLockCycle
##desc: Verifies locked mold adds waste, rejects fill, unlocks on next order start.
##tags: [test, mold, lock, order-cycle]
##run: godot --headless --path . --script scripts/dev/test_mold_lock_cycle.gd --quit-after 20

extends SceneTree

# Test: order_completed → is_locked=true → pours add waste → order_started → is_locked=false
# This test covers the full lock/unlock cycle in game context.
#
# Known issue (BUG-003): Mold.gd _on_order_started only clears is_complete or
# is_contaminated molds. Locked (but neither complete nor contaminated) molds
# may not be properly reset. This test verifies the fix.

func _init():
	print("=== MOLD LOCK CYCLE TEST ===")

	var failures = 0

	# ── Test 1: locked mold rejects fill and charges waste ─────────────────
	print("\n[Test 1] locked mold rejects fill + charges waste")
	var r1 = _test_locked_rejects_fill()
	if r1 == "":
		print("  Locked mold rejects fill: PASS")
	else:
		print("  Locked mold rejects fill: FAIL — " + r1)
		failures += 1

	# ── Test 2: order_completed → is_locked=true on all molds ─────────────
	print("\n[Test 2] order_completed → is_locked=true")
	var r2 = _test_locked_after_order_complete()
	if r2 == "":
		print("  Lock after order_completed: PASS")
	else:
		print("  Lock after order_completed: FAIL — " + r2)
		failures += 1

	# ── Test 3: order_started → is_locked=false ────────────────────────────
	print("\n[Test 3] order_started → is_locked=false, mold cleared")
	var r3 = _test_unlocked_after_order_start()
	if r3 == "":
		print("  Unlock after order_started: PASS")
	else:
		print("  Unlock after order_started: FAIL — " + r3)
		failures += 1

	# ── Test 4: full cycle — order 1 complete → order 2 starts ────────────
	print("\n[Test 4] full cycle: Order 1 complete → Order 2 start")
	var r4 = _test_full_order_cycle()
	if r4 == "":
		print("  Full order cycle: PASS")
	else:
		print("  Full order cycle: FAIL — " + r4)
		failures += 1

	print("")
	print("==============================================")
	if failures == 0:
		print("  ALL LOCK CYCLE TESTS PASSED")
	else:
		print("  FAILED: " + str(failures) + " test(s)")
	print("==============================================")
	quit()

# ── Test 1: Locked mold rejects fill and adds waste ───────────────────────────

func _test_locked_rejects_fill() -> String:
	var MoldClass = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0

	# Create mold
	var mold = MoldClass.new()
	mold.mold_id = "blade"
	mold.part_type = "blade"
	mold.required_metal = "iron"
	mold.order_manager = order_manager
	mold.score_manager = score_manager
	mold.game_data = game_data
	# Simulate is_locked = true (locked between orders)
	mold.is_locked = true
	mold.mold_state = MoldClass.MoldState.LOCKED

	var initial_score = score_manager.get_total_score()

	# Try to pour into locked mold
	mold.receive_metal("iron", 50.0)

	# Mold should NOT have accepted any metal
	if mold.current_fill != 0.0:
		return "locked mold should not accept metal, fill=%s" % mold.current_fill

	# ScoreManager.add_waste should have been called
	var new_score = score_manager.get_total_score()
	if new_score >= initial_score:
		return "locked mold pour should reduce score (waste), score unchanged: %s" % new_score

	return ""

# ── Test 2: order_completed → is_locked=true ───────────────────────────────────

func _test_locked_after_order_complete() -> String:
	var MoldClass = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")
	var OrderDefClass = load("res://scripts/data/OrderDefinition.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0

	# Create 3 molds
	var blade = _make_mold("blade", "blade", "iron", order_manager, score_manager, game_data)
	var guard = _make_mold("guard", "guard", "iron", order_manager, score_manager, game_data)
	var grip = _make_mold("grip", "grip", "iron", order_manager, score_manager, game_data)

	# Verify all start unlocked
	if blade.is_locked or guard.is_locked or grip.is_locked:
		return "molds should start unlocked"

	# Create an order and emit completed
	var order = OrderDefClass.new()
	order._order_name = "Iron Sword"
	order._base_value = 100
	order._parts = ["iron_blade", "iron_guard", "iron_grip"]
	order._part_requests = {"blade": "iron", "guard": "iron", "grip": "iron"}

	order_manager.order_completed.emit(order, 100)

	# After order completed, all molds should be locked
	if not blade.is_locked:
		return "blade should be locked after order_completed"
	if not guard.is_locked:
		return "guard should be locked after order_completed"
	if not grip.is_locked:
		return "grip should be locked after order_completed"

	return ""

# ── Test 3: order_started → is_locked=false, mold cleared ──────────────────────

func _test_unlocked_after_order_start() -> String:
	var MoldClass = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")
	var OrderDefClass = load("res://scripts/data/OrderDefinition.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0

	var mold = _make_mold("blade", "blade", "iron", order_manager, score_manager, game_data)

	# Simulate order completed → mold locked
	mold.is_locked = true
	mold.mold_state = MoldClass.MoldState.LOCKED

	# Verify locked
	if not mold.is_locked:
		return "mold should be locked before order_started"

	# Now emit order_started for a new order
	var new_order = OrderDefClass.new()
	new_order._order_name = "Steel Sword"
	new_order._base_value = 160
	new_order._parts = ["steel_blade", "steel_guard", "steel_grip"]
	new_order._part_requests = {"blade": "steel", "guard": "steel", "grip": "steel"}

	order_manager.order_started.connect(func(o): mold._on_order_started(o))
	mold._on_order_started(new_order)

	# After order_started, mold should be unlocked
	if mold.is_locked:
		return "mold should be unlocked after order_started (BUG-003 if this fails)"
	if mold.mold_state != MoldClass.MoldState.IDLE:
		return "mold state should be IDLE after order_started, got %s" % mold.mold_state

	return ""

# ── Test 4: Full cycle — Order 1 complete → Order 2 start ─────────────────────

func _test_full_order_cycle() -> String:
	var MoldClass = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")
	var OrderDefClass = load("res://scripts/data/OrderDefinition.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0

	# Create all 3 molds
	var blade = _make_mold("blade", "blade", "iron", order_manager, score_manager, game_data)
	var guard = _make_mold("guard", "guard", "iron", order_manager, score_manager, game_data)
	var grip = _make_mold("grip", "grip", "iron", order_manager, score_manager, game_data)

	# ── Order 1: Iron Sword ───────────────────────────────────────────────
	var order1 = OrderDefClass.new()
	order1._order_name = "Iron Sword"
	order1._base_value = 100
	order1._parts = ["iron_blade", "iron_guard", "iron_grip"]
	order1._part_requests = {"blade": "iron", "guard": "iron", "grip": "iron"}

	# Simulate filling molds with iron (just mark as filled to simulate order completion)
	blade.is_complete = true
	blade.current_fill = 100.0
	guard.is_complete = true
	guard.current_fill = 100.0
	grip.is_complete = true
	grip.current_fill = 100.0

	# Complete order 1
	order_manager.order_completed.emit(order1, 100)

	if not (blade.is_locked and guard.is_locked and grip.is_locked):
		return "all molds should be locked after order 1 complete"

	# ── Order 2: Steel Sword ──────────────────────────────────────────────
	var order2 = OrderDefClass.new()
	order2._order_name = "Steel Sword"
	order2._base_value = 160
	order2._parts = ["steel_blade", "steel_guard", "steel_grip"]
	order2._part_requests = {"blade": "steel", "guard": "steel", "grip": "steel"}

	order_manager.order_started.emit(order2)

	# All molds should be unlocked, cleared, and ready for new order
	if blade.is_locked or guard.is_locked or grip.is_locked:
		return "all molds should be unlocked after order 2 started"

	if blade.mold_state != MoldClass.MoldState.IDLE:
		return "blade state should be IDLE, got %s" % blade.mold_state
	if guard.mold_state != MoldClass.MoldState.IDLE:
		return "guard state should be IDLE, got %s" % guard.mold_state
	if grip.mold_state != MoldClass.MoldState.IDLE:
		return "grip state should be IDLE, got %s" % grip.mold_state

	# required_metal should be updated for the new order
	if blade.required_metal != "steel":
		return "blade required_metal should be 'steel' for order 2, got '%s'" % blade.required_metal

	# ── Verify locked mold adds waste during transition ────────────────────
	# During the brief window between order 1 complete and order 2 start,
	# a pour into a locked mold should add waste
	blade.is_locked = true
	blade.mold_state = MoldClass.MoldState.LOCKED
	var score_before = score_manager.get_total_score()
	blade.receive_metal("steel", 30.0)
	var score_after = score_manager.get_total_score()

	if score_after >= score_before:
		return "locked mold should add waste on pour during transition, score unchanged"

	return ""

# ── Helper ───────────────────────────────────────────────────────────────────

func _make_mold(mold_id: String, part_type: String, metal: String,
		order_manager: Node, score_manager: Node, game_data: Node) -> Node:
	var MoldClass = load("res://scripts/game/Mold.gd")
	var mold = MoldClass.new()
	mold.mold_id = mold_id
	mold.part_type = part_type
	mold.required_metal = metal
	mold.order_manager = order_manager
	mold.score_manager = score_manager
	mold.game_data = game_data
	mold.is_locked = false
	return mold
