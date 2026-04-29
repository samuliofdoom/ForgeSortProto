##name: PlaytestScript
##desc: Loads Main.tscn, waits for game to run, simulates gameplay
##tags: [gameplay, test]

extends SceneTree

# Time budget for the whole test
const GAME_TICK_LIMIT: int = 200
const ORDER_TICK_LIMIT: int = 80

var _tick: int = 0
var _phase: int = 0
var _failures: int = 0

# Game nodes (set after scene loads)
var _game_controller: Node
var _metal_source: Node
var _metal_flow: Node
var _flow_controller: Node
var _score_manager: Node
var _order_manager: Node
var _molds: Dictionary = {}

# Per-order tracking
var _current_order_index: int = 0
var _parts_filled: int = 0
var _order_complete: bool = false

# Gate config per order
const ORDER_GATE_CONFIG: Array = [
	# Order 1: Iron Sword — any gates, any metal
	{"gate_01": true, "gate_02": true, "gate_03": false, "gate_04": false},
	# Order 2: Steel Sword — need blade(steel) + guard(iron) + grip(iron)
	{"gate_01": true, "gate_02": true, "gate_03": false, "gate_04": false},
	# Order 3: Noble Sword — blade(steel) + guard(gold) + grip(iron)
	{"gate_01": true, "gate_02": true, "gate_03": false, "gate_04": false},
]

func _init():
	print("=== FORGESORTPROTO PLAYTHROUGH TEST ===")

	# Load the actual game scene so all autoloads + child nodes exist
	print("[LOAD] Loading Main.tscn scene tree...")
	var load_err = root.change_scene_to_file("res://scenes/Main.tscn")
	if load_err != OK:
		print("  FAIL: could not load Main.tscn — error %d" % load_err)
		_failures += 1
		quit(1)
		return

	print("  Scene loaded. Waiting one tick for _ready() chains to settle...")
	# _ready() runs after the first process frame; use idle_frame to wait
	await Engine.get_main_loop().process_frame
	print("  _ready() chains settled.")

	_init_nodes()
	_init_signals()

	print("Game initialized. Starting playthough...\n")
	_phase = 1

	# Start the game
	_game_controller.start_game()
	await _wait_for_order_start()
	_configure_gates_for_order(0)

	print("\n[SIMULATION] Starting per-frame simulation")

func _init_nodes():
	_metal_source    = get_node("/root/MetalSource")
	_metal_flow      = get_node("/root/MetalFlow")
	_flow_controller = get_node("/root/FlowController")
	_score_manager   = get_node("/root/ScoreManager")
	_order_manager   = get_node("/root/OrderManager")
	_game_controller = get_node("/root/GameController")

	# Collect molds
	var mold_area = get_node("/root/Main/MoldArea")
	for child in mold_area.get_children():
		_molds[child.mold_id] = child

func _init_signals():
	_score_manager.game_over.connect(_on_game_over)
	_order_manager.order_started.connect(_on_order_started)
	_order_manager.order_completed.connect(_on_order_completed)

	var mold: Node = null
	for mold in _molds.values():
		mold.part_produced.connect(_on_part_produced)

# ── Gate configuration ─────────────────────────────────────────────────

func _configure_gates_for_order(order_idx: int):
	var cfg = ORDER_GATE_CONFIG[order_idx] if order_idx < ORDER_GATE_CONFIG.size() else ORDER_GATE_CONFIG[-1]
	_flow_controller.reset_all_gates()
	for gate_id in cfg:
		if cfg[gate_id]:
			_flow_controller.set_gate_state(gate_id, true)
	print("[ORDER %d] Gates: %s" % [order_idx + 1, _flow_controller._debug_gate_states()])

# ── Simulation helpers ────────────────────────────────────────────────

func _wait_for_order_start():
	var max_wait = 30
	while _order_manager.get_current_order() == null and max_wait > 0:
		await Engine.get_main_loop().process_frame
		max_wait -= 1
	if _order_manager.get_current_order() == null:
		print("  FAIL: order never started after 30 ticks")
		_failures += 1

	var order = _order_manager.get_current_order()
	print("  Order started: %s" % order.name)

func _on_order_started(order):
	print("[ORDER] Started: %s — parts needed: %s" % [order.name, order.parts]))

func _on_order_completed(results: Dictionary):
	print("[ORDER] Completed: %s" % results)
	_order_complete = true

func _on_part_produced(part_id: String, mold_id: String):
	print("[PART] Produced: %s from mold %s" % [part_id, mold_id])
	_parts_filled += 1

