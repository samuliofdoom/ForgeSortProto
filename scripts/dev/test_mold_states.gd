##name: TestMoldStates
##desc: Headless test for Mold state transitions — extends SceneTree, wires Mold's deps.
##tags: [test, mold, states, contamination]
##run: godot --headless --path . --script scripts/dev/test_mold_states.gd --quit-after 15

extends SceneTree

# Mold.gd needs SceneTree for:
#   1. add_child(timer)  — Timer must be inside the scene tree to start
#   2. signal delivery    — Godot's signal bus requires a live tree
#
# Approach:
#   - Add the mold to a World proxy inside our SceneTree.
#   - Override _process in THIS SceneTree subclass to call _mold._process(delta).
#     Mold has no _process (extends Node2D) but the Timer inside it (added as a
#     child) ticks when the tree ticks — this drives the hardening timer.
#   - For tests that need to wait for hardening: call _mold._on_hardening_complete()
#     directly (the Timer's only job is to call this after 2 s; we skip the wait).

var _world: Node = null
var _mold: Node = null
var _signals_fired: Array[String] = []
var _score_manager: Node = null
var _tests_ran: bool = false

func _init():
	print("=== MOLD STATE TRANSITIONS TEST ===")

	var MoldClass         = load("res://scripts/game/Mold.gd")
	var ScoreManagerClass = load("res://scripts/game/ScoreManager.gd")
	var OrderManagerClass = load("res://scripts/game/OrderManager.gd")
	var GameDataClass     = load("res://scripts/data/GameData.gd")

	_score_manager = ScoreManagerClass.new()

	var game_data = GameDataClass.new()
	game_data._ready()

	var order_manager = Node.new()
	order_manager.set_script(OrderManagerClass)
	order_manager.game_data = game_data
	order_manager.score_manager = _score_manager
	order_manager.current_order_index = 0
	order_manager.current_order = null

	# Proxy node inside the SceneTree — Mold (Node2D) must be in the tree so
	# that add_child(timer) succeeds and Timer.tick() fires each frame.
	_world = Node.new()
	_world.name = "World"
	root.add_child(_world)

	_mold = MoldClass.new()
	_mold.mold_id = "blade"
	_mold.name    = "BladeMold"
	_mold.order_manager = order_manager
	_mold.score_manager = _score_manager
	_world.add_child(_mold)

	# Capture signals
	_signals_fired = []
	_mold.mold_filled.connect(_sig("filled"))
	_mold.mold_completed.connect(_sig("completed"))
	_mold.mold_contaminated.connect(_sig("contaminated"))
	_mold.mold_cleared.connect(_sig("cleared"))
	_mold.mold_tapped.connect(_sig("tapped"))
	_mold.part_produced.connect(_sig("produced"))

func _sig(tag: String) -> Callable:
	return func(..._args): _signals_fired.append(tag)

func _clear():
	_signals_fired = []

func _process(_delta: float):
	# Note: Mold extends Node2D and has an animation-only _process.
	# Timers tick via SceneTree's frame loop — no forwarding needed.
	if not _tests_ran:
		_tests_ran = true
		_run_tests()

# Skip the 2-second hardening timer by calling the completion handler directly.
# The Timer's only job is to call _on_hardening_complete() after 2 s — in tests
# we want immediate completion so we call it directly.
func _complete_hardening():
	_mold._on_hardening_complete()

