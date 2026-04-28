##name: TestOrderTransitions
##desc: Headless test for Order 1→2→3 transitions and game_completed signal.
##tags: [test, orders, transitions]
##run: godot --headless --path . --script scripts/dev/test_order_transitions.gd --quit-after 10

extends SceneTree

var _game_completed_fired: bool = false
var _game_completed_results: Dictionary = {}
var _failures: int = 0

func _init():
	print("=== ORDER TRANSITIONS TEST ===")

	var GameDataClass    = load("res://scripts/data/GameData.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")

	var score_manager = ScoreManagerClass.new()

	var game_data = GameDataClass.new()
	game_data._ready()

	# Build OrderManager the same way the real autoload does
	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0
	order_manager.current_order = null

	# Capture signals
	var order_started_signals: Array[String] = []
	var order_completed_signals: Array[String] = []

	order_manager.order_started.connect(func(o):
		order_started_signals.append(o.name))
	order_manager.order_completed.connect(func(o, s):
		order_completed_signals.append(o.name))
	order_manager.game_completed.connect(func(r):
		_game_completed_fired = true
		_game_completed_results = r)

	# ── Test 1: Initial state ──────────────────────────────────────────────
	print("\n[Test 1] Initial state")
	var order1 = game_data.get_order(0)
	if order1.name != "Iron Sword":
		_fail("Order 1 should be 'Iron Sword', got '%s'" % order1.name)
	if order1.base_value != 100:
		_fail("Order 1 base_value should be 100, got %d" % order1.base_value)
	if order1.part_requests.get("blade") != "iron":
		_fail("Order 1 blade should need iron")
	if order1.part_requests.get("guard") != "iron":
		_fail("Order 1 guard should need iron")
	if order1.part_requests.get("grip") != "iron":
		_fail("Order 1 grip should need iron")
	print("  PASS")

	# ── Test 2: Order 1 → completion ──────────────────────────────────────
	print("\n[Test 2] Order 1 completion triggers score + order_completed signal")
	order_manager.start_game()

	if order_started_signals != ["Iron Sword"]:
		_fail("order_started should fire for Iron Sword, got %s" % str(order_started_signals))

	order_manager.complete_part("iron_blade")
	order_manager.complete_part("iron_guard")
	order_manager.complete_part("iron_grip")

	if order_completed_signals != ["Iron Sword"]:
		_fail("order_completed should fire for Iron Sword, got %s" % str(order_completed_signals))

	var score_after_order1 = score_manager.get_total_score()
	if score_after_order1 < 100:
		_fail("Score should be >= 100 after Iron Sword, got %d" % score_after_order1)
	print("  Iron Sword completed, score=%d — PASS" % score_after_order1)

	# ── Test 3: Order 2 auto-starts ───────────────────────────────────────
	print("\n[Test 3] Order 2 auto-starts after Order 1 completion")
	if order_started_signals != ["Iron Sword", "Steel Sword"]:
		_fail("order_started should fire for Steel Sword next, got %s" % str(order_started_signals))

	if order_manager.get_current_order().name != "Steel Sword":
		_fail("current_order should be Steel Sword")

	var order2 = order_manager.get_current_order()
	if order2.part_requests.get("blade") != "steel":
		_fail("Order 2 blade should need steel")
	if order2.part_requests.get("guard") != "iron":
		_fail("Order 2 guard should need iron")
	if order2.part_requests.get("grip") != "iron":
		_fail("Order 2 grip should need iron")
	print("  PASS")

	# ── Test 4: Order 2 completion ────────────────────────────────────────
	print("\n[Test 4] Order 2 completion")
	order_manager.complete_part("steel_blade")
	order_manager.complete_part("iron_guard")
	order_manager.complete_part("iron_grip")
	if order_completed_signals != ["Iron Sword", "Steel Sword"]:
		_fail("order_completed should fire for both orders, got %s" % str(order_completed_signals))
	print("  Steel Sword completed — PASS")

	# ── Test 5: Order 3 ───────────────────────────────────────────────────
	print("\n[Test 5] Order 3 (Noble Sword)")
	if order_started_signals != ["Iron Sword", "Steel Sword", "Noble Sword"]:
		_fail("order_started should fire for Noble Sword, got %s" % str(order_started_signals))

	var order3 = order_manager.get_current_order()
	if order3.name != "Noble Sword":
		_fail("Order 3 should be Noble Sword, got '%s'" % order3.name)
	if order3.part_requests.get("guard") != "gold":
		_fail("Order 3 guard should need gold")
	print("  PASS")

	# ── Test 6: Order 3 completion → game_completed ────────────────────────
	print("\n[Test 6] Order 3 completion → game_completed")
	order_manager.complete_part("steel_blade")
	order_manager.complete_part("gold_guard")
	order_manager.complete_part("iron_grip")

	if not _game_completed_fired:
		_fail("game_completed should fire after all orders")
	if _game_completed_results.get("total_score", 0) <= 0:
		_fail("game_completed results should include total_score > 0, got %s" % str(_game_completed_results))
	if _game_completed_results.get("orders_completed", 0) != 3:
		_fail("game_completed should report orders_completed=3, got %s" % str(_game_completed_results))
	print("  game_completed fired: %s — PASS" % str(_game_completed_results))

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if _failures == 0:
		print("==========================================")
		print("  ORDER TRANSITIONS TESTS PASSED")
		print("  Orders 1→2→3 + game_completed verified")
		print("==========================================")
	else:
		print("==========================================")
		print("  ORDER TRANSITION TESTS FAILED: %d assertion(s)" % _failures)
		print("==========================================")

	quit(_failures)

func _fail(msg: String):
	print("  FAIL: " + msg)
	_failures += 1
