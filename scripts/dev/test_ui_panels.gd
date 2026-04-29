##name: TestUIPanels
##desc: Headless test for UI panel runtime logic — OrderPanel, GateToggleUI, ScoreDisplay, WasteMeter, SpeedTimer
##tags: [test, ui, panels]
##run: godot --headless --path . --script scripts/dev/test_ui_panels.gd --quit-after 20

extends SceneTree

func _init():
	print("=== UI PANELS HEADLESS TEST ===")

	var failures = 0

	# ── OrderPanel ────────────────────────────────────────────────────────────
	print("\n[Test 1] OrderPanel: initial state + order started")
	var order_panel = _test_order_panel()
	if order_panel == "":
		print("  OrderPanel: PASS")
	else:
		print("  OrderPanel: FAIL — " + order_panel)
		failures += 1

	# ── GateToggleUI ─────────────────────────────────────────────────────────
	print("\n[Test 2] GateToggleUI: button states sync with gate toggles")
	var gate_result = _test_gate_toggle_ui()
	if gate_result == "":
		print("  GateToggleUI: PASS")
	else:
		print("  GateToggleUI: FAIL — " + gate_result)
		failures += 1

	# ── ScoreDisplay ─────────────────────────────────────────────────────────
	print("\n[Test 3] ScoreDisplay: updates on score_updated signal")
	var score_result = _test_score_display()
	if score_result == "":
		print("  ScoreDisplay: PASS")
	else:
		print("  ScoreDisplay: FAIL — " + score_result)
		failures += 1

	# ── WasteMeter ───────────────────────────────────────────────────────────
	print("\n[Test 4] WasteMeter: progress updates on waste_updated signal")
	var waste_result = _test_waste_meter()
	if waste_result == "":
		print("  WasteMeter: PASS")
	else:
		print("  WasteMeter: FAIL — " + waste_result)
		failures += 1

	# ── SpeedTimer ────────────────────────────────────────────────────────────
	print("\n[Test 5] SpeedTimer: starts on order_started, resets on order_completed")
	var speed_result = _test_speed_timer()
	if speed_result == "":
		print("  SpeedTimer: PASS")
	else:
		print("  SpeedTimer: FAIL — " + speed_result)
		failures += 1

	# ── Summary ──────────────────────────────────────────────────────────────
	print("")
	print("==============================================")
	if failures == 0:
		print("  ALL UI PANEL TESTS PASSED")
	else:
		print("  FAILED: " + str(failures) + " test(s)")
	print("==============================================")
	quit()

# ── OrderPanel ─────────────────────────────────────────────────────────────────

func _test_order_panel() -> String:
	var OrderPanelClass = load("res://scripts/ui/OrderPanel.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")
	var OrderDefClass = load("res://scripts/data/OrderDefinition.gd")

	# Minimal autoloads
	var score_manager = ScoreManagerClass.new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager
	order_manager.current_order_index = 0
	order_manager.current_order = null

	var order_panel = Control.new()
	order_panel.set_script(OrderPanelClass)
	order_panel.order_manager = order_manager
	order_panel.score_manager = score_manager

	# Minimal scene tree for OrderPanel to find MoldArea
	var main = Node2D.new()
	main.name = "Main"
	var mold_area = Node2D.new()
	mold_area.name = "MoldArea"
	mold_area.set_script(load("res://scripts/game/MoldAreaDummy.gd"))  # Will fail but satisfies get_node_or_null
	root.add_child(main)
	main.add_child(mold_area)

	order_panel._ready()

	# Initial state: "No Order"
	if order_panel.order_name_label.text != "No Order":
		return "initial text should be 'No Order', got '%s'" % order_panel.order_name_label.text

	# Simulate order started
	var order = OrderDefClass.new()
	order._order_name = "Iron Sword"
	order._base_value = 100
	order._parts = ["iron_blade", "iron_guard", "iron_grip"]
	order._part_requests = {"blade": "iron", "guard": "iron", "grip": "iron"}

	order_manager.order_started.emit(order)

	if not order_panel.current_order:
		return "current_order should be set after order_started"
	if order_panel.order_name_label.text.find("Iron Sword") < 0:
		return "order name label should contain 'Iron Sword', got '%s'" % order_panel.order_name_label.text
	if order_panel.order_progress.value != 0.0:
		return "order progress should start at 0, got %s" % order_panel.order_progress.value

	# Simulate parts completed
	var completed = ["iron_blade", "iron_guard"]
	order_manager.completed_parts_changed.emit(completed)
	# Progress should be 2/3 = 66.6...%
	if order_panel.order_progress.value < 65.0 or order_panel.order_progress.value > 68.0:
		return "progress should be ~66%% after 2/3 parts, got %s" % order_panel.order_progress.value

	# Cleanup
	order_panel.queue_free()
	main.queue_free()
	return ""

# ── GateToggleUI ───────────────────────────────────────────────────────────────

