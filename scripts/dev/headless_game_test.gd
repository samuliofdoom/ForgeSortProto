##name: HeadlessGameTest
##desc: Full gameplay test — loads Main.tscn as child, simulates gameplay
##tags: [gameplay, test, headless]

extends SceneTree

const GAME_TICK_LIMIT: int = 300

var _tick: int = 0
var _failures: int = 0

var _metal_source: Node
var _metal_flow: Node
var _flow_controller: Node
var _score_manager: Node
var _order_manager: Node
var _game_controller: Node
var _molds: Dictionary = {}

var _order_started: bool = false
var _order_complete: bool = false
var _game_over_fired: bool = false
var _game_over_score: int = 0
var _game_over_waste: float = 0.0

func _init():
	print("\n=== FORGESORTPROTO HEADLESS GAMEPLAY TEST ===")

	var scene_packed = load("res://scenes/Main.tscn")
	var scene_instance = scene_packed.instantiate()
	root.add_child(scene_instance)
	await process_frame
	await process_frame
	await process_frame

	_metal_source    = root.get_node_or_null("/root/MetalSource")
	_metal_flow      = root.get_node_or_null("/root/MetalFlow")
	_flow_controller = root.get_node_or_null("/root/FlowController")
	_score_manager   = root.get_node_or_null("/root/ScoreManager")
	_order_manager   = root.get_node_or_null("/root/OrderManager")
	_game_controller = root.get_node_or_null("/root/Main")

	var mold_area = root.get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		for child in mold_area.get_children():
			if "mold_id" in child:
				_molds[child.mold_id] = child

	_wire_signals()

	print("  MetalSource:    " + ("OK" if _metal_source else "MISSING"))
	print("  MetalFlow:      " + ("OK" if _metal_flow else "MISSING"))
	print("  FlowController: " + ("OK" if _flow_controller else "MISSING"))
	print("  ScoreManager:   " + ("OK" if _score_manager else "MISSING"))
	print("  OrderManager:   " + ("OK" if _order_manager else "MISSING"))
	print("  Molds: " + str(_molds.keys()))

	if not _flow_controller:
		push_error("FlowController missing!")
		_failures += 1
		quit(1)
		return

	var gs = _flow_controller.get("gate_states")
	print("  gate_states: " + str(gs))

	print("\nStarting game via order_manager.start_game()...")
	_order_manager.start_game()

func _wire_signals():
	if _score_manager and _score_manager.has_signal("game_over"):
		_score_manager.game_over.connect(_on_game_over)
	if _order_manager:
		if _order_manager.has_signal("order_started"):
			_order_manager.order_started.connect(_on_order_started)
		if _order_manager.has_signal("order_completed"):
			_order_manager.order_completed.connect(_on_order_completed)
	for mold in _molds.values():
		if mold.has_signal("part_produced"):
			mold.part_produced.connect(_on_part_produced)

func _on_order_started(order):
	print("[ORDER] " + order.name)
	_order_started = true

func _on_order_completed(results: Dictionary):
	print("[ORDER COMPLETED] " + str(results))
	_order_complete = true

func _on_part_produced(part_id: String, mold_id: String):
	print("[PART] " + part_id + " from " + mold_id)

func _on_game_over(final_score: int, waste_pct: float):
	print("[GAME OVER] score=" + str(final_score) + " waste=" + str(waste_pct) + "%")
	_game_over_fired = true
	_game_over_score = final_score
	_game_over_waste = waste_pct

