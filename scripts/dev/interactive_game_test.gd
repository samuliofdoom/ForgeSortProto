##name: InteractiveGameTest
##desc: Full gameplay test using proven receive_metal approach
##tags: [gameplay, test]

extends SceneTree

const TICK_LIMIT = 600

var _tick: int = 0
var _phase: int = 1

var _metal_source: Node
var _metal_flow: Node
var _flow_controller: Node
var _score_manager: Node
var _order_manager: Node
var _pour_zone: Node
var _molds: Dictionary = {}
var _gates: Dictionary = {}

var _order_complete_count: int = 0
var _parts_collected: Array = []
var _signals_wired: bool = false

func _init():
	print("")
	print("=== FORGESORTPROTO INTERACTIVE GAMEPLAY TEST ===")

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
	_pour_zone       = root.get_node_or_null("/root/Main/PourZone")

	var mold_area = root.get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		for child in mold_area.get_children():
			if "mold_id" in child:
				_molds[child.mold_id] = child
	if _molds.is_empty():
		var main = root.get_node_or_null("/root/Main")
		if main:
			for c in main.get_children():
				if "mold_id" in c:
					_molds[c.mold_id] = c

	_gates = {}
	_resolve_gates(root)

	_wire_signals()

	print("  MetalSource:    " + ("OK" if _metal_source else "MISSING"))
	print("  MetalFlow:      " + ("OK" if _metal_flow else "MISSING"))
	print("  FlowController: " + ("OK" if _flow_controller else "MISSING"))
	print("  ScoreManager:   " + ("OK" if _score_manager else "MISSING"))
	print("  OrderManager:   " + ("OK" if _order_manager else "MISSING"))
	print("  PourZone:       " + ("OK" if _pour_zone else "MISSING"))
	print("  Molds: " + str(_molds.keys()))
	print("  Gates: " + str(_gates.keys()))

	if not _flow_controller or not _order_manager:
		push_error("FATAL: Missing core autoloads")
		quit(1)
		return

	print("")
	print("Starting game via order_manager.start_game()...")
	_order_manager.start_game()

func _resolve_gates(node: Node):
	for child in node.get_children():
		var cls = child.get_class()
		if cls in ["StaticBody2D", "Node2D"]:
			if child.has_method("get_gate_id"):
				_gates[child.get_gate_id()] = child
		_resolve_gates(child)

func _wire_signals():
	if _signals_wired:
		return
	_signals_wired = true
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
	print("")
	print("[ORDER] " + order.name)

func _on_order_completed(results):
	print("[ORDER COMPLETED] " + str(results))
	_order_complete_count += 1

func _on_part_produced(part_id: String, mold_id: String):
	print("[PART] " + part_id + " from " + mold_id)
	_parts_collected.append(part_id)

func _on_game_over(final_score: int, waste_pct: float):
	print("[GAME OVER] score=" + str(final_score) + " waste=" + str(waste_pct) + "%")
	_finish()
	quit(0)

func _open_gate(gate_id: String):
	_flow_controller.set_gate_state(gate_id, true)
	var gs = _flow_controller.get("gate_states")
	print("[GATE] " + gate_id + " opened -> " + str(gs))

func _close_gate(gate_id: String):
	_flow_controller.set_gate_state(gate_id, false)

func _pour_metal_to_mold(mold_id: String, metal_id: String, units: float):
	var mold: Node = _molds.get(mold_id)
	if not mold:
		print("[WARN] Mold " + mold_id + " not found")
		return
	if mold.has_method("receive_metal"):
		mold.receive_metal(metal_id, units)
		print("[POUR] metal=" + metal_id + " mold=" + mold_id + " amount=" + str(units))
	else:
		print("[WARN] Mold " + mold_id + " has no receive_metal")

func _collect_molds():
	for mold_id in _molds:
		var mold = _molds[mold_id]
		if mold.has_method("is_complete") and mold.is_complete():
			if mold.has_method("collect"):
				mold.collect()

func _process(_delta: float):
	_tick += 1

	match _phase:
		1: _phase1()
		2: _phase2()
		3: _phase3()

	if _tick >= TICK_LIMIT:
		_finish()
		quit(0)

# Order 1: Iron Sword
# gate_01 -> intake_a/blade + intake_b/guard
# gate_02 -> intake_b/guard + intake_c/grip
# gate_03 -> all intakes
# Open G1+G3 to reach all three parts

func _phase1():
	if _tick == 10:
		print("")
		print("=== PHASE 1: Iron Sword ===")
		_open_gate("gate_01")
		_open_gate("gate_03")

	if _tick == 20:
		_pour_metal_to_mold("blade", "iron", 100.0)
	if _tick == 40:
		_pour_metal_to_mold("guard", "iron", 100.0)
	if _tick == 60:
		_pour_metal_to_mold("grip", "iron", 100.0)

	if _tick == 200:
		_collect_molds()
		var score = _score_manager.get_total_score() if _score_manager else 0
		print("[SCORE] After Order 1: " + str(score))

	if _tick == 210:
		_close_gate("gate_01")
		_close_gate("gate_03")
		_phase = 2

# Order 2: Steel Sword
# blade=steel via G3, guard=iron via G2, grip=iron via G2
# Open G2+G3

func _phase2():
	if _tick == 220:
		print("")
		print("=== PHASE 2: Steel Sword ===")
		_open_gate("gate_02")
		_open_gate("gate_03")

	if _tick == 230:
		_pour_metal_to_mold("blade", "steel", 100.0)
	if _tick == 250:
		_pour_metal_to_mold("guard", "iron", 100.0)
	if _tick == 270:
		_pour_metal_to_mold("grip", "iron", 100.0)

	if _tick == 410:
		_collect_molds()
		var score = _score_manager.get_total_score() if _score_manager else 0
		print("[SCORE] After Order 2: " + str(score))

	if _tick == 420:
		_close_gate("gate_02")
		_close_gate("gate_03")
		_phase = 3

func _phase3():
	if _tick == 430:
		_finish()
		quit(0)

func _finish():
	var score = _score_manager.get_total_score() if _score_manager else 0
	print("")
	print("==================================================")
	print("           INTERACTIVE TEST COMPLETE")
	print("==================================================")
	print("  Ticks: " + str(_tick))
	print("  Score: " + str(score))
	print("  Parts: " + str(_parts_collected))
	print("  Orders completed: " + str(_order_complete_count))
	print("==================================================")
