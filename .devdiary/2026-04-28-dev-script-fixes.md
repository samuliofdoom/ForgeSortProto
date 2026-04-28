# ForgeSortProto Dev Diary

## Session: 2026-04-28 — Dev Script Parse Fixes

---

## Goal

Fix parse errors in `dev/` scripts causing "Failed to load script" errors when running the game headless.

---

## What We Did

### 1. Found Three Parse Errors in dev/ Scripts

Ran `--check-only` on all `dev/*.gd` files and found:

- `dev/ProblemReader.gd:24` — missing closing `"` on `print("=== DONE ===")`
- `dev/semantic_check.gd:34` — same missing closing `"` issue
- `dev/semantic_check.gd:30` — `GDScriptParser.new()` — this class does not exist in Godot 4.x

The first two were trivial missing-quote bugs. The third (`GDScriptParser`) was a Godot 3.x API that no longer exists in 4.x.

### 2. Fixed All Three Errors

**ProblemReader.gd:24**:
```gdscript
# Before
print("=== DONE ===)
# After
print("=== DONE ===")
```

**semantic_check.gd:34**:
```gdscript
# Before
print("=== DONE ===)
# After
print("=== DONE ===")
```

**semantic_check.gd:30** — removed invalid `GDScriptParser.new()` line:
```gdscript
# Before
var parser = GDScriptParser.new()
print("CHECKED: " + path)
# After
print("CHECKED: " + path)
```

### 3. Verified All Scripts Now Work

Ran each dev script headless:
```
dev/semantic_check.gd  → PASS (17 scripts checked, exit 0)
dev/test_scene_load.gd → PASS (Main.tscn instantiates, exit 0)
dev/problems_fetch.gd  → PASS (all scripts load OK, exit 0)
```

### 4. Verified Main Game Is Clean

```bash
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 300
# Exit: 0 — clean, no errors, no warnings
```

All 8 validate.sh checks pass.

### 5. Fixed 3 GDScript Warnings Found Via Debug Mode

When running Godot in debug mode (`-d`), it surfaces warnings that `--headless` suppresses:
- `Gate.gd:29` — param `gate_id` shadowed the `@export var gate_id` class member
- `GateToggleUI.gd` — `signal gate_toggled(gate_id: String)` declared but never emitted
- `MetalSelector.gd` — `signal metal_selected(metal_id: String)` declared but never emitted

Fixed all three. After fixes, running with `-d` produces zero warnings.

---

## Files Changed

| File | Change |
|------|--------|
| `dev/ProblemReader.gd` | Line 24: added missing `"` closing quote |
| `dev/semantic_check.gd` | Line 34: added missing `"` closing quote; Line 30: removed `GDScriptParser.new()` (Godot 4.x incompatible) |
| `scripts/game/Gate.gd` | Line 29: renamed param `gate_id` → `p_gate_id` to avoid shadowing `@export var gate_id` |
| `scripts/ui/GateToggleUI.gd` | Removed unused `signal gate_toggled` |
| `scripts/ui/MetalSelector.gd` | Removed unused `signal metal_selected` |

---

## Running Headless

```bash
cd /mnt/g/AI_STUFF/Games/ForgeSortProto
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 300
```

Dev scripts can be tested individually:
```bash
./GodotEngine/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script dev/semantic_check.gd --quit-after 30
```

---

## Next Session

Run `./validate.sh` first. If all pass, game is clean.

---

## Session: 2026-04-28 (Evening) — RID Leak Fixes in Test Scripts

### What We Did

Thorough MCP testing revealed two test scripts leaking renderer resources (RIDs) on quit:

**`dev/test_scene_load.gd`** and **`scripts/dev/verify_game_loads.gd`** both instantiated `Main.tscn` via `preload().instantiate()` or `load().instantiate()` but called `quit()` without cleaning up the scene tree first. This leaked:
- RID allocations for physics bodies, areas, shapes
- Canvas and CanvasItem RIDs
- TextServer resources
- ObjectDB instances

**Fix**: Call `inst.queue_free()` before `quit()` in both scripts.

Also confirmed `dev/ProblemReader.gd` is `@tool extends EditorPlugin` — it can ONLY run inside the Godot editor. Running it headless always produces "Class 'EditorPlugin' can only be instantiated by editor". This is expected behavior, not an error.

