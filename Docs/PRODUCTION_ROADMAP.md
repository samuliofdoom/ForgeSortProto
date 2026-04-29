# ForgeSortProto — Production Roadmap

**Last Updated:** 2026-04-30
**Status:** Feature-complete, post-team-analysis. Game is playable. Ship blockers documented.

---

## Validation Status

| Check | Result |
|-------|--------|
| `./validate.sh` | PASS — 9/9 checks green |
| `godot --headless --quit-after 300` | PASS — exits clean (no errors) |

---

## What's Done

### Core Game Loop
- Hold+sweep pour mechanic with per-metal stream width/speed tuning (Iron/Steel/Gold)
- 4-gate routing system (G1=A/B, G2=B/C, G3=A+C, G4=C) with toggle UI
- 3 molds (Blade/Guard/Grip) with fill → hardening → completion state machine
- Contamination detection and tap-to-clear mechanic
- Waste meter with hard-fail at 100%
- Score tracking with per-order speed bonus
- Result screen + restart

### UI / UX
- Metal selector (Iron/Steel/Gold buttons)
- Score display, waste meter, speed timer
- Gate toggle UI with route labels (A/B, B/C, A+C, C)
- Order panel showing current recipe
- Part-pop effect on mold completion (Polygon2D silhouettes)
- Start/restart flow

### Visual Feedback
- Furnace glow pulse animation
- Ember particles (CPUParticles2D)
- Pour stream line + glow at cursor
- Mold fill bars with color-coded states
- Mold state labels (Cooling..., Done!, Tap to Clear, Locked, %%)
- Mold hardening animation (white flash → desaturate → darken → scale bounce)
- Padlock icon on locked molds (programmatic, with pulse tween)
- Contamination flash + rejection flash at pour origin

### Infrastructure
- Autoload architecture: OrderManager, ScoreManager, MetalFlow, FlowController, MetalSource, GameData, GameController
- Full signal wiring for game events
- 49 GDScript files (21 game scripts, 19 dev tests, 9 data/UI)
- validate.sh with 9 automated checks
- Headless smoke test

### Bugs Fixed (BUG-001 through BUG-005)
- **BUG-001:** Speed bonus now uses per-order timer (`order_start_time`) instead of game clock
- **BUG-002:** `flush_accumulator` routes metal via FlowController without double-penalizing
- **BUG-003:** Mold clears itself at order start regardless of contamination state
- **BUG-004:** `game_over` signal (waste meter full) connected to ResultPanel
- **BUG-005:** Various signal/RID leaks and orphaned node cleanup

---

## What's Remaining

### Issue 1 — FEATURE-006: Atmosphere System
- **Type:** P0 Feature
- **Status:** BLOCKED — awaiting design doc from creative team
- **Description:** Persistent furnace ambience, dynamic background lighting tied to pour activity, heat haze
- **What's needed:** Design doc specifying atmosphere elements, how they scale with gameplay intensity, and performance budget for mobile
- **Blocking:** No concrete scope; creative direction unclear (stylized vs realistic, mobile perf targets)

### Issue 2 — FEATURE-007: Molten Stream Simulation
- **Type:** P0 Feature
- **Status:** BLOCKED — awaiting design doc from creative team
- **Description:** Improved pour stream with fluid-like behavior, glow bloom, particle density scaling
- **What's needed:** Design doc specifying stream feel (trickle vs gush), metal viscosity differences, performance constraints
- **Blocking:** No concrete scope; decisions about CPUParticle2D vs GPU particles, mobile compatibility

### Issue 3 — BUG-006: Polygon2D Parse Error
- **Type:** P2 Bug
- **Status:** Open — parse-time error during scene load
- **Root Cause:** `PartPopEffect.gd` line 29 calls `Polygon2D.new()` with no `.polygon` property set at construction time; `Polygon2D` inherits from `Node2D` and has no default constructor in Godot 4.6
- **Impact:** Low — only triggers on part completion pop; game otherwise runs clean
- **Fix:** Set `polygon.polygon = PackedVector2Array(...)` immediately after construction (already done on line 31), OR use a pre-instantiated scene (Polygon2D is a leaf node, no scene needed). The code order on line 29–31 already does this correctly, so the actual parse error is likely in the `.tscn` load path or a type annotation issue.
- **Note:** Godot headless exits clean — the parse error may only surface in the editor or under specific conditions. Needs investigation with `--editor` or a debug build to confirm the exact trigger.

### Issue 4 (New) — Technical Debt: Hardcoded Node Paths
- **Type:** Technical Debt
- **Status:** Known issue (TD-003 from dev_diary.md)
- **Description:** `FlowController.gd` and `MetalFlow.gd` use hardcoded `/root/...` paths for MoldArea lookups; `GameController.get_mold_area()` exists but is not consistently used
- **Impact:** Fragile; breaks if scene structure changes
- **Fix:** Cache `MoldArea` reference once in `GameController` at `_ready()`, expose via getter, have `FlowController` and `MetalFlow` use it

