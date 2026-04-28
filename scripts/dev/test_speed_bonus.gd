##name: TestSpeedBonus
##desc: Headless test for speed bonus calculation — extends SceneTree.
##tags: [test, speed, bonus, score]
##run: godot --headless --path . --script scripts/dev/test_speed_bonus.gd --quit-after 10

extends SceneTree

func _init():
	print("=== SPEED BONUS TEST ===")

	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var GameDataClass    = load("res://scripts/data/GameData.gd")
	var OrderDefClass    = load("res://scripts/data/OrderDefinition.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()   # initializes metals, molds, orders

	# Use the real Iron Sword order from GameData (avoids typed-array construction issues)
	var order: Resource = game_data.orders[0]
	print("  Testing with order: %s (base_value=%d)" % [order.name, order.base_value])

	var failures = 0

	# ── Test 1: Fast order (< 30s) → speed bonus applied ─────────────────
	print("\n[Test 1] Fast order (< 30s elapsed) → speed bonus +50")
	score_manager.reset()

	# Manually set start_time to NOW so elapsed ≈ 0
	score_manager.start_time = Time.get_ticks_msec()

	var earned: int = score_manager.calculate_order_score(order)
	print("  elapsed ≈ 0s, base=%d, speed_bonus=50 → earned=%d" % [order.base_value, earned])
	if earned < (order.base_value + 50):
		print("  FAIL: expected >= %d (base %d + speed 50), got %d" % [order.base_value + 50, order.base_value, earned])
		failures += 1
	else:
		print("  PASS")

	# ── Test 2: Slow order (> 30s) → no speed bonus ──────────────────────
	print("\n[Test 2] Slow order (> 30s elapsed) → no speed bonus")
	score_manager.reset()

	# Simulate 35 seconds elapsed
	score_manager.start_time = Time.get_ticks_msec() - 35000

	earned = score_manager.calculate_order_score(order)
	print("  elapsed ≈ 35s, base=%d → earned=%d" % [order.base_value, earned])
	if earned != order.base_value:
		print("  FAIL: expected exactly %d (base only, no bonus), got %d" % [order.base_value, earned])
		failures += 1
	else:
		print("  PASS")

	# ── Test 3: start_time resets on score_manager.reset() ─────────────────
	print("\n[Test 3] start_time resets on score_manager.reset()")
	score_manager.reset()

	# Advance by 20 seconds then reset again
	score_manager.start_time = Time.get_ticks_msec() - 20000
	var before: int = score_manager.start_time

	score_manager.reset()
	var after: int = score_manager.start_time

	var elapsed_after_reset: float = (Time.get_ticks_msec() - after) / 1000.0
	print("  start_time before reset = %d, after = %d, elapsed=%.1fs" % [before, after, elapsed_after_reset])
	if elapsed_after_reset > 1.0:
		print("  FAIL: start_time should be reset to now (elapsed should be < 1s)")
		failures += 1
	else:
		print("  PASS")

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if failures == 0:
		print("==========================================")
		print("  SPEED BONUS TESTS PASSED")
		print("==========================================")
	else:
		print("==========================================")
		print("  SPEED BONUS TESTS FAILED: %d assertion(s)" % failures)
		print("==========================================")

	quit(failures)
