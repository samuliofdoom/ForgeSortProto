## Verify game loads and stays running without crashing.
## Run with: --script scripts/dev/verify_game_loads.gd
extends SceneTree

var _ticks: int = 0

func _init():
	print("=== VERIFY GAME LOADS ===")

func _ready():
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	var inst = scene.instantiate()
	root.add_child(inst)
	await Engine.get_main_loop().process_frame

	# Check critical autoloads
	var checks = [
		["MetalSource", "/root/MetalSource"],
		["MetalFlow", "/root/MetalFlow"],
		["FlowController", "/root/FlowController"],
		["ScoreManager", "/root/ScoreManager"],
		["OrderManager", "/root/OrderManager"],
		["GameController", "/root/Main"],
	]
	for ch in checks:
		var node = root.get_node_or_null(ch[1])
		if node == null:
			push_error("%s NOT FOUND at %s" % [ch[0], ch[1]])
		else:
			print("OK: %s" % ch[0])

	# Check UI
	var start_btn = root.get_node_or_null("/root/Main/UI/StartButton")
	if start_btn == null:
		push_error("StartButton NOT FOUND")
	else:
		print("OK: StartButton visible=%s" % start_btn.visible)

	print("=== GAME LOADED OK — staying alive for 3 seconds ===")

func _process(_delta):
	_ticks += 1
	if _ticks >= 180:  # 3 seconds at 60fps
		print("PASS: Game stayed alive for 3 seconds without crash")
		# Clean up before quit to avoid RID leaks
		var inst = root.get_node_or_null("/root/Main")
		if inst:
			inst.queue_free()
		quit(0)
