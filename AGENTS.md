# Forge Sort Proto — Agent Context

**Godot**: `~/.local/bin/godot` (Linux native build 4.6.2)
**Godot (editor)**: `G:\GodotEngine\Godot_v4.6.2-stable_win64.exe` (Windows)

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
| `scripts/dev/smoke_check.gd` | Full compilation check (`.new()` all game/UI scripts) |
| `scripts/dev/detect_unused_params.py` | Static checker for unused function parameters |

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
5. When prefixing a signal callback param with `_`, update the body too (e.g. `_score` not just `score` in signature — body must also use `_score`)
6. `smoke_check.gd` skips data definitions (OrderDefinition, MoldDefinition, MetalDefinition, GameData) — they have required `_init()` args and can only be `load()`ed, not `.new()`ed

---

## Quality Gates (MUST PASS BEFORE COMMIT)

**Before marking any ticket done**, verify ALL of the following:

1. **Run `./validate.sh`** — must pass all 9 checks
2. **Open changed scripts in Godot editor** — Problems panel must show zero warnings or errors
3. **Run headless gameplay test** — `godot --headless --path . --quit-after 300` must exit 0
4. **Run smoke check** — `godot --headless --path . --script scripts/dev/smoke_check.gd --quit-after 10` must exit 0

**Common GDScript warnings to watch for:**
- `unused_parameter` — prefix unused signal callback params with `_`, and update body references too
- `standalone_ternary` — ternary result must be assigned: `x = a if cond else b`
- `unused_signal` — signals with no `connect()` call are intentional (e.g. `part_produced` in Mold.gd), but verify before ignoring
- `invalid_constant` — Godot 4.6.2 Line2D uses `LINE_CAP_MODE_SQUARE` not `ROUND`, `LINE_JOINT_MODE_BEVEL` not `ROUND`
- `unused_variable` / `unused_local_variable` — remove or prefix with `_`

**The static unused-param checker (`scripts/dev/detect_unused_params.py`) catches these at validate.sh time — do NOT disable Check 8.**

---

## Known Gotchas
- Gate uses `_input(event)` not `Area2D` for click detection
- `Mold.clear_mold()` only on contaminated state
- `ScoreManager.add_waste()` vs `add_contamination()`
- MCP headless polling (`mcp_godot_run_project` + `get_debug_output`) does NOT work — Godot process dies between tool calls; use `smoke_check.gd` + `validate.sh` instead

---

## validate.sh — 8 Checks

| # | Check | Fail condition |
|---|-------|----------------|
| 1 | Signal handler coverage | `grep -c connect` mismatch vs registered handlers |
| 2 | Scene `load_steps` | ext + sub != load_steps |
| 3 | Script `class_name` references | referenced class missing from project |
| 4 | Autoload singletons | autoload .gd file missing |
| 5 | **Full compilation** | `smoke_check.gd` stderr contains "Warning" or "ERROR" |
| 6 | Parse errors | `--check-only` returns non-zero |
| 7 | gdlint | SKIPPED (pip blocked on this system) |
| 8 | **Static unused-param check** | `detect_unused_params.py` exits non-zero |

---

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