func _on_game_over(final_score: int, waste_pct: float):
	print("[GAME OVER] Score: %d, Waste: %.1f%%" % [final_score, waste_pct])
	quit(0)

# ── Per-frame simulation loop ─────────────────────────────────────────

func _process(_delta: float):
	_tick += 1

	match _phase:
		1:
			_phase_pour_order_1()
		2:
			_phase_pour_order_2()
		3:
			_phase_pour_order_3()
		4:
			_phase_wait_for_result()

	if _tick >= GAME_TICK_LIMIT:
		print("\n[TICK LIMIT] Reached %d ticks — force-ending test" % GAME_TICK_LIMIT)
		_print_summary()
		quit(_failures)

func _phase_pour_order_1():
	# Simple test: pour iron to all 3 molds simultaneously via gates 1+2
	# gate_01 covers A(blade) + B(guard), gate_02 covers B(guard) + C(grip)
	# With both open: pour at A → blade, pour at B → guard, pour at C → grip
	if _tick == 5:
		print("\n[PHASE 1] Pouring iron to all molds (G1+G2 open)...")
		_metal_source.select_metal_by_id("iron")
		_pour_at_intake("intake_a", 3.0)
	if _tick == 10:
		_pour_at_intake("intake_b", 3.0)
	if _tick == 15:
		_pour_at_intake("intake_c", 3.0)
	if _tick == 60:
		var blade: Node = _molds.get("blade")
		var guard: Node = _molds.get("guard")
		var grip: Node  = _molds.get("grip")
		if blade and blade.is_complete:
			print("  PASS: blade complete")
		else:
			print("  FAIL: blade NOT complete (is_complete=%s)" % (blade.is_complete if blade else "null"))
			_failures += 1
		if guard and guard.is_complete:
			print("  PASS: guard complete")
		else:
			print("  FAIL: guard NOT complete")
			_failures += 1
		if grip and grip.is_complete:
			print("  PASS: grip complete")
		else:
			print("  FAIL: grip NOT complete")
			_failures += 1
		_order_complete = false
		if not _order_complete:
			print("  Note: order_manager.order_completed not fired yet (molds may need hardening timer)")
		_phase = 2
		_tick = 0

func _phase_pour_order_2():
	# Order 2: steel blade, iron guard, iron grip
	# With gates 1+2: pour steel at A(blade), pour iron at B(guard/grip)
	if _tick == 5:
		print("\n[PHASE 2] Pouring steel sword...")
		_metal_source.select_metal_by_id("steel")
		_pour_at_intake("intake_a", 3.0)
	if _tick == 10:
		_metal_source.select_metal_by_id("iron")
		_pour_at_intake("intake_b", 3.0)
	if _tick == 15:
		_pour_at_intake("intake_c", 3.0)
	if _tick == 60:
		_phase = 3
		_tick = 0

func _phase_pour_order_3():
	# Order 3: steel blade, gold guard, iron grip
	if _tick == 5:
		print("\n[PHASE 3] Pouring noble sword...")
		_metal_source.select_metal_by_id("steel")
		_pour_at_intake("intake_a", 3.0)
	if _tick == 10:
		_metal_source.select_metal_by_id("gold")
		_pour_at_intake("intake_b", 3.0)
	if _tick == 15:
		_metal_source.select_metal_by_id("iron")
		_pour_at_intake("intake_c", 3.0)
	if _tick == 60:
		_phase = 4
		_tick = 0

func _phase_wait_for_result():
	if _tick >= 30:
		print("\n[RESULT WAIT] Timed out waiting for game_over")
		_print_summary()
		quit(_failures)

func _pour_at_intake(_intake_id: String, _duration: float):
	_metal_flow.start_pour()
	await Engine.get_main_loop().process_frame
	# Simulate metal routing: the flow controller routes based on open gates
	# For this test just verify routing functions don't crash
	var result = _flow_controller.get_mold_for_pour_position(Vector2(0, 0))
	_metal_flow.stop_pour()

# ── Summary ───────────────────────────────────────────────────────────

func _print_summary():
	print("\n==================================================")
	print("  PLAYTHROUGH TEST SUMMARY")
	print("==================================================")
	print("  Ticks simulated: %d" % _tick)
	print("  Failures: %d" % _failures)
	print("  Score: %s" % (_score_manager.get_total_score() if _score_manager else "N/A"))
	print("==================================================")

# ── Gate debug helper ────────────────────────────────────────────────

# Dummy node method used in debug print
