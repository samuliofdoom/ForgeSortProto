## Verify game loads and stays running without crashing.
## Run with: --script scripts/dev/verify_game_loads.gd
extends Node

var _ticks: int = 0
var _root: Window

func _ready():
	print("=== VERIFY GAME LOADS ===")
	_root = get_window()

	# Load and add Main.tscn
	var scene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Failed to load Main.tscn")
		get_tree().quit(1)
		return
	var inst = scene.instantiate()
	_root.add_child(inst)
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
		var node = get_node_or_null(ch[1])
		if node == null:
			push_error("%s NOT FOUND at %s" % [ch[0], ch[1]])
		else:
			print("OK: %s" % ch[0])

	# Check UI
	var start_btn = get_node_or_null("/root/Main/UI/StartButton")
	if start_btn == null:
		push_error("StartButton NOT FOUND")
	else:
		print("OK: StartButton visible=%s" % start_btn.visible)

	print("=== GAME LOADED OK — staying alive for 3 seconds ===")

func _process(_delta):
	_ticks += 1
	if _ticks >= 180:  # 3 seconds at 60fps
		print("PASS: Game stayed alive for 3 seconds without crash")
		get_tree().quit(0)
