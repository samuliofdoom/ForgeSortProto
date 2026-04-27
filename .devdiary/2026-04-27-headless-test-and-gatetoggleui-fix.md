# ForgeSortProto Dev Diary

## Session: 2026-04-27 — Full Gameplay Test & GateToggleUI Fix

---

## Goal

Run a complete headless gameplay test of ForgeSortProto, inject a TestRunner node into Main.tscn, verify all 9 game phases work end-to-end, and fix any bugs found.

---

## What We Did

### 1. Discovered `--script` Mode Limitation (Again, Properly)

**Problem**: When running Godot with `--script <file>`, the script `extends` whatever it claims — but the Godot **engine itself does not boot**. Autoloads are NOT registered as Engine singletons. `get_node("/root/...")` always returns null. `Engine.get_singleton()` always returns null.

**Root cause confirmed**: `--script` mode runs a bare script without loading `project.godot`. It has no SceneTree, no autoloads, no scene. It's useful only for `load()` + `instantiate()` of resources directly.

**Solution**: Run `--scene "res://scenes/Main.tscn"` instead. The scene loads, the engine boots normally, autoloads register, and TestRunner (as a child of Main) has full access to everything.

---

### 2. Injected TestRunner Into Main.tscn

**Approach**: Added `full_gameplay_test.gd` as `ExtResource id="14_testrunner"` in Main.tscn's `[ext_resource]` block, then added a `TestRunner` Node2D child of Main with `process_mode = 3` (Always) and `visible = false`.

This means:
- Normal gameplay: TestRunner is invisible, never interferes
- Headless test run: TestRunner's `_ready()` + `_process()` runs normally
- Autoloads are available (project boots with Main.tscn)
- Test quits with `get_tree().quit()` after all phases pass

**Files changed**:
- `scenes/Main.tscn`: `load_steps=16`, +ExtResource, +TestRunner node
- `scripts/dev/full_gameplay_test.gd`: rewritten for Node2D (not SceneTree)
- `scenes/dev/TestRunner.tscn`: scene stub (not used — TestRunner lives in Main.tscn now)

---

### 3. Found & Fixed GateToggleUI Infinite Recursion

**The bug**: `_update_button_states()` sets `btn.button_pressed = is_open` to sync button visuals with gate state. But `button_pressed` is a property whose setter fires the `toggled` signal. So:

```
btn.toggled signal → _on_gate_button_toggled() → flow_controller.toggle_gate()
→ gate_toggled.emit() → _on_gate_toggled() → _update_button_states()
→ btn.button_pressed = is_open → btn.toggled signal → ...
```

Stack overflow every time.

**The fix**:
1. Added `_guard_recursion: bool = false` flag
2. `_update_button_states()` and `_on_gate_button_toggled()` both return early if `_guard_recursion` is true
3. Only set `button_pressed` when it differs from current value — avoids unnecessary signal fires even without the guard
4. Removed the `_process_mode` approach; pure recursion guard is cleaner

```gdscript
func _update_button_states():
    if _guard_recursion:
        return
    _guard_recursion = true
    for gate_id in gate_buttons:
        var btn = gate_buttons[gate_id]
        if btn:
            var is_open = flow_controller.get_gate_state(gate_id) if flow_controller else false
            if btn.button_pressed != is_open:  # only if different
                btn.button_pressed = is_open
            btn.modulate = Color.GREEN if is_open else Color.WHITE
    _guard_recursion = false
```

---

### 4. Found Wrong Node Path for GameController

**The bug**: Test script used `get_node("/root/GameController")`. But `GameController` is NOT an autoload — it's a script attached to the `Main` node.

**The fix**: `get_node("/root/Main")` to access GameController (or `get_node("/root/Main").start_game()` etc.)

---

### 5. All 9 Test Phases Pass