func _run_tests():
	var failures = 0

	# ── Test 1: empty → filling → complete (correct metal) ──────────────────
	print("\n[Test 1] empty→filling→complete (iron)")
	if _mold.current_fill != 0.0:              print("  FAIL: initial fill != 0");          failures += 1
	if _mold.is_complete:                        print("  FAIL: initially complete");        failures += 1
	if _mold.is_contaminated:                    print("  FAIL: initially contaminated");    failures += 1

	_mold.receive_metal("iron", 50.0)
	if _mold.current_fill != 50.0:              print("  FAIL: fill != 50 after 50 iron"); failures += 1
	if not _signals_fired.has("filled"):        print("  FAIL: mold_filled not fired");     failures += 1

	_clear()
	_mold.receive_metal("iron", 50.0)
	if _mold.current_fill < 100.0:              print("  FAIL: fill < 100");               failures += 1
	if not _mold.is_complete:                   print("  FAIL: not complete");              failures += 1

	_complete_hardening()

	if not _signals_fired.has("completed"):  print("  FAIL: mold_completed not fired");  failures += 1
	if not _signals_fired.has("produced"):   print("  FAIL: part_produced not fired");   failures += 1
	if _score_manager.contamination_count != 0: print("  FAIL: contamination != 0");     failures += 1
	print("  PASS")

	# ── Test 2: filling → contaminated (wrong metal mid-fill) ──────────────
	print("\n[Test 2] filling→contaminated (wrong gold mid-fill)")
	_mold.clear_mold()
	_clear()

	_mold.receive_metal("iron", 30.0)
	print("  DEBUG sm=", _score_manager, " cc=", _score_manager.contamination_count)
	if _mold.current_fill != 30.0:              print("  FAIL: fill != 30");              failures += 1
	if _mold.is_contaminated:                    print("  FAIL: contaminated early");        failures += 1

	_mold.receive_metal("gold", 50.0)
	print("  DEBUG: after gold 50: is_contaminated=", _mold.is_contaminated, " contamination_count=", _score_manager.contamination_count)
	if not _mold.is_contaminated:                print("  FAIL: not contaminated after wrong metal"); failures += 1
	if _mold.current_metal != "gold":           print("  FAIL: current_metal != gold");    failures += 1
	if not _signals_fired.has("contaminated"):  print("  FAIL: mold_contaminated not fired");     failures += 1
	if _score_manager.contamination_count < 1:  print("  FAIL: contamination_count not incremented"); failures += 1
	print("  PASS")

	# ── Test 3: complete → wrong metal → contaminated ─────────────────────
	print("\n[Test 3] complete→contaminated (wrong metal on full mold)")
	_mold.clear_mold()
	_clear()
	_mold.receive_metal("iron", 100.0)
	if not _mold.is_complete:                    print("  FAIL: not complete");              failures += 1
	_complete_hardening()
	_clear()

	_mold.receive_metal("gold", 10.0)
	if not _mold.is_contaminated:                print("  FAIL: not contaminated after wrong metal on full mold"); failures += 1
	if not _signals_fired.has("contaminated"):  print("  FAIL: mold_contaminated not fired on full mold"); failures += 1
	print("  PASS")

	# ── Test 4: complete → correct metal → overflow waste ─────────────────
	print("\n[Test 4] complete→overflow waste (correct metal on full mold)")
	_mold.clear_mold()
	_mold.receive_metal("iron", 100.0)
	_complete_hardening()
	var waste_before = _score_manager.waste_units
	_mold.receive_metal("iron", 20.0)
	if _score_manager.waste_units <= waste_before: print("  FAIL: waste not incremented"); failures += 1
	print("  PASS (waste=%.1f)" % _score_manager.waste_units)

	# ── Test 5: contaminated → cleared → empty (tap to clear) ─────────────
	print("\n[Test 5] contaminated→cleared→empty (tap to clear)")
	_mold.clear_mold()
	_mold.receive_metal("iron", 30.0)
	_mold.receive_metal("gold", 50.0)
	if not _mold.is_contaminated: print("  FAIL: not contaminated"); failures += 1

	_clear()
	_mold._on_mold_tapped()
	if _mold.is_contaminated:             print("  FAIL: still contaminated after clear");    failures += 1
	if _mold.current_fill != 0.0:         print("  FAIL: fill != 0 after clear");          failures += 1
	if _mold.current_metal != "":         print("  FAIL: current_metal != '' after clear"); failures += 1
	if not _signals_fired.has("cleared"): print("  FAIL: mold_cleared not fired");         failures += 1
	print("  PASS")

	# ── Test 6: locked mold blocks receive_metal ────────────────────────────
	print("\n[Test 6] locked mold blocks receive_metal")
	_mold.clear_mold()
	_mold.is_locked = true
	var waste_before_locked = _score_manager.waste_units
	_mold.receive_metal("iron", 100.0)
	if _mold.current_fill != 0.0:                             print("  FAIL: locked mold accepted metal");    failures += 1
	if _score_manager.waste_units <= waste_before_locked:      print("  FAIL: locked mold metal not → waste"); failures += 1
	print("  PASS")

	# ── Summary ─────────────────────────────────────────────────────────────
	print("")
	if failures == 0:
		print("==========================================")
		print("  MOLD STATE TRANSITIONS TESTS PASSED")
		print("==========================================")
	else:
		print("==========================================")
		print("  MOLD TESTS FAILED: %d assertion(s)" % failures)
		print("==========================================")

	quit(failures)
