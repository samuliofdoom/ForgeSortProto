# ForgeSortProto — Agent Handoff

**Last updated**: 2026-04-27
**Branch**: master (local only — no remote)
**Commit**: `932111a` — "Test: inject TestRunner into Main.tscn, fix GateToggleUI infinite recursion"

---

## Project Status: CORE LOOP COMPLETE ✓

All major features implemented and verified via 9-phase headless test.

| Feature | Status |
|---------|--------|
| Pour zone with visual feedback | ✓ |
| Metal source (iron/steel/gold) | ✓ |
| Gate routing (4 gates) | ✓ |
| Mold fill/complete/contamination | ✓ |
| Order system (3 orders) | ✓ |
| Score tracking + speed bonus | ✓ |
| Waste meter + game over | ✓ |
| P2: metal speed/spread differentiation | ✓ |
| P3: waste meter hard fail | ✓ |
| Headless gameplay test | ✓ |

---

## Godot MCP Usage

**Project path format**: `/mnt/g/...` (WSL/Linux absolute path)

| Tool | Purpose |
|------|---------|
| `mcp_godot_get_godot_version` | Verify engine running |
| `mcp_godot_get_project_info` | Get project metadata |
| `mcp_godot_get_scene_tree` | Get full scene hierarchy |
| `mcp_godot_call_node_method` | Call methods on scene nodes |
| `mcp_godot_run_project` | **Opens editor window** (not headless) |

**Note**: `mcp_godot_run_project` always opens the Godot editor, never runs headless. For headless testing, use the console exe directly (see below).

---

## Running the Game

### Normal play
```bash
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe --path .
# or open scenes/Main.tscn in Godot editor
```

### Headless gameplay test (9 phases)
```bash
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe \
    --headless --path . --quit-after 300
```
Test node is invisible (`visible=false`), normal play unaffected.

### Smoke check (parse errors only)
```bash
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe \
    --headless --path . --script scripts/dev/smoke_check.gd --quit-after 10
```

---

## Key Node Paths

| Node | Path |
|------|------|
| Main | `/root/Main` |
| GameController | `/root/Main` (script on Main node) |
| MoldArea | `/root/Main/MoldArea` |
| BladeMold | `/root/Main/MoldArea/BladeMold` |
| GuardMold | `/root/Main/MoldArea/GuardMold` |
| GripMold | `/root/Main/MoldArea/GripMold` |
| StartButton | `/root/Main/UI/StartButton` |
| MetalSource | `/root/MetalSource` (autoload) |
| FlowController | `/root/FlowController` (autoload) |
| ScoreManager | `/root/ScoreManager` (autoload) |
| OrderManager | `/root/OrderManager` (autoload) |

---

## Autoloads (in project.godot)

```
OrderManager, MetalFlow, ScoreManager, GameData, FlowController, MetalSource, GameController
```

**Important**: GameController is NOT an autoload. It is a script attached to the Main node. Access via `get_node("/root/Main")`.

---

## Orders

| # | Name | Parts | Value |
|---|------|-------|-------|
| 1 | Iron Sword | iron_blade, iron_guard, iron_grip | 100 |
| 2 | Steel Sword | steel_blade, iron_guard, iron_grip | 160 |
| 3 | Noble Sword | steel_blade, gold_guard, iron_grip | 250 |

Speed bonus: +50 pts if completed under 30 seconds.

---

## Bug Fixes Applied

### GateToggleUI infinite recursion (fixed in `932111a`)
`_update_button_states()` set `button_pressed = is_open` which fires `toggled` signal → `toggle_gate()` → `gate_toggled.emit()` → `_update_button_states()` → infinite loop.

**Fix**: `_guard_recursion` bool flag + only set `button_pressed` when value differs.

### PourZone parse error (fixed in `6296404`)
`stream_width` variable was declared as `_current_stream_width`. Fixed all references.

### FlowController gate routing (fixed in `0a1b291`)
Gate routing now uses `get_mold_for_pour_position()` which respects gate open/closed state.

---

## Dev Tools

| Tool | Location | Purpose |
|------|----------|---------|
| `validate.sh` | root | 5-check validation (bash + smoke + Godot version + parse + git) |
| `smoke_check.gd` | `scripts/dev/` | Parse error checker (SceneTree-based, headless) |
| `full_gameplay_test.gd` | `scripts/dev/` | 9-phase gameplay test (Node2D, injected into Main.tscn) |
| TestRunner.tscn | `scenes/dev/` | Test scene stub |

---

## Known Gotchas

- **GameController is NOT an autoload** — it's on the Main node. Do not use `get_node("/root/GameController")`.
- **`--script` mode does NOT boot the project** — no autoloads, no SceneTree. Use `--scene` or inject into Main.tscn.
- **GateToggleUI recursion** — `button_pressed = x` fires `toggled(x)`. Never set it inside a `toggled` handler without a guard.
- **`--quit-after N`** — only works with the console exe, not the GUI exe.
- **jcodemunch index goes stale** — re-index with `index_folder(force=true)` when disk files differ from index.

---

## Remaining Work

No remaining bugs. Core game loop is complete and verified.

Future enhancements (not in current scope):
- Save/load system
- Sound effects and music
- Additional orders or game modes
- Touch/mobile input support

---

## Recent Commits

| Commit | Description |
|--------|-------------|
| `932111a` | Test: inject TestRunner into Main.tscn, fix GateToggleUI infinite recursion |
| `6296404` | Fix PourZone parse error + gameplay test script |
| `5e38b7f` | P2: metal differentiation + P3: waste meter game over |
| `0a1b291` | Fix gate routing and add visual feedback layer |