### MCP Testing Findings

Working MCP tools for ForgeSortProto:
- `get_godot_version` ✓
- `get_project_info` ✓
- `list_projects` ✓

Non-functional (method not found on this MCP server):
- `list_prompts`
- `list_resources`

MCP polling (`run_project` → `get_debug_output`) does NOT work — Godot process dies between tool calls. Documented in AGENTS.md.

### Files Changed

| File | Change |
|------|--------|
| `dev/test_scene_load.gd` | Added `inst.queue_free()` before `quit()` |
| `scripts/dev/verify_game_loads.gd` | Added cleanup block before `quit()` |
| `handoff.md` | Updated with MCP status, RID leak note, debug mode info |

### Final State (Evening)

- `validate.sh`: 8/8 pass
- `smoke_check.gd`: 23/23 scripts pass
- `dev/test_scene_load.gd`: EXIT 0, no RID leaks
- `scripts/dev/verify_game_loads.gd`: EXIT 0, no RID leaks
- Game (no --script): clean EXIT 0
- Debug mode: zero warnings, zero errors

---

## Session: 2026-04-28 (Late Night) — part_requests Chain-Access Bug + validate.sh Check 9

### What We Did

**Bug found via jcodemunch audit**: `Mold.gd:151` had:
```gdscript
required_metal = new_order.part_requests[part_type].required_metal
```
`part_requests` is `{"blade": "iron", "guard": "iron", "grip": "iron"}` — a Dictionary mapping `part_type -> metal_string`. So `part_requests[part_type]` returns a `String` like `"iron"`, NOT an object. Calling `.required_metal` on a String is a runtime crash that only fires when an order starts.

**Fix**: Remove `.required_metal`:
```gdscript
required_metal = new_order.part_requests[part_type]
```

### Systemic Gap Found

`smoke_check.gd` only `load()`s data definitions (`OrderDefinition`, `MoldDefinition`, `MetalDefinition`) — never `.new()`s them. So constructor call-site mismatches (wrong arg count) and missing property accesses surface only at runtime.

### New Safeguard: Check 9

Created `scripts/dev/detect_constructor_mismatches.py` — a static Python checker that:
1. Finds all `.new()` call sites in `scripts/`
2. Resolves the class name to its source file
3. Extracts the `._init()` parameter count and required (no-default) count
4. Compares call-site arg count vs signature

Added as **Check 9** in `validate.sh`.

### Jcodemunch Index

Re-indexed with `mcp_jcodemunch_index_folder(incremental=false)`:
- Repo: `local/ForgeSortProto-0f1b469d` — 39 files, 250 symbols
- **gdscript extractor is missing** — use `search_text` + `read_file` for GDScript reads

### Patterns That Cause Bugs (Safeguards)

1. **Missing Resource properties**: `smoke_check.gd` only `load()`s data defs, doesn't `.new()` — property gaps only caught at runtime. Safeguard: always cross-check accessed properties against the class definition.
2. **Chain property access on primitives**: `dict[key].property` where `dict[key]` returns a String/int/Color — compiles fine, crashes at runtime. No static check catches this. Safeguard: headless gameplay test (`--quit-after 300`).
3. **Unused params**: `detect_unused_params.py` (Check 8).
4. **Constructor arity mismatches**: `detect_constructor_mismatches.py` (Check 9).

### Files Changed

| File | Change |
|------|--------|
| `scripts/game/Mold.gd` | Line 151: removed erroneous `.required_metal` |
| `scripts/dev/detect_constructor_mismatches.py` | NEW: static constructor arity checker |
| `validate.sh` | Added Check 9: constructor call-site validation |
| `handoff.md` | Updated with new patterns, check_9, jcodemunch status |

### Final State (Late Night)

- `validate.sh`: **9/9 pass** (was 8, added Check 9)
- `smoke_check.gd`: 23/23 scripts pass
- Game (headless): clean EXIT 0
- Debug mode: zero warnings, zero errors
- Constructor mismatch check: PASS
- No remote (local-only repo)

---

## Next Session

Run `./validate.sh` first. If all 9 pass, game is clean.
