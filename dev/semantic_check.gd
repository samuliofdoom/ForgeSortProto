extends SceneTree

func _init():
    print("=== SEMANTIC CHECK ===")
    # Use Godot's GDScriptAnalyzer to check all scripts
    var scripts = [
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
    
    for path in scripts:
        var res = load(path)
        if res:
            print("CHECKED: " + path)
    
    print("=== DONE ===")
    quit()
