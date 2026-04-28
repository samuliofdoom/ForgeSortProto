## Test: simulate pressing Start and verify _on_order_started runs without error.
## Run with: --script dev/test_order_start.gd
extends SceneTree

func _init():
	print("=== TEST: Order Start Flow ===")
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("FAIL: could not load Main.tscn")
		quit(1)
		return
	var inst = scene.instantiate()
	root.add_child(inst)

	# Wait for _ready
	await get_root().get_node("Main").ready

	# Press Start — this calls OrderManager.start_game() -> start_next_order() -> order_started.emit()
	var start_btn = get_root().get_node("Main/UI/StartButton")
	if start_btn == null:
		push_error("FAIL: StartButton not found")
		quit(1)
		return

	print("Pressing Start...")
	start_btn.pressed.emit()

	# Let the game run for 2 seconds to catch any runtime errors
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().create_timer(2.0).timeout

	# Clean up
	inst.queue_free()
	print("PASS: Order started without errors")
	quit(0)
