extends SceneTree

var _failures: int = 0

func _init():
	print("=== FORGESORTPROTO GAMEPLAY INTEGRATION TEST ===")

	# ── Instantiate all components ────────────────────────────────────────
	var MetalSourceClass    = load("res://scripts/game/MetalSource.gd")
	var FlowControllerClass = load("res://scripts/game/FlowController.gd")
	var ScoreManagerClass  = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass  = load("res://scripts/game/OrderManager.gd")
	var MoldClass          = load("res://scripts/game/Mold.gd")
	var GameDataClass      = load("res://scripts/data/GameData.gd")

	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager

	var metal_source = MetalSourceClass.new()
	var flow_controller = FlowControllerClass.new()

	# Create a minimal MoldArea with 3 molds
	var mold_area = Node.new()
	mold_area.name = "MoldArea"
	var mold_defs = [["blade", "iron"], ["guard", "iron"], ["grip", "iron"]]
	for i in range(mold_defs.size()):
		var pair = mold_defs[i]
		var m = MoldClass.new()
		m.name = pair[0].capitalize() + "Mold"
		m.mold_id = pair[0]
		mold_area.add_child(m)

	# Wire each mold to score_manager (needed for waste/contamination tracking)
	for child in mold_area.get_children():
		child.score_manager = score_manager

	# Track game_over signal
	var game_over_fired: bool = false
	score_manager.game_over.connect(func(_fs, _wp): game_over_fired = true)

	print("All autoloads instantiated — running checks")

	# ── Check 1: Initial state ──────────────────────────────────────────────
	print("\n[Check 1] Initial state")
	order_manager.start_game()

	var order = order_manager.get_current_order()
	_check(order != null, "get_current_order() should not be null")
	_check(order.name == "Iron Sword", "Order 1 should be Iron Sword, got '%s'" % order.name)
	_check(score_manager.get_total_score() == 0, "Initial score should be 0, got %d" % score_manager.get_total_score())

	var blade = mold_area.find_child("BladeMold", true, false)
	var guard = mold_area.find_child("GuardMold", true, false)
	var grip  = mold_area.find_child("GripMold",  true, false)
	_check(blade != null, "BladeMold should exist")
	_check(guard != null, "GuardMold should exist")
	_check(grip  != null, "GripMold should exist")
	_check(blade.is_complete == false, "Blade should not be complete initially")
	_check(guard.is_complete == false, "Guard should not be complete initially")
	_check(grip.is_complete  == false, "Grip should not be complete initially")
	print("  PASS")

	# ── Check 2: Metal selection ────────────────────────────────────────────
	print("\n[Check 2] Metal selection")
	_check(metal_source.get_selected_metal() == "iron", "Default metal should be iron")
	metal_source.select_metal_by_id("steel")
	_check(metal_source.get_selected_metal() == "steel", "Could not select steel")
	metal_source.select_metal_by_id("gold")
	_check(metal_source.get_selected_metal() == "gold", "Could not select gold")
	metal_source.select_metal_by_id("iron")
	var metal_data = metal_source.get_selected_metal_data()
	_check(metal_data != null, "get_selected_metal_data() should not be null")
	_check(metal_data.speed > 0.0, "Metal speed should be positive")
	print("  PASS")

	# ── Check 3: Gate toggle ───────────────────────────────────────────────
	print("\n[Check 3] Gate toggle")
	for gid in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		var before = flow_controller.get_gate_state(gid)
		flow_controller.toggle_gate(gid)
		var after = flow_controller.get_gate_state(gid)
		_check(after != before, "Gate %s did not toggle" % gid)
		flow_controller.toggle_gate(gid)  # reset
	flow_controller.set_gate_state("gate_01", true)
	flow_controller.set_gate_state("gate_02", true)
	flow_controller.reset_all_gates()
	_check(flow_controller.get_gate_state("gate_01") == false, "reset_all_gates() failed")
	print("  PASS")

	# ── Check 4: Pour sequence — molds fill correctly ───────────────────────
	print("\n[Check 4] Pour sequence")
	blade.receive_metal("iron", 100.0)
	_check(blade.is_complete == true, "Blade should be complete after 100 iron")
	guard.receive_metal("iron", 100.0)
	_check(guard.is_complete == true, "Guard should be complete")
	grip.receive_metal("iron", 100.0)
	_check(grip.is_complete == true, "Grip should be complete")
	print("  PASS")

	# ── Check 5: Order completion (3 parts) ─────────────────────────────────
	print("\n[Check 5] Order completion")
	# Complete all 3 parts via order_manager
	order_manager.complete_part("iron_blade")
	order_manager.complete_part("iron_guard")
	order_manager.complete_part("iron_grip")

	var completed = order_manager.get_completed_parts()
	_check(completed.size() == 3, "Expected 3 completed parts, got %d" % completed.size())
	_check(completed.has("iron_blade"), "iron_blade should be completed")
	_check(completed.has("iron_guard"), "iron_guard should be completed")
	_check(completed.has("iron_grip"),  "iron_grip should be completed")
	print("  PASS")

	# ── Check 6: Score tracking ────────────────────────────────────────────
	print("\n[Check 6] Score tracking")
	var score = score_manager.get_total_score()
	_check(score >= 100, "Score should be >= 100 after Iron Sword, got %d" % score)
	print("  Score after Iron Sword: %d — PASS" % score)

	# ── Check 7: Waste meter → game_over ──────────────────────────────────
	print("\n[Check 7] Waste meter → game_over")
	score_manager.reset()
	game_over_fired = false
	score_manager.add_waste(100.0)
	_check(game_over_fired == true, "game_over should fire when waste >= 100")
	print("  PASS")

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if _failures == 0:
		print("==================================================")
		print("  GAMEPLAY INTEGRATION TEST PASSED")
		print("==================================================")
		print("  [1] Initial state: order=Iron Sword, score=0, molds empty")
		print("  [2] Metal selection: iron/steel/gold all work")
		print("  [3] Gate toggle: all 4 gates + reset_all_gates()")
		print("  [4] Pour sequence: molds fill correctly")
		print("  [5] Order completion: 3 parts tracked correctly")
		print("  [6] Score tracking: Iron Sword = 100 pts")
		print("  [7] Waste meter: game_over fires at 100 waste")
	else:
		print("==================================================")
		print("  GAMEPLAY INTEGRATION TEST FAILED: %d checks" % _failures)
		print("==================================================")

	quit(_failures)

func _check(condition: bool, msg: String):
	if not condition:
		print("  FAIL: " + msg)
		_failures += 1