### Issue 5 (New) — Missing Audio Layer
- **Type:** P2 Polish
- **Status:** Not started
- **Description:** No audio anywhere in the game — no pour hum, fill clank, gate click, contamination buzz, waste tick, order fanfare
- **Impact:** Game feels quiet/silent; loses physicality of molten metal
- **Fix:** Add AudioStreamPlayer nodes to PourZone, Mold, Gate, WasteMeter; wire to appropriate game events. Use procedural (AudioStreamGenerator) or free samples per creative direction decision (see Issue 8)

### Issue 6 (New) — Speed Timer UI Has No Source Signal
- **Type:** P2 Bug
- **Status:** Script exists (`SpeedTimer.gd`) and is attached to a Label in Main.tscn, but no signal wires it to actual order elapsed time
- **Impact:** Timer displays "0.0s" permanently; player has no feedback on speed bonus eligibility
- **Fix:** Wire `SpeedTimer` to `OrderManager.order_started` to begin counting, and `OrderManager.order_completed` to show final time

---

## Priority Ordering

| # | Item | Priority | Blocking | Notes |
|---|------|----------|----------|-------|
| 1 | FEATURE-006 Atmosphere | P0 | Design doc | No scope; blocked until creative team delivers doc |
| 2 | FEATURE-007 Molten Stream | P0 | Design doc | No scope; blocked until creative team delivers doc |
| 3 | BUG-006 Polygon2D parse error | P2 | None | Needs repro — headless passes; likely editor-only or condition-specific |
| 4 | Hardcoded MoldArea paths (TD) | P3 | None | Refactor; doesn't affect gameplay |
| 5 | Audio layer | P2 | Creative direction (samples vs procedural) | No audio at all currently |
| 6 | SpeedTimer signal wire | P2 | None | Timer stuck at 0.0s |

---

## What's Blocking Each Item

| Item | Blocker | Unblock Action |
|------|---------|----------------|
| FEATURE-006 Atmosphere | No design doc | Creative team writes atmosphere spec (scope, performance, visuals) |
| FEATURE-007 Molten Stream | No design doc | Creative team writes stream sim spec (particle budget, mobile targets) |
| BUG-006 Polygon2D | Cannot reproduce in headless | Need editor or debug build to get exact error message; confirm trigger condition |
| Hardcoded paths | None | Coder can refactor `GameController.get_mold_area()` → cached ref in `FlowController` |
| Audio layer | Creative direction decision | Designer answers: procedural (AudioStreamGenerator) or free samples? |
| SpeedTimer | None | Coder wires `order_started` signal to start timer |

---

## Ship It Checklist

### Must Pass Before Ship
- [ ] `./validate.sh` passes (currently 9/9 green)
- [ ] `godot --headless --path . --quit-after 300` exits clean (currently clean)
- [ ] All P0 bugs fixed (BUG-001 through BUG-005 — done)
- [ ] BUG-006 reproduced and fixed (or confirmed non-critical)
- [ ] SpeedTimer actually counts elapsed time (currently dead)
- [ ] `game_over` signal shows dramatic UI (waste meter full → game over screen)
- [ ] Restart button works and resets all state fully

### Should Fix Before Ship
- [ ] Audio layer (at minimum: pour hum, mold fill clank, contamination buzz, gate click)
- [ ] Hardcoded `/root/Main/MoldArea` paths refactored to cached reference
- [ ] GateDebugHUD F1 key does not conflict with Godot editor F1 (change to F2 or Ctrl+F1)

### Nice to Have (Post-Launch)
- [ ] FEATURE-006 Atmosphere system (blocked on design doc)
- [ ] FEATURE-007 Molten stream simulation (blocked on design doc)
- [ ] Fill bar tween smoothing (currently jumps)
- [ ] Gate toggle animation (elastic rotation)
- [ ] Waste meter 80% warning threshold (visual escalation)
- [ ] Order transition fanfare
- [ ] Intake glow amplification (0.8s + particle burst)

---

## Open Questions for Creative Director

1. **Prototype complete scope** — 3 fixed orders loop forever (score only), or are more levels planned?
2. **Audio style** — procedural (Godot AudioStreamGenerator) or free samples?
3. **FEATURE-006 Atmosphere** — has a design doc been started? What's the performance budget for mobile?
4. **FEATURE-007 Molten Stream** — has a design doc been started? GPU particles or CPUParticle2D?
5. **BUG-006** — has the Polygon2D parse error been seen in the Godot editor? What is the exact error message?
6. **Speed bonus threshold** — 30s per order is current. Is this for skilled players only, or should it be widened for accessibility?
