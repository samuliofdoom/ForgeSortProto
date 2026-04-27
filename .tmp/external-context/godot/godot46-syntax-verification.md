---
source: Official Godot 4.6 Docs (docs.godotengine.org/en/stable)
library: godot
package: godot4
topic: Area2D, Control, Button, InputEventMouseButton, @onready
fetched: 2026-04-27
---

# Godot 4.6 GDScript Syntax Verification

## 1. Area2D `area_entered` Signal

**✅ EXISTS - Signature:**
```
area_entered(area: Area2D)
```

The signal is emitted when a received `area` enters this area. Requires `monitoring` to be set to `true`.

Source: https://docs.godotengine.org/en/stable/classes/class_area2d.html#signals

---

## 2. Control with `@onready` - Referencing Non-existent Child Nodes

**✅ SAFE - `@onready` is designed for this purpose**

The `@onready` annotation defers initialization of a member variable until `_ready()` is called. This is the intended pattern because:

- Nodes can only be obtained via `get_node()` when the scene is in the active tree
- `@onready` delays the `get_node()` call until `Node._ready()` is invoked
- This ensures the child nodes already exist at initialization time

**Pattern:**
```gdscript
@onready var my_label = get_node("MyLabel")
```

This is equivalent to:
```gdscript
var my_label

func _ready():
    my_label = get_node("MyLabel")
```

Source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#onready-annotation

---

## 3. Button.toggled Signal (inherited from BaseButton)

**✅ EXISTS - Signature:**
```
toggled(toggled_on: bool)
```

Emitted when the button was just toggled between pressed and normal states (only if `toggle_mode` is active). The new state is contained in the `toggled_on` argument.

Note: The `Button` class inherits from `BaseButton` where this signal is defined.

Source: https://docs.godotengine.org/en/stable/classes/class_basebutton.html#signals

---

## 4. InputEventMouseButton `position` Property

**❌ NOT on InputEventMouseButton directly - inherited from InputEventMouse**

`InputEventMouseButton` inherits from `InputEventMouse`, which has the `position` property:

```
position: Vector2 (property on InputEventMouse)
```

When received in `Node._input()` or `Node._unhandled_input()`, returns the mouse's position in the Viewport this Node is in.

When received in `Control._gui_input()`, returns the mouse's position in the Control using the local coordinate system of the Control.

Source: https://docs.godotengine.org/en/stable/classes/class_inputeventmouse.html#properties
Source: https://docs.godotengine.org/en/stable/classes/class_inputeventmousebutton.html

---

## Summary

| Pattern | Status | Notes |
|---------|--------|-------|
| `Area2D.area_entered(area: Area2D)` | ✅ Valid | |
| `@onready var x = get_node("Child")` | ✅ Safe | Deferred until `_ready()` |
| `Button.toggled(toggled_on: bool)` | ✅ Valid | Inherited from BaseButton |
| `InputEventMouseButton.position` | ⚠️ Inherited | Defined on InputEventMouse parent |
