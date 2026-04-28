@tool
extends EditorPlugin

var problems_panel = null

func _enter_tree():
    print("=== EDITOR PLUGIN LOADED ===")
    # Try to access the editor's script editor
    var script_editor = get_editor_interface().get_script_editor()
    if script_editor:
        print("Script editor found")
        var children = script_editor.get_children()
        for c in children:
            print("  child: ", c.get_class(), " ", c.name)
    else:
        print("No script editor")

    # Try to get all errors from the editor
    var ed = get_editor_interface()
    if ed:
        # Check if we can access error list
        print("Editor interface available")

    print("=== DONE ===")

func _exit_tree():
    pass
