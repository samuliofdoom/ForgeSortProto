---
source: Godot 4.6 Official Documentation
library: godot
package: godot-engine
topic: gdscript-identifier-scope-errors
fetched: 2026-04-27T00:00:00Z
official_docs: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html
---

# GDScript Identifier "Not Declared in Scope" Error

## What Causes This Error

The error **"Identifier 'X' not declared in the current scope"** in GDScript occurs when you reference a variable, function, or identifier that the compiler cannot find in the current scope.

### Common Causes:

### 1. **Using a variable before it's declared**
```gdscript
# WRONG - 'my_var' used before declaration
func _ready():
    print(my_var)  # Error: my_var not declared
    var my_var = 10

# CORRECT - declare first
func _ready():
    var my_var = 10
    print(my_var)
```

### 2. **Typo in identifier name**
```gdscript
var my_variable = 10
print(my_varaible)  # Typo - different name
```

### 3. **Using local variable outside its scope**
```gdscript
func _ready():
    if true:
        var local_var = 5
    print(local_var)  # Error - local_var only exists inside the if block
```

### 4. **Missing extends statement when using parent class members**
```gdscript
# If this script should extend Node2D but extends is missing:
func _ready():
    position = Vector2(100, 100)  # Error if position not declared
```

### 5. **Forgetting to declare a variable with `var`**
```gdscript
# WRONG
my_number = 42  # Error: Identifier "my_number" not declared

# CORRECT
var my_number = 42
```

### 6. **Inner class accessing outer class members without proper scope**
```gdscript
class Inner:
    func foo():
        print(outer_var)  # Error - outer_var not accessible directly
```

## Identifiers in GDScript

From the Godot documentation:

> Any string that restricts itself to alphabetic characters (`a` to `z` and `A` to `Z`), digits (`0` to `9`) and `_` qualifies as an identifier. Additionally, identifiers must not begin with a digit. Identifiers are case-sensitive (`foo` is different from `FOO`).

## The `self` Keyword

To access class members, you may need to use `self`:
```gdscript
var health = 100

func take_damage():
    self.health -= 10  # Explicitly access member via self
```

## Static Typing Helps Catch This Early

Using static typing provides earlier detection:
```gdscript
var health: int = 100

func _ready():
    # This would be caught at compile time
    var typed_var: int = "string"  # Error - type mismatch
```

The warning system in Godot can also help identify undeclared identifiers before runtime.

---

## Related Warnings

- **UNTyped_DECLARATION**: Warns when a variable doesn't have explicit type
- **INFERRED_DECLARATION**: Warns when type inference may be ambiguous
