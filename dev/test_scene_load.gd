extends SceneTree

func _init():
    print("=== FULL SCENE LOAD TEST ===")
    var main_scene = preload("res://scenes/Main.tscn")
    if main_scene:
        print("Main.tscn preload OK")
        var inst = main_scene.instantiate()
        if inst:
            print("Main.tscn instantiate OK")
            inst.queue_free()  # Clean up before quit to avoid RID leaks
            quit(0)
        else:
            print("FAIL: could not instantiate Main.tscn")
            quit(1)
    else:
        print("FAIL: could not preload Main.tscn")
        quit(1)
