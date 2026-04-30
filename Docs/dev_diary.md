# ForgeSortProto — Development Diary

## Session: 2026-04-30 (Evening)

**Status going in**: BUG-004 (game_over handler) already fixed in prior session. MetalBlob.gd introduced FREEZE_MODE_DISABLED (Godot 4.7+ API) causing parse error.

**Action**: Designer agent spun up via MCP → live game review → reported D-1 (timer `"0.0fs"` typo) and D-2 (game_over no handler). Orchestrator re-verified: D-2 was already fixed. Only D-1 was real.

**Fixes applied tonight**:
| Fix | File | Change |
|-----|------|--------|
| D-1: Timer `"0.0fs"` literal | `scripts/ui/OrderChecklistUI.gd:65` | `"%.1fs"` → `"%.1f s"` |
| MetalBlob parse error | `scripts/game/MetalBlob.gd:25,31` | Removed `FREEZE_MODE_DISABLED` (4.7+ only); `freeze_mode=disabled` is Godot 4.6.2 default |

**Validate**: 9/9 pass, 0 warnings. MetalBlob was never in smoke_check.

**BUG-004 status**: Already fixed in prior session — ResultPanel.gd:20 connects `game_over`, handler at lines 30-33 with shake overlay. Dev diary incorrectly listed it as open.

---

## Session: 2026-04-29 (Morning)

**Status going in**: 9/9 validate.sh pass. Headless exits clean. 23/23 game scripts compile. GateDebugHUD committed (`8648426`).

**Action**: Full game dev team analysis — all 5 roles (Producer, Designer, Coder, QA, Artist) spun up simultaneously in 2 batches (3 + 2). Reports synthesized by orchestrator.

---

## Team Analysis Summary

### What the Game IS
A one-screen mobile forge-action prototype. Hold+sweep to pour molten metal → route through 4 toggleable gates (G1→A/B, G2→B/C, G3→A/C, G4→C) → fill 3 molds (Blade/Guard/Grip) → complete 3 fixed orders (Iron Sword → Steel Sword → Noble Sword) → score. Core loop is complete and playable.

### What Works
- Hold/sweep pour with metal-specific stream width/speed
- Gate toggle routing to 3 intake zones
- Mold fill/contamination/overfill/completion state machine
- Tap-to-clear contaminated molds
- Waste meter + score tracking
- Part-pop effects and score display
- All signal wiring and autoload hierarchy
- 9/9 validate.sh pass, headless clean

### Bugs Found (P1 — Fix First)

**BUG-001: Speed bonus uses game clock, not per-order clock**
- `ScoreManager.gd:54` — `elapsed = (Time.get_ticks_msec() - start_time) / 1000.0` where `start_time` is set once at game start
- For Order 3, elapsed = all time spent on Orders 1+2+3
- SPEED_THRESHOLD_SECONDS = 30, so Orders 2 and 3 can NEVER qualify
- Fix: Add `order_start_time` to OrderManager, set it in `start_next_order()`, pass order elapsed to `calculate_order_score()`
- Reported by: Coder, QA (BUG-QA-001)

**BUG-002: flush_accumulator double-penalizes on gate toggle mid-pour**
- `MetalFlow.gd:50-54` calls `_route_fallback()` which both delivers metal to nearest mold AND calls `add_waste()`
- Player loses metal AND gets waste penalty for one mistake
- Fix: Route via `FlowController.get_mold_for_pour_position()` WITHOUT charging waste, since metal IS delivered
- Reported by: Coder (BUG-003), QA (BUG-QA-002), Designer (section 3.1)

**BUG-003: Mold contamination leaks across orders**
- `Mold.gd:150-158` `_on_order_started()` only calls `clear_mold()` when `is_complete or is_contaminated` AND `part_requests.has(part_type)`
- If mold was contaminated but new order doesn't need that mold, contamination persists
- Fix: Always call `clear_mold()` at order start, or add else branch
- Reported by: Coder (BUG-008), QA (BUG-QA-004)

**BUG-004: game_over signal has no UI handler**
- `ScoreManager.gd:46` emits `game_over(final_score, waste_percent)`
- `ResultPanel.gd` only listens to `game_completed`, not `game_over`
- Waste-based game end goes straight to result screen — no "GAME OVER" moment
- Fix: Connect `game_over` in ResultPanel, add screen shake + flash + overlay
- Reported by: Designer (Priority 2), QA (BUG-QA-003)
- **Status: FIXED** — ResultPanel.gd:20 connects `game_over`, `_on_game_over` at lines 30-33 with shake overlay

### Polish Gaps (P2 — Phase B/C)

| Issue | Reported By | Fix |
|-------|-------------|-----|
| Audio entirely absent | Designer, Artist | AudioStreamPlayer nodes in PourZone/Mold/Gate/WasteMeter |
| Mold cool/harden animation missing | Artist | Tween chain in Mold._trigger_complete() |
| Gate routing invisible | Designer, Artist | Labels on GateToggleUI, persistent indicators near MoldArea |
| Speed timer not displayed | Designer | Wire SpeedTimer.gd to UI |
| Fill bars jump (no tween) | Designer | Tween fill_bar.value in Mold._update_display() |
| Intake glow too fast (0.4s) | Artist | Extend to 0.8s + particle burst |
| Gate toggle no animation | Designer, Artist | Tween rotation with elastic ease |
| Locked mold unclear | Designer, Artist | Desaturated + padlock icon |
| Rejection flash at mold, not pour origin | Designer | Move visual feedback to failure point |
| Order transition no fanfare | Designer | Extend green flash + scale pulse |

