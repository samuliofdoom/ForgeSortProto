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
# Try to get semantic warnings
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

### Final State

- `validate.sh`: 8/8 pass
- `smoke_check.gd`: 23/23 scripts pass
- `dev/test_scene_load.gd`: EXIT 0, no RID leaks
- `scripts/dev/verify_game_loads.gd`: EXIT 0, no RID leaks
- Game (no --script): clean EXIT 0
- Debug mode: zero warnings, zero errors
