extends SceneTree

func _init():
    print("=== PROBLEMS FETCH ===")
    var errors = []
    var warnings = []
    var script_paths = [
        "res://scripts/game/ScoreManager.gd",
        "res://scripts/game/OrderManager.gd",
        "res://scripts/game/MetalFlow.gd",
        "res://scripts/game/FlowController.gd",
        "res://scripts/game/PourZone.gd",
        "res://scripts/game/Mold.gd",
        "res://scripts/game/Gate.gd",
        "res://scripts/game/Intake.gd",
        "res://scripts/game/MetalSource.gd",
        "res://scripts/game/GameController.gd",
        "res://scripts/ui/GateToggleUI.gd",
        "res://scripts/ui/WasteMeter.gd",
        "res://scripts/ui/OrderPanel.gd",
        "res://scripts/ui/ScoreDisplay.gd",
        "res://scripts/ui/MetalSelector.gd",
        "res://scripts/ui/ResultPanel.gd",
        "res://scripts/data/GameData.gd",
        "res://scripts/data/MetalDefinition.gd",
    ]
    for p in script_paths:
        var scr = load(p)
        if scr:
            print("OK: " + p)
        else:
            errors.append("LOAD_FAIL: " + p)
    print("=== DONE: " + str(errors.size()) + " load errors ===")
    quit()