### Technical Debt (Coder Report)

| ID | Issue | Severity | Fix |
|----|-------|----------|-----|
| TD-001 | FlowController.register_gate() is a no-op | Medium | Remove or implement properly |
| TD-002 | Inconsistent routing fallback (get_mold_for_intake vs get_mold_for_pour_position) | Medium | Standardize on one API |
| TD-003 | Hardcoded /root/Main/MoldArea paths in MetalFlow.gd + FlowController.gd | High | Get once in GameController, cache and pass |
| TD-004 | GateDebugHUD F1 conflicts with Godot editor | Low | Change to F2 or Ctrl+F1 |
| TD-005 | PartPopEffect node lookups ignore null silently | Low | Use fallback position visibly |

### Test Gaps (QA Report)

| Gap | Severity | Action |
|-----|----------|--------|
| `get_mold_for_pour_position` never called in any test | Critical | Add test_pour_position_routing.gd |
| flush_accumulator mid-pour untested | Critical | Add gate-toggle-during-pour test |
| game_over signal no UI handler | High | Connect handler + test |
| UI panels (MetalSelector, OrderPanel, etc.) zero headless coverage | Medium | Add test_ui_panels.gd |
| Mold lock state not verified in full order cycle | Medium | Add test_mold_lock_and_contamination.gd |

---

## Production Phases

### Phase A — Bug Fixes (1-2 days)
1. **A1**: Fix speed bonus per-order timing (BUG-001)
2. **A2**: Fix flush_accumulator double-penalty (BUG-002)
3. **A3**: Fix contamination leakage (BUG-003)
4. **A4**: Handle game_over signal with dramatic UI (BUG-004) — **DONE**

### Phase B — Content Completion (2-3 days)
1. **B1**: Audio layer (pour hum, fill clank, contamination buzz, gate click, waste tick)
2. **B2**: Mold cool/harden animation (tween chain in _trigger_complete)
3. **B3**: Gate routing disclosure (labels on buttons + persistent indicators)
4. **B4**: Speed timer display (wire SpeedTimer.gd to UI)
5. **B5**: Intake glow amplification (0.8s + particle burst)

### Phase C — Polish/Juice (2-3 days)
1. **C1**: Fill bar smoothing (tween)
2. **C2**: Gate toggle animation (elastic tween)
3. **C3**: Waste meter 80% warning threshold
4. **C4**: Order transition fanfare
5. **C5**: Locked mold visual distinction
6. **C6**: Hardcoded path refactor (TD-003)

---

## Open Questions (For Creative Director)

1. **Speed bonus threshold** — 30s is too tight for Orders 2+3 given the routing complexity. Keep at 30s (skilled bonus), widen to 45s (accessible), or per-order (30/40/50s)?
2. **Gate routing disclosure** — visible from start, or earned through experimentation?
3. **Audio style** — procedural (Godot AudioStreamGenerator) or free samples?
4. **Prototype complete scope** — 3 orders loop forever (score only), or are more levels planned?
5. **Mobile playtesting** — has hold-to-pour been tested on actual hardware?
6. **Score breakdown** — show per-order receipt, only at end, or always visible?
7. **Performance budget** — framerate floor for mobile? Affects Phase C juice items.

---

## Five-Agent Analysis Output Files

| File | Role | Size |
|------|------|------|
| /tmp/designer_report.md | Designer | 15KB |
| /tmp/coder_report.md | Coder | 21KB |
| /tmp/artist_report.md | Artist | 9KB |
| /tmp/producer_report.md | Producer | 18KB |
| /tmp/qa_report.md | QA | 22KB |

---

## Commit History (this project)

```
SMOKE CHECK: metalblob_freeze_fix (HEAD)
8648426 feat: GateDebugHUD — F1-toggleable debug overlay for playtesting
f820a62 fix: BUG-FLOW-001 (silent wrong-mold routing), BUG-RESULT-001 (dict key fallback), BUG-GATE-001 (CONNECT_ONE_SHOT)
10ce7a3 fix: P0 bugs (WasteMeter, PourZone color, Intake dead signal) + SpeedTimer
dc01e6e fix 4 more bugs: screen→world coords, clear_mold API, orphaned signals
29d96b0 fix 4 bugs: gate mid-pour accumulator flush, orphaned PourStream removal, waste tracking in fallback, G3 routing rebalance
2c9c78d Install native Linux Godot 4.6.2; update validate.sh and docs to use ~/.local/bin/godot
ce4207c Docs: update dev diary (late night session — part_requests bug, check_9, patterns)
77673b5 Fix Mold.gd: remove erroneous .required_metal chain; add detect_constructor_mismatches.py check to validate.sh
ne6b39ec Fix: add part_requests to OrderDefinition; update GameData orders
e18776b Docs: add evening session (RID leaks, MCP testing) to dev diary
4a6f788 Fix RID leaks in test scripts; update handoff with MCP status
9cfeff6 Docs: add Gate/MetalSelector warning fixes to dev diary
```
