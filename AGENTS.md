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
- `FlowController.get_mold_for_pour_position()` — runtime routing (NOTE: NOT `get_mold_for_intake()` which is older/deprecated API)
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
| `scenes/Main.tscn` | load_steps=19 (17 ext + 2 sub) |
| `scripts/game/GameController.gd` | Start flow, order reset |
| `scripts/game/MetalFlow.gd` | Pour routing (uses `get_mold_for_pour_position`) |
| `scripts/game/FlowController.gd` | Gate routing (has BOTH `get_mold_for_intake` AND `get_mold_for_pour_position`) |
| `scripts/game/Mold.gd` | Fill/contamination (tap to clear) |
| `scripts/game/Gate.gd` | Toggle (input_pickable=true) |
| `scripts/game/PourZone.gd` | Hold/sweep input |
| `scripts/ui/GateToggleUI.gd` | G1-G4 buttons |
| `scripts/dev/smoke_check.gd` | Full compilation check (`.new()` all game/UI scripts) |

---

## Orders
| # | Name | Parts | Value |
|---|------|-------|-------|
| 1 | Iron Sword | iron blade/guard/grip | 100 |
| 2 | Steel Sword | steel blade, iron guard/grip | 160 |
| 3 | Noble Sword | steel blade, gold guard, iron grip | 250 |

---

## Common Errors (CHECK FIRST)
1. `input_pickable = true` required on Gate StaticBody2D
2. `load_steps=N` must equal ext_resources + sub_resources
3. `@onready var x = $Y` — Y must exist in scene
4. Signal `.connect(_on_foo)` → `func _on_foo()` must be in SAME file
5. When prefixing a signal callback param with `_`, update the body too (e.g. `_score` not just `score` in signature — body must also use `_score`)
6. `smoke_check.gd` skips data definitions (OrderDefinition, MoldDefinition, MetalDefinition, GameData) — they have required `_init()` args and can only be `load()`ed, not `.new()`ed
7. **Routing API mismatch**: `test_flow_controller_routing.gd` uses `get_mold_for_intake()` but the actual runtime uses `get_mold_for_pour_position()` — do NOT trust test_flow_controller_routing.gd for routing correctness, it tests the wrong API

## Known Gotchas
- Gate uses `_input(event)` not `Area2D` for click detection
- `Mold.clear_mold()` only on contaminated state
- `ScoreManager.add_waste()` vs `add_contamination()`
- MCP headless polling (`mcp_godot_run_project` + `get_debug_output`) does NOT work — Godot process dies between tool calls; use `smoke_check.gd` + `validate.sh` instead

---

## validate.sh — 9 Checks

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
| 9 | Constructor mismatches | `detect_constructor_mismatches.py` exits non-zero |

---

## Critical Bugs (as of 2026-04-29)

### BUG-001: Speed bonus non-functional for Orders 2+3
- `ScoreManager.gd:54` uses `start_time` (set once at game start) instead of per-order time
- SPEED_THRESHOLD_SECONDS=30, elapsed for Order 3 = all time spent on Orders 1+2+3
- Fix: add `order_start_time` to OrderManager, set in `start_next_order()`

### BUG-002: flush_accumulator double-penalizes
- `MetalFlow.gd:50-54` calls `_route_fallback()` which delivers metal AND charges waste
- Fix: route via `get_mold_for_pour_position()` without the waste charge

### BUG-003: Mold contamination leaks across orders
- `Mold.gd:150-158` only clears if `part_requests.has(part_type)` for the new order
- Fix: always call `clear_mold()` at order start

### BUG-004: game_over signal has no UI handler
- `ScoreManager.gd:46` emits `game_over` but `ResultPanel.gd` only handles `game_completed`
- Fix: connect `game_over` in ResultPanel with "GAME OVER" overlay + screen shake

---

## Dev Diary

Full analysis, bug register, production phases, and open questions in `Docs/dev_diary.md`.