func _test_gate_toggle_ui() -> String:
	var GateToggleUIClass = load("res://scripts/ui/GateToggleUI.gd")
	var FlowControllerClass = load("res://scripts/game/FlowController.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")

	# Minimal GameController for FlowController
	var GameControllerClass = load("res://scripts/game/GameController.gd")
	var game_controller = Node.new()
	game_controller.set_script(GameControllerClass)

	var flow_controller = Node.new()
	flow_controller.set_script(FlowControllerClass)
	flow_controller.game_controller = game_controller

	var ui = Control.new()
	ui.set_script(GateToggleUIClass)
	ui.flow_controller = flow_controller

	# Create minimal button/route label hierarchy that GateToggleUI expects
	_setup_gate_ui_hierarchy(ui)

	# Wire up
	ui._ready()

	# Verify initial button states (all closed → white)
	# GateToggleUI button signals are internal, so just verify the _update_button_states works
	# Reset gates to known state
	flow_controller.reset_all_gates()
	ui._update_button_states()

	var failures = ""
	# All 4 gates closed → buttons should be white (not green)
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		var btn = ui.gate_buttons.get(gate_id)
		if btn and btn.modulate != Color.WHITE:
			failures += "%s should be WHITE when closed, " % gate_id

	# Open gate_01 → should turn green
	flow_controller.set_gate_state("gate_01", true)
	ui._update_button_states()
	if ui.gate_buttons["gate_01"].modulate != Color.GREEN:
		failures += "gate_01 should be GREEN when open, "

	# Open gate_02 → green
	flow_controller.set_gate_state("gate_02", true)
	ui._update_button_states()
	if ui.gate_buttons["gate_02"].modulate != Color.GREEN:
		failures += "gate_02 should be GREEN when open, "

	ui.queue_free()
	flow_controller.queue_free()
	game_controller.queue_free()
	return failures

func _setup_gate_ui_hierarchy(ui: Control):
	# GateToggleUI references: $Gate01Button, $Gate01Route, etc.
	# Create minimal nodes so @onready doesn't crash
	for gate_num in ["01", "02", "03", "04"]:
		var btn = Button.new()
		btn.name = "Gate%sButton" % gate_num
		btn.toggle_mode = true
		ui.add_child(btn)

		var lbl = Label.new()
		lbl.name = "Gate%sRoute" % gate_num
		ui.add_child(lbl)

# ── ScoreDisplay ───────────────────────────────────────────────────────────────

func _test_score_display() -> String:
	var ScoreDisplayClass = load("res://scripts/ui/ScoreDisplay.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")

	var score_manager = ScoreManagerClass.new()
	var display = Label.new()
	display.set_script(ScoreDisplayClass)
	display.score_manager = score_manager
	display._ready()

	# Initial score should be 0
	if display.text.find("0") < 0:
		return "initial score should contain '0', got '%s'" % display.text

	# Emit score updated
	score_manager.score_updated.emit(150)
	if display.text.find("150") < 0:
		return "score display should show 150 after update, got '%s'" % display.text

	display.queue_free()
	return ""

# ── WasteMeter ────────────────────────────────────────────────────────────────

func _test_waste_meter() -> String:
	var WasteMeterClass = load("res://scripts/ui/WasteMeter.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")

	var score_manager = ScoreManagerClass.new()
	var meter = Control.new()
	meter.set_script(WasteMeterClass)
	meter.score_manager = score_manager
	meter._ready()

	# Emit waste updated (50%)
	score_manager.waste_updated.emit(50.0)
	# WasteMeter updates its waste_bar progress to waste_percent
	var bar = meter.get_node_or_null("WasteBar")
	if bar == null:
		bar = meter.get_node_or_null("WasteProgress")
	if bar == null:
		# Check if meter has a child that is the progress bar
		for ch in meter.get_children():
			if ch is ProgressBar:
				bar = ch
				break
	if bar == null:
		return "no ProgressBar child found in WasteMeter"
	if bar.value != 50.0:
		return "waste bar should be 50%%, got %s" % bar.value

	meter.queue_free()
	return ""

# ── SpeedTimer ────────────────────────────────────────────────────────────────

func _test_speed_timer() -> String:
	var SpeedTimerClass = load("res://scripts/ui/SpeedTimer.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass = load("res://scripts/data/GameData.gd")

	var score_manager = load("res://scripts/game/ScoreManager.gd").new()
	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = score_manager

	var timer = Label.new()
	timer.set_script(SpeedTimerClass)
	timer.order_manager = order_manager
	timer._ready()

	# Initial state: shows "0.0s"
	if timer.text != "0.0s":
		return "initial timer should be '0.0s', got '%s'" % timer.text

	# order_start_time set by _on_order_started
	var OrderDefClass = load("res://scripts/data/OrderDefinition.gd")
	var order = OrderDefClass.new()
	order._order_name = "Test"
	order._base_value = 100
	order._parts = []
	order._part_requests = {}

	order_manager.order_started.emit(order)

	# order_start_time should now be non-zero
	if timer.order_start_time == 0:
		return "order_start_time should be set after order_started"

	# Timer should now be counting (simulate 1 frame of _process)
	timer._process(0.0)
	if timer.text == "0.0s":
		# Timer may show 0.0s in headless (Time.get_ticks_msec() resolution)
		pass  # Accept either 0.0s or small value
	else:
		# text should be in format "Xs"
		if not timer.text.ends_with("s"):
			return "timer text should end with 's', got '%s'" % timer.text

	# Simulate order completed → timer resets
	order_manager.order_completed.emit(order, 100)
	if timer.order_start_time != 0:
		return "order_start_time should reset to 0 after order_completed, got %s" % timer.order_start_time

	timer.queue_free()
	return ""
