# Handoff — Session Complete

All tasks finished. No pending work.

## Current State
- Commit: `b5f2d881` (local only, no remote)
- Branch: `master`
- All 9 `validate.sh` checks pass
- All GDScript warnings resolved — zero Problems panel warnings
- Game exits cleanly: headless (`--quit-after 300`) EXIT 0 with zero errors
- Debug mode (`-d`): zero warnings, zero errors
- RID leak fixes applied to test infrastructure (`test_scene_load.gd`, `verify_game_loads.gd`)

## Today's Fixes (2026-04-28)
### Morning session (committed earlier as fc9d977)
- `OrderDefinition.gd` — added `part_requests: Dictionary` property (was missing entirely)
- `GameData.gd` — updated all 3 order constructors to build and pass `part_requests` dict
- `Mold.gd` — `receive_metal()` now uses `new_order.part_requests` to validate metal type

### This session
- `scripts/game/Mold.gd:151` — **BUG FIX**: `new_order.part_requests[part_type].required_metal` was erroneous.
  - `part_requests` is `Dictionary` mapping `part_type -> metal_string` (e.g. `{"blade": "iron", ...}`)
  - `part_requests[part_type]` returns a `String` like `"iron"`, NOT an object with a `.required_metal` property
  - Calling `.required_metal` on a String is a runtime crash. Fixed: removed `.required_metal`
- `scripts/dev/detect_constructor_mismatches.py` — **NEW**: static checker for `.new()` call-site args vs `._init()` signature mismatches
- `validate.sh` — added **Check 9**: constructor call-site validation (calls the new script above)

## Known Limitations
- `dev/ProblemReader.gd` is `@tool extends EditorPlugin` — can ONLY run inside Godot editor, not headless.
  Running it headless produces "Class 'EditorPlugin' can only be instantiated by editor". This is expected.
  It must be run from within the editor (Scene > Run Script or via EditorPlugin mechanism).

## Dev Scripts Status
All `dev/` and `scripts/dev/` scripts now parse and run cleanly:
- `dev/ProblemReader.gd` — EditorPlugin, editor-only (lists script editor children)
- `dev/semantic_check.gd` — loads all game scripts, verifies they load without error
- `dev/problems_fetch.gd` — loads all game scripts, reports load errors
- `dev/test_scene_load.gd` — instantiates Main.tscn, verifies it builds cleanly (RID-clean)
- `dev/test_order_start.gd` — SceneTree-based order start test (uses await, not yield)
- `scripts/dev/smoke_check.gd` — 23/23 game/UI scripts compile via `.new()`
- `scripts/dev/verify_game_loads.gd` — scene load verification + 3s alive test (RID-clean)
- `scripts/dev/detect_constructor_mismatches.py` — static call-site vs _init arity checker

## Godot — Native Linux Install
- Installed to: `~/.local/bin/godot` (Linux x86_64 native build 4.6.2.stable)
- Reason: WSL2 9pdrvfs mounts can't execute Windows PE binaries
- validate.sh now uses `${HOME}/.local/bin/godot` by default
- Windows binary still at `G:\GodotEngine\Godot_v4.6.2-stable_win64_console.exe` (editor use)

## MCP Server Status
- Server: `godot-mcp-codex` (wrapper script at `/home/samuli/.local/bin/godot-mcp-codex`)
- Binary: `G:/AI_STUFF/FeralLoveProto/GodotEngine/Godot_v4.6.2-stable_win64_console.exe` (shared between projects)
- `projectPath` for ForgeSortProto: `/mnt/g/AI_STUFF/Games/ForgeSortProto`
- MCP polling DOES NOT work for gameplay testing — Godot process dies between tool calls (documented in AGENTS.md)
- Working MCP tools: `get_godot_version`, `get_project_info`, `list_projects`
- Non-functional: `list_prompts`, `list_resources` (method not found)

## What's Built
- `scripts/dev/detect_unused_params.py` — static Python checker for unused function parameters
- `scripts/dev/detect_constructor_mismatches.py` — static Python checker for `.new()` call-site vs `._init()` signature mismatches (NEW this session)
- `scripts/dev/smoke_check.gd` — full compilation check via `.new()` on all game/UI scripts (23/23 pass)
- `scripts/dev/verify_game_loads.gd` — scene load verification
- `validate.sh` — **9-check pipeline** (Check 9 = constructor mismatch detection is new this session)

## Jcodemunch Index
- Repo: `local/ForgeSortProto-0f1b469d`
- 39 files indexed, 250 symbols
- **gdscript extractor flagged as missing** — `get_symbol_source`, `get_file_outline`, `search_symbols` all fail for GDScript files
- **Use `search_text` + `read_file`** for all GDScript reads
- Index command: `mcp_jcodemunch_index_folder` with `incremental=false` (full reindex)

## Patterns That Cause Bugs (Safeguards)
1. **Missing Resource properties**: `OrderDefinition`, `MoldDefinition`, `MetalDefinition` are `Resource` classes. If a caller accesses a property that doesn't exist on the Resource, runtime crash. `smoke_check.gd` does NOT catch this (only `load()`s them, doesn't `.new()`). `detect_constructor_mismatches.py` catches arity mismatches but not missing properties. **Safeguard**: always cross-check accessed properties against the class definition.
2. **Chain property access on primitives**: `dict[key].property` where `dict[key]` returns a String/int/Color — compiles fine, crashes at runtime. No static check catches this yet. **Safeguard**: headless gameplay test.
3. **Unused params**: `detect_unused_params.py` catches these (Check 8). Prefix intentionally unused params with `_`.
4. **Constructor arity mismatches**: `detect_constructor_mismatches.py` catches these (Check 9).

## Running the Game
```bash
# Headless test (clean exit expected)
cd /mnt/g/AI_STUFF/Games/ForgeSortProto
godot --headless --path . --quit-after 300

# Debug mode (watch for warnings in output)
godot -d --path .

# Validate all checks
./validate.sh
```

## Next Session
Run `./validate.sh` first. If all 9 pass, game is clean.
