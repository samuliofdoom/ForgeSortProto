---
source: Godot 4.6 Official Documentation
library: godot
package: godot-engine
topic: area2d-area-entered-signal-monitoring
fetched: 2026-04-27T00:00:00Z
official_docs: https://docs.godotengine.org/en/stable/classes/class_area2d.html
---

# Area2D `area_entered` Signal Requirements

## Signal Definition

```gdscript
area_entered(area: Area2D)
```

Emitted when the received `area` enters this area.

## Critical Requirement: `monitoring` Must Be `true`

**YES, `monitoring` MUST be enabled** for `area_entered` (and all detection signals) to work.

From the official documentation:

> **Requires [monitoring](#class-area2d-property-monitoring) to be set to `true`.**

## The `monitoring` Property

```gdscript
bool monitoring = true
```

If `true`, the area detects bodies or areas entering and exiting it.

### Default Value
`monitoring` defaults to `true` - so areas detect by default.

### Code Example

```gdscript
extends Area2D

func _ready():
    # These signals require monitoring = true (default)
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)
    
    # You can also check current state
    print("Monitoring: ", monitoring)

func _on_area_entered(area: Area2D):
    print("Area entered: ", area.name)

func _on_area_exited(area: Area2D):
    print("Area exited: ", area.name)

# To disable detection:
func disable_detection():
    monitoring = false  # area_entered/exited will no longer fire

func enable_detection():
    monitoring = true
```

## Related Properties

| Property | Default | Description |
|----------|---------|-------------|
| `monitoring` | `true` | Enable/disable detection of entering/exiting areas |
| `monitorable` | `true` | Whether OTHER areas can detect this area |
| `collision_mask` | `1` | Which layers this area detects on |
| `collision_layer` | `1` | Which layer this area is on |

## All Signals That Require `monitoring = true`

1. `area_entered(area: Area2D)`
2. `area_exited(area: Area2D)`
3. `area_shape_entered(...)`
4. `area_shape_exited(...)`
5. `body_entered(body: Node2D)`
6. `body_exited(body: Node2D)`
7. `body_shape_entered(...)`
8. `body_shape_exited(...)`

## Common Mistakes

```gdscript
# WRONG - area_entered won't fire
var my_area = Area2D.new()
my_area.monitoring = false  # Detection disabled!
add_child(my_area)

# CORRECT
var my_area = Area2D.new()
my_area.monitoring = true  # Explicit (though it's default)
add_child(my_area)
```

## Tutorial Reference

See: [Using Area2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html)
