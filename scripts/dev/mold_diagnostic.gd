##name: MoldDiagnostic
##desc: Focused diagnostic: does receive_metal trigger part_produced?
##tags: [gameplay, test]

extends SceneTree

var _tick: int = 0
var _molds: Dictionary = {}
var _order_manager: Node
var _score_manager: Node
var _signals_log: Array = []
var _phase: int = 0

func _init():
	print("")
	print("=== MOLD DIAGNOSTIC TEST ===")

	var scene_packed = load("res://scenes/Main.tscn")
	var scene_instance = scene_packed.instantiate()
	root.add_child(scene_instance)
	await process_frame
	await process_frame
	await process_frame

	_order_manager = root.get_node_or_null("/root/OrderManager")
	_score_manager = root.get_node_or_null("/root/ScoreManager")

	# Find molds
	var mold_area = root.get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		for child in mold_area.get_children():
			if "mold_id" in child:
				_molds[child.mold_id] = child

	print("  Molds found: " + str(_molds.keys()))

	if not _molds.has("blade"):
		push_error("FATAL: blade mold not found")
		quit(1)
		return

	# Wire signals on mold directly
	var blade_mold = _molds["blade"]
	if blade_mold.has_signal("part_produced"):
		blade_mold.part_produced.connect(_on_part_produced)
		print("  Connected blade.part_produced")
	if blade_mold.has_signal("mold_completed"):
		blade_mold.mold_completed.connect(_on_mold_completed)
		print("  Connected blade.mold_completed")
	if blade_mold.has_signal("mold_filled"):
		blade_mold.mold_filled.connect(_on_mold_filled)
		print("  Connected blade.mold_filled")

	if _order_manager and _order_manager.has_signal("order_started"):
		_order_manager.order_started.connect(_on_order_started)
		print("  Connected order_manager.order_started")

	if _score_manager and _score_manager.has_signal("game_over"):
		_score_manager.game_over.connect(_on_game_over)
		print("  Connected score_manager.game_over")

	if _score_manager and _score_manager.has_signal("waste_updated"):
		_score_manager.waste_updated.connect(_on_waste_updated)
		print("  Connected score_manager.waste_updated")

	print("")
	print("Starting game...")
	_order_manager.start_game()

func _on_order_started(order):
	print("[ORDER STARTED] " + order.name)
	print("  part_requests: " + str(order.part_requests))

func _on_part_produced(part_id: String, mold_id: String):
	print("[SIGNAL] part_produced: " + part_id + " mold=" + mold_id)
	_signals_log.append("part_produced:" + part_id)

func _on_mold_completed(mold_id: String):
	print("[SIGNAL] mold_completed: " + mold_id)
	_signals_log.append("mold_completed:" + mold_id)

func _on_mold_filled(mold_id: String, fill_pct: float):
	print("[SIGNAL] mold_filled: " + mold_id + " pct=" + str(fill_pct))

func _on_waste_updated(waste_pct: float):
	print("[WASTE] " + str(waste_pct) + "%")

func _on_game_over(final_score: int, waste_pct: float):
	print("[GAME OVER] score=" + str(final_score) + " waste=" + str(waste_pct) + "%")
	_dump()
	quit(0)

func _process(_delta: float):
	_tick += 1

	match _phase:
		0:
			if _tick == 5:
				print("")
				print("--- Phase 0: Pour iron to blade (expected: fill -> part_produced) ---")
				var blade = _molds["blade"]
				print("  blade state before: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete) + " locked=" + str(blade.is_locked) + " metal=" + str(blade.current_metal))
				blade.receive_metal("iron", 50.0)
				print("  blade state after 50: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete))
				_phase = 1

		1:
			if _tick == 15:
				var blade = _molds["blade"]
				print("")
				print("--- Phase 1: Pour 60 more iron (total 110, over threshold) ---")
				print("  blade state before: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete))
				blade.receive_metal("iron", 60.0)
				print("  blade state after: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete))
				_phase = 2

		2:
			if _tick == 30:
				print("")
				print("--- Phase 2: Check order manager state ---")
				if _order_manager:
					print("  current_order: " + str(_order_manager.current_order))
					print("  completed_parts count: " + str(_order_manager.get("completed_parts").size()) if _order_manager.has("completed_parts") else "  completed_parts: N/A")
				var score = _score_manager.get_total_score() if _score_manager else 0
				print("  score: " + str(score))
				print("  signals log: " + str(_signals_log))
				_phase = 3

		3:
			if _tick == 50:
				print("")
				print("--- Phase 3: Collect molds ---")
				var blade = _molds["blade"]
				print("  blade before collect: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete))
				if blade.has_method("collect"):
					blade.collect()
					print("  blade after collect: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete))
				else:
					print("  collect() not found on blade")
				var score = _score_manager.get_total_score() if _score_manager else 0
				print("  FINAL SCORE: " + str(score))
				_dump()
				quit(0)

	if _tick > 300:
		print("TIMEOUT")
		_dump()
		quit(1)

func _dump():
	print("")
	print("=== DIAGNOSTIC SUMMARY ===")
	print("  Ticks: " + str(_tick))
	print("  Signals received: " + str(_signals_log))
	var blade = _molds.get("blade")
	if blade:
		print("  blade: fill=" + str(blade.current_fill) + " complete=" + str(blade.is_complete) + " locked=" + str(blade.is_locked))
	print("==================================")
