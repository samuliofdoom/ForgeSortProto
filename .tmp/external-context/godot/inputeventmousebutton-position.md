---
source: Godot 4.6 Official Documentation
library: godot
package: godot-engine
topic: inputeventmousebutton-position-inheritance
fetched: 2026-04-27T00:00:00Z
official_docs: https://docs.godotengine.org/en/stable/classes/class_inputeventmousebutton.html
---

# InputEventMouseButton and `position` Property Inheritance

## Inheritance Hierarchy

```
InputEvent
└── InputEventFromWindow
    └── InputEventWithModifiers
        └── InputEventMouse
            ├── InputEventMouseButton
            └── InputEventMouseMotion
```

**YES**, `position` IS inherited from `InputEventMouse` into `InputEventMouseButton`.

## The `position` Property

From `InputEventMouse` class documentation:

```gdscript
Vector2 position = Vector2(0, 0)
```

> When received in `Node._input()` or `Node._unhandled_input()`, returns the mouse's position in the Viewport this Node is in using the coordinate system of this Viewport.
>
> When received in `Control._gui_input()`, returns the mouse's position in the Control using the local coordinate system of the Control.

## Direct Access in InputEventMouseButton

Since `InputEventMouseButton` inherits `position` from `InputEventMouse`, you can access it directly:

```gdscript
func _input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            # Access position directly - inherited from InputEventMouse
            var mouse_pos: Vector2 = event.position
            print("Mouse click at: ", mouse_pos)
```

## Global Position

Also inherited is `global_position`:

```gdscript
func _input(event: InputEvent):
    if event is InputEventMouseButton:
        # Global position (root viewport coordinates)
        var global_pos: Vector2 = event.global_position
        print("Global click at: ", global_pos)
```

## InputEventMouseButton Specific Properties

| Property | Type | Description |
|----------|------|-------------|
| `button_index` | MouseButton | Which button (LEFT, RIGHT, etc.) |
| `pressed` | bool | Whether button is pressed |
| `double_click` | bool | Whether this was a double-click |
| `canceled` | bool | Whether event was canceled |
| `factor` | float | Scroll amount for wheel events |

## Example: Complete Mouse Button Handler

```gdscript
func _unhandled_input(event: InputEvent):
    if event is InputEventMouseButton:
        var pos: Vector2 = event.position      # Viewport-local position
        var global_pos: Vector2 = event.global_position  # Root viewport position
        var button: int = event.button_index
        var pressed: bool = event.pressed
        
        match button:
            MOUSE_BUTTON_LEFT:
                if pressed:
                    print("Left click at ", pos)
            MOUSE_BUTTON_RIGHT:
                if pressed:
                    print("Right click at ", pos)
            MOUSE_BUTTON_WHEEL_UP:
                print("Scroll up at ", pos)
```

## Coordinate System Note

> When received in `Node._input()` or `Node._unhandled_input()`, returns the mouse's position in the Viewport this Node is in using the coordinate system of this Viewport.

For 2D nodes, this is typically your game world coordinates. For 3D, it's the camera's viewport coordinates.
