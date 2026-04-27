extends SceneTree

func _init():
	print("=== ForgeSortProto Smoke Check ===")
	var errors = 0

	# Check main scene
	var main = load("res://scenes/Main.tscn")
	if main:
		print("OK: Main.tscn loaded")
	else:
		print("ERROR: Main.tscn failed to load")
		errors += 1

	# Check all scripts parse/load
	var scripts = [
		"res://scripts/data/GameData.gd",
		"res://scripts/data/OrderDefinition.gd",
		"res://scripts/data/MoldDefinition.gd",
		"res://scripts/data/MetalDefinition.gd",
		"res://scripts/game/ScoreManager.gd",
		"res://scripts/game/MetalSource.gd",
		"res://scripts/game/OrderManager.gd",
		"res://scripts/game/FlowController.gd",
		"res://scripts/game/MetalFlow.gd",
		"res://scripts/game/GameController.gd",
		"res://scripts/game/Mold.gd",
		"res://scripts/game/Gate.gd",
		"res://scripts/game/PourZone.gd",
		"res://scripts/game/Intake.gd",
		"res://scripts/game/PartPopEffect.gd",
		"res://scripts/ui/MetalSelector.gd",
		"res://scripts/ui/OrderPanel.gd",
		"res://scripts/ui/ScoreDisplay.gd",
		"res://scripts/ui/WasteMeter.gd",
		"res://scripts/ui/GateToggleUI.gd",
		"res://scripts/ui/ResultPanel.gd",
		"res://scripts/ui/PartPopLabel.gd"
	]
	for path in scripts:
		var s = load(path)
		if s:
			print("OK: " + path)
		else:
			print("ERROR: " + path + " failed to load")
			errors += 1

	print("")
	if errors == 0:
		print("SMOKE CHECK PASSED")
	else:
		print("SMOKE CHECK FAILED: " + str(errors) + " error(s)")
	quit(errors)
