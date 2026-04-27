extends SceneTree

# Phase 1: load() + .new() each game/UI script.
#   .new() forces full compilation → Godot emits unused-parameter and other
#   semantic warnings to stderr, which validate.sh captures and fails on.
#
# Phase 2: load() only the data-definition scripts that have required ctor
#   args (OrderDefinition, MoldDefinition, MetalDefinition).  Skipping .new()
#   for these avoids "expected N argument(s)" runtime errors; they have no
#   complex logic that could produce semantic warnings anyway.
#
# If a script's .new() fails because _init requires arguments, it will print
# an error to stderr (compile-time, before this script runs) and return null.
# We skip the free() call in that case.

func _init():
	print("=== ForgeSortProto Smoke Check ===")
	var failures = 0

	# Scripts that can be safely .new()'d (default _init, no required args)
	var instantiable = [
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
		"res://scripts/ui/PartPopLabel.gd",
	]

	# Data definitions — load() only (custom _init requires args)
	var load_only = [
		"res://scripts/data/GameData.gd",
		"res://scripts/data/OrderDefinition.gd",
		"res://scripts/data/MoldDefinition.gd",
		"res://scripts/data/MetalDefinition.gd",
	]

	print("--- Loading data definitions (no instantiation) ---")
	for path in load_only:
		var s = load(path)
		if s:
			print("OK: " + path)
		else:
			print("ERROR: " + path + " failed to load")
			failures += 1

	print("\n--- Instantiating game/UI scripts (triggers full compilation) ---")
	for path in instantiable:
		var cls = load(path)
		if not cls:
			print("ERROR: " + path + " failed to load")
			failures += 1
			continue

		# .new() forces compilation.  If _init has required args this prints
		# a compile-time error before _init even runs, and returns null.
		var inst = cls.new()
		if inst:
			print("OK: " + path)
			# free() is safe on most Node subclasses; skip if null.
			if "free" in inst:
				inst.free()
		else:
			# .new() returned null — something went wrong at construction time.
			# The error will already be in stderr; count it as a failure.
			print("WARN: " + path + " .new() returned null (check stderr)")
			failures += 1

	print("")
	if failures == 0:
		print("SMOKE CHECK PASSED")
	else:
		print("SMOKE CHECK FAILED: " + str(failures) + " error(s)")
	quit(failures)
