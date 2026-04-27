# Forge Sort Proto — Agent Context

**Godot**: `G:\GodotEngine\Godot_v4.6.2-stable_win64.exe`

---

## MUST RUN BEFORE TESTING
```bash
./validate.sh
```

---

## Indexes (USE THESE FIRST)
| Tool | Repo | Use |
|------|------|-----|
| `jcodemunch_search_symbols` | `local/ForgeSortProto` | Find functions/classes |
| `jcodemunch_search_text` | `local/ForgeSortProto` | Full-text search |
| `jdocmunch_search_sections` | `local/Docs` | Spec/search |

---

## Architecture

```
PourZone → MetalSource → MetalFlow → FlowController → Mold → OrderManager
```

**Key methods**:
- `MetalFlow._process()` — routes to intake by X position
- `FlowController.get_mold_for_intake()` — respects gate states
- `Mold.receive_metal()` — fill/contamination/completion

**Gate routing** (`FlowController.gd`):
```gdscript
INTAKE_TO_MOLD = {"intake_a":"blade", "intake_b":"guard", "intake_c":"grip"}
GATE_ROUTING = {
  "gate_01":["intake_a","intake_b"], "gate_02":["intake_b","intake_c"],
  "gate_03":["intake_a","intake_b","intake_c"], "gate_04":["intake_c"]
}
```

---

## Autoloads
```
GameData, ScoreManager, MetalSource, OrderManager, FlowController, MetalFlow
```

---

## Files

| File | Purpose |
|------|---------|
| `scenes/Main.tscn` | load_steps=15 (13 ext + 2 sub) |
| `scripts/game/GameController.gd` | Start flow, order reset |
| `scripts/game/MetalFlow.gd` | Pour routing |
| `scripts/game/FlowController.gd` | Gate routing |
| `scripts/game/Mold.gd` | Fill/contamination (tap to clear) |
| `scripts/game/Gate.gd` | Toggle (input_pickable=true) |
| `scripts/game/PourZone.gd` | Hold/sweep input |
| `scripts/ui/GateToggleUI.gd` | G1-G4 buttons |

---

## Orders
| # | Name | Parts | Value |
|---|------|-------|-------|
| 1 | Iron Sword | iron_blade/guard/grip | 100 |
| 2 | Steel Sword | steel_blade, iron guard/grip | 160 |
| 3 | Noble Sword | steel_blade, gold_guard, iron_grip | 250 |

---

## Common Errors (CHECK FIRST)
1. `input_pickable = true` required on Gate StaticBody2D
2. `load_steps=N` must equal ext_resources + sub_resources
3. `@onready var x = $Y` — Y must exist in scene
4. Signal `.connect(_on_foo)` → `func _on_foo()` must be in SAME file

---

## Quality Gates (MUST PASS BEFORE COMMIT)

**Before marking any ticket done**, verify ALL of the following:

1. **Run `./validate.sh`** — must pass all 6 checks
2. **Open changed scripts in Godot editor** — Problems panel must show zero warnings or errors
3. **Run headless gameplay test** — `GodotEngine/Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 300` must exit 0
4. **Run smoke check** — `GodotEngine/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script scripts/dev/smoke_check.gd --quit-after 10` must exit 0

**Common GDScript warnings to watch for:**
- `unused_parameter` — prefix unused signal callback params with `_`
- `standalone_ternary` — ternary result must be assigned: `x = a if cond else b`
- `unused_signal` — signals with no `connect()` call are intentional (e.g. `part_produced` in Mold.gd), but verify before ignoring
- `invalid_constant` — Godot 4.6.2 Line2D uses `LINE_CAP_MODE_SQUARE` not `ROUND`, `LINE_JOINT_MODE_BEVEL` not `ROUND`
- `unused_variable` / `unused_local_variable` — remove or prefix with `_`

---

## Known Gotchas
- Gate uses `_input(event)` not `Area2D` for click detection
- `Mold.clear_mold()` only on contaminated state
- `ScoreManager.add_waste()` vs `add_contamination()`

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
