# ForgeSortProto - Session Handoff

## Issue Tracker
Beads (`bd`) is the issue tracker. Run `bd ready` to see current issues.

**Active Issue:** `ForgeSortProto-eo0` — "Fix parse errors in Godot project"
- Status: open, claimed to "samuli"
- Run `bd update ForgeSortProto-eo0 --claim` to reclaim

---

## Godot MCP Fix

### Problem
godot-mcp couldn't find Godot because:
1. It looks for `/usr/bin/godot` on Linux
2. Actual Godot is at `G:\GodotEngine\Godot_v4.6.2-stable_win64.exe`
3. Path is on Windows, not Linux

### Solution Applied
Updated `/home/samuli/.config/opencode/opencode.json`:

```json
"godot": {
  "type": "local",
  "command": ["godot-mcp"],
  "enabled": true,
  "environment": {
    "GODOT_PATH": "G:\\GodotEngine\\Godot_v4.6.2-stable_win64.exe",
    "GODOT_PROJECT_PATH": "/mnt/g/AI_STUFF/Games/ForgeSortProto",
    "strictPathValidation": false
  }
}
```

### Activation
**MCP requires OpenCode restart to pick up config changes.**
Close this session, start a new session, then MCP tools will work.

---

## Project State

### Validation
`./validate.sh` passes - no script reference errors, load_steps correct.

### Parse Errors
Unknown - couldn't confirm if errors still exist. Godot MCP was broken.
After MCP works, run `godot_run_project` then `godot_get_debug_output` to see actual errors.

### Key Files
| File | Purpose |
|------|---------|
| `scenes/Main.tscn` | Main scene, load_steps=15 |
| `scripts/game/GameController.gd` | Start flow, order reset |
| `scripts/game/MetalFlow.gd` | Pour routing by X position |
| `scripts/game/FlowController.gd` | Gate routing logic |
| `scripts/game/Mold.gd` | Fill/contamination (tap to clear) |
| `scripts/game/Gate.gd` | Toggle gates (input_pickable=true) |
| `scripts/game/Intake.gd` | Area2D metal receiver |

### Architecture
```
PourZone → MetalSource → MetalFlow → FlowController → Mold → OrderManager
```

### Orders
| # | Name | Parts | Value |
|---|------|-------|-------|
| 1 | Iron Sword | iron_blade/guard/grip | 100 |
| 2 | Steel Sword | steel_blade, iron guard/grip | 160 |
| 3 | Noble Sword | steel_blade, gold_guard, iron_grip | 250 |

---

## Perms Issue
`.beads` has permissions 0777 (Windows mount). `chmod 700` won't work on this filesystem. Beads still works despite warning.

---

## Next Steps
1. **Start new OpenCode session** (MCP config won't update in current session)
2. **Run `godot_run_project`** to start Godot with the project
3. **Run `godot_get_debug_output`** to see any parse errors
4. **Fix errors** reported by Godot
5. **Test game loop** in Godot editor
6. **Close issue** with `bd close ForgeSortProto-eo0` when done

---

## Godot Path (for reference)
```
G:\GodotEngine\Godot_v4.6.2-stable_win64.exe
```