func _process(_delta: float):
	_tick += 1

	# ── Tick 15: Verify initial gate states ────────────────────────────
	if _tick == 15:
		var gs = _flow_controller.get("gate_states")
		print("\nGate states: " + str(gs))
		if gs.get("gate_01") == false and gs.get("gate_02") == false:
			print("  Initial gates all-closed: PASS")
		else:
			print("  Initial gates: UNEXPECTED")
			_failures += 1

	# ── Tick 20: Open gates for Order 1 ───────────────────────────────
	if _tick == 20:
		_flow_controller.set_gate_state("gate_01", true)
		_flow_controller.set_gate_state("gate_02", true)
		print("\n[SETUP] G1+G2 opened")
		_verify_gate_states({"gate_01": true, "gate_02": true, "gate_03": false, "gate_04": false})

	# ── Tick 25: Pour iron to intake_a (blade) ────────────────────────
	if _tick == 25:
		print("\n[POUR 1] Iron to intake_a (blade)...")
		_metal_source.select_metal_by_id("iron")
		var mold_id = _route_metal("intake_a", "iron", 10.0)
		if mold_id == "blade":
			print("  iron -> intake_a -> blade: PASS")
		else:
			print("  iron -> intake_a -> " + str(mold_id) + ": UNEXPECTED")
			_failures += 1

	# ── Tick 50: Pour iron to intake_b (guard) ────────────────────────
	if _tick == 50:
		print("[POUR 2] Iron to intake_b (guard)...")
		var mold_id = _route_metal("intake_b", "iron", 10.0)
		if mold_id == "guard":
			print("  iron -> intake_b -> guard: PASS")
		else:
			print("  iron -> intake_b -> " + str(mold_id) + ": UNEXPECTED")
			_failures += 1

	# ── Tick 75: Pour iron to intake_c (grip) ─────────────────────────
	if _tick == 75:
		print("[POUR 3] Iron to intake_c (grip)...")
		var mold_id = _route_metal("intake_c", "iron", 10.0)
		if mold_id == "grip":
			print("  iron -> intake_c -> grip: PASS")
		else:
			print("  iron -> intake_c -> " + str(mold_id) + ": UNEXPECTED")
			_failures += 1

	# ── Tick 120: Check mold fill states ────────────────────────────────
	if _tick == 120:
		print("\n[MID-CHECK] Mold fill states at tick 120:")
		_check_molds()

	# ── Tick 150: Check mold states after hardening ───────────────────
	if _tick == 150:
		print("\n[CHECK] Mold states at tick 150 (post-hardening):")
		_check_molds()
		var parts = _get_completed_parts()
		print("  Completed parts so far: " + str(parts))
		if _order_complete:
			print("  Order completed: PASS")
		else:
			print("  Order completed: FAIL (not fired)")

	# ── Tick 200: Final score check ───────────────────────────────────
	if _tick == 200:
		var score = _score_manager.get_total_score() if _score_manager else 0
		print("\n  Score at tick 200: " + str(score))
		var parts: Array = _get_completed_parts()
		if parts.size() >= 3:
			print("  All 3 parts completed: PASS")
		else:
			print("  Parts completed: " + str(parts.size()) + "/3")
			_failures += 1

	# ── End condition ─────────────────────────────────────────────────
	if _tick >= GAME_TICK_LIMIT or _game_over_fired:
		_finish()
		quit(_failures)

# Mold needs fill_amount=100.0 to complete; call 10× with 10.0 each.
func _route_metal(intake_id: String, metal_id: String, amount: float) -> String:
	var mold_id = _flow_controller.get_mold_for_intake(intake_id)
	if mold_id != "":
		_flow_controller.route_metal_to_mold(intake_id, mold_id, metal_id, amount)
		var mold = _molds.get(mold_id)
		if mold and mold.has_method("receive_metal"):
			for i in range(10):
				mold.receive_metal(metal_id, amount)
	return mold_id

func _verify_gate_states(expected: Dictionary):
	var gs = _flow_controller.get("gate_states")
	for g in expected:
		var actual = gs.get(g, null)
		if actual != expected[g]:
			print("  GATE FAIL: " + g + " expected=" + str(expected[g]) + " actual=" + str(actual))
			_failures += 1
		else:
			print("  " + g + "=" + str(actual) + ": PASS")

func _check_molds():
	for mold_id in ["blade", "guard", "grip"]:
		var mold: Node = _molds.get(mold_id)
		if mold:
			var state = mold.get("mold_state") if "mold_state" in mold else "?"
			var complete = mold.get("is_complete") if "is_complete" in mold else false
			var fill = mold.get("fill_level") if "fill_level" in mold else -1.0
			print("  " + mold_id + ": state=" + str(state) + " complete=" + str(complete) + " fill=" + str(fill))

func _get_completed_parts() -> Array:
	if _order_manager and "completed_parts" in _order_manager:
		return _order_manager.get("completed_parts")
	return []

func _finish():
	var score = _score_manager.get_total_score() if _score_manager else 0
	var parts: Array = _get_completed_parts()
	print("\n==================================================")
	print("  HEADLESS GAMEPLAY TEST RESULT")
	print("==================================================")
	print("  Ticks: " + str(_tick) + " / " + str(GAME_TICK_LIMIT))
	print("  Failures: " + str(_failures))
	print("  Game over: " + str(_game_over_fired))
	if _game_over_fired:
		print("  Final score: " + str(_game_over_score))
		print("  Waste: " + str(_game_over_waste) + "%")
	print("  Score: " + str(score))
	print("  Completed parts: " + str(parts))
	print("==================================================")
