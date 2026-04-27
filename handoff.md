# ForgeSortProto - Session Handoff

## Issue Tracker
Beads (`bd`) is the issue tracker. Run `bd ready` to see current issues.
**Status**: All issues closed.

---

## Project State
ForgeSortProto is a Godot 4.6.2 forge-sorting game. Validation passes, project loads headless cleanly.

### Git
- Local commit: `954d2d6` "Fix Godot project parse errors"
- `.gitignore` updated to exclude `node_modules/` and `package-lock.json`
- No remote configured — `git push` will fail until remote is added

### Files (committed to git)
- `scenes/Main.tscn` — Main scene, load_steps=15, parses correctly
- `scripts/data/` — GameData.gd, MetalDefinition.gd, MoldDefinition.gd, OrderDefinition.gd
- `scripts/game/` — GameController, MetalFlow, FlowController, Mold, Gate, Intake, PourZone, OrderManager, ScoreManager, PartPopEffect
- `scripts/ui/` — MetalSelector, OrderPanel, ScoreDisplay, WasteMeter, ResultPanel, GateToggleUI, PartPopLabel

### Autoloads (in project.godot)
```
GameData, ScoreManager, MetalSource, OrderManager, FlowController, MetalFlow
```

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

## Validation
```bash
./validate.sh  # PASSES
timeout 8 godot --headless --path "G:/AI_STUFF/Games/ForgeSortProto" --quit-after 5  # No parse errors
```

---

## Common Gotchas
- Gate uses `_input(event)` not `Area2D` for click detection
- `Mold.clear_mold()` only on contaminated state
- `ScoreManager.add_waste()` vs `add_contamination()`
- `input_pickable = true` required on Gate StaticBody2D
- `load_steps=N` must equal ext_resources + sub_resources
- `@onready var x = $Y` — Y must exist in scene
- Signal `.connect(_on_foo)` → `func _on_foo()` must be in SAME file

---

## Godot MCP / OpenCode Issue ⚠️

### Problem
OpenCode MCP refuses to load the godot entry from config. Error:
```
ERROR service=mcp key=godot Ignoring MCP config entry without type
```
The godot config is valid JSON with `type: "local"`, but opencode silently drops it during config resolution.

### Config (in `/home/samuli/.config/opencode/opencode.json`)
```json
"godot": {
  "type": "local",
  "command": [
    "node",
    "/mnt/g/AI_STUFF/Games/ForgeSortProto/node_modules/@coding-solo/godot-mcp/build/index.js"
  ],
  "enabled": true,
  "environment": {
    "GODOT_PATH": "/mnt/g/GodotEngine/Godot_v4.6.2-stable_win64.exe",
    "GODOT_PROJECT_PATH": "/mnt/g/AI_STUFF/Games/ForgeSortProto",
    "strictPathValidation": false
  }
}
```

### Manual Test (works)
```bash
GODOT_PATH="/mnt/g/GodotEngine/Godot_v4.6.2-stable_win64.exe" \
node /mnt/g/AI_STUFF/Games/ForgeSortProto/node_modules/@coding-solo/godot-mcp/build/index.js
# Outputs tools list correctly
```

### Status
- MCP issue is an opencode config resolution problem, NOT a project code problem
- Project code is fine — validated and loads cleanly
- All other MCP servers (jcodemunch, jdocmunch, sentry, context7) load fine
- This remains unresolved as of handoff

---

## Next Steps
1. **Push to remote** — add `git remote add origin <url>` when network available
2. **Debug Godot MCP** — opencode config resolution issue (separate from project)
3. **Manual game test** — run in Godot editor to verify runtime behavior
4. **Feature work** — no open issues, check `bd ready` for new work