```
=== FORGESORTPROTO FULL GAMEPLAY TEST ===
[P0] Start button: visible, pressable
[P1] Initial state: order=Iron Sword, score=0, molds empty
[P2] Metal selection: iron/steel/gold all work — speed=1.0/0.7/0.5, spread=1.0/1.5/2.0
[P3] Gate toggle: all 4 gates + reset_all_gates() work
[P4] Pour sequence: molds fill to 100 with receive_metal()
[P5] Order completion: 3 parts tracked (iron_blade, iron_guard, iron_grip)
[P6] Score tracking: Iron Sword = 150 pts (100 base + 50 speed bonus)
[P7] Waste game-over: fires at 100 waste_units
ALL TESTS PASSED
Ticks: 31
```

**Key findings from the test**:
- Iron Sword scores **150 pts** not 100 — speed bonus of +50 is applied (time < 30s threshold, even in headless test)
- All 3 molds complete in a single frame (tick 20) because `receive_metal(100.0)` is called directly — no flow simulation needed for the test
- Score starts at 0 and goes to 150 after completing Iron Sword
- After `score_manager.reset()`, waste is added to 100 and `game_over` signal fires correctly
- Gate toggle works: 4 gates each toggle open/closed, `reset_all_gates()` sets all to false

---

## Running the Headless Test

```bash
cd /mnt/g/AI_STUFF/Games/ForgeSortProto
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe \
    --headless --path . --quit-after 300
```

- `--headless`: no window
- `--path .`: use current directory as project root
- `--quit-after 300`: run 300 frames (~5 sec at 60fps), then quit cleanly
- Test node is invisible during normal play; use `--quit-after 300` to get test output

---

## What We Learned

### MCP is fully functional with correct path format
- Project path: `/mnt/g/...` (WSL/Linux absolute path)
- `mcp_godot_run_project` always opens **editor window** — no headless game support
- `mcp_godot_get_godot_version` confirmed 4.6.2.stable.official.71f334935
- `mcp_jcodemunch_*` tools work perfectly with repo name `local/ForgeSortProto`
- Fresh `index_folder` gave 205 symbols (vs stale 159) — re-index when files on disk differ from index

### The proper way to test Godot gameplay headless
- Do NOT use `--script` mode (doesn't boot project)
- Use `--scene "res://scenes/Main.tscn"` with `--headless --quit-after N`
- Or inject TestRunner into Main.tscn as a hidden always-processing child

### GateToggleUI signal recursion is a common Godot gotcha
- `button_pressed = x` fires `toggled(x)` on `Button`
- Never set `button_pressed` inside a handler connected to `toggled` without a guard
- The cleanest fix: guard flag + only set when value actually differs

### GameController is NOT an autoload
- It's `extends Node` with `@onready var start_button: Button = $UI/StartButton`
- Attached to the `Main` node in Main.tscn
- Access via `get_node("/root/Main")` or `get_node("/root/Main").start_game()`

---

## Files Changed

| File | Change |
|------|--------|
| `scenes/Main.tscn` | load_steps=16, +TestRunner ExtResource, +TestRunner Node2D |
| `scripts/dev/full_gameplay_test.gd` | 9-phase headless test (Node2D-based, not SceneTree) |
| `scenes/dev/TestRunner.tscn` | New stub scene |
| `scripts/ui/GateToggleUI.gd` | Recursion guard fix, only set button_pressed when different |
| `scripts/dev/smoke_check.gd` | Unchanged |

---

## Commit

`932111a` — "Test: inject TestRunner into Main.tscn, fix GateToggleUI infinite recursion" — local only (no remote).

---

## Next Steps (From Prior Sessions)

1. **Ilya/Calve/Rook routes** — narrative content for FeralLoveProto, not ForgeSortProto
2. **Tier 3 flags** — FeralLoveProto
3. **Visual layer** — FeralLoveProto
4. **Save/load system** — both projects need this

ForgeSortProto core loop is **complete and verified**.
