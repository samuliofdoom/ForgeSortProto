# PRODUCER_REVIEW.md
## ForgeSortProto — Production Readiness Synthesis

**Author:** Producer  
**Date:** 2026-04-30  
**Status:** Pre-ship analysis complete  
**Based on:** PRODUCTION_ROADMAP.md, dev_diary.md, Docs/DESIGNER_REVIEW.md, Docs/QA_REVIEW.md, Docs/ARTIST_VISUAL_AUDIT.md (Docs/CODER_REVIEW.md was not found), FEATURE_006_ATMOSPHERE.md, FEATURE_007_MOLTEN_STREAM.md

**Note:** Docs/CODER_REVIEW.md was not found in the repository at time of writing. Cross-team synthesis uses dev_diary summaries for Coder findings plus actual Designer and QA review docs for Designer and QA findings.

---

## 1. Current Build Status

### validate.sh Output
```
=== GDScript Validation ===
Checking signal handlers...         OK
Checking scene structure...         OK — Main.tscn: load_steps=19, ext=15, sub=4
Checking script references...       OK
Checking autoloads...                OK
Checking scripts with full compilation... OK — no Godot warnings
Checking GDScript parse errors...    OK — scripts/dev/smoke_check.gd, verify_game_loads.gd
Checking with gdlint...             SKIP (gdlint unavailable)
Checking unused GDScript parameters... OK
Checking constructor call-site vs _init signature... OK
=== Validation PASSED ===  (exit 0)
```

### Headless Godot Run
```
Godot Engine v4.6.2.stable.official.71f334935
(exits clean with exit code 0, no errors)
```

### Conclusion
Build is clean. 9/9 validation checks pass. No runtime errors in headless smoke test. Game is playable.

---

## 2. Cross-Team Issue Synthesis

Issues flagged by 2 or more agents (deduplicated across Coder, Designer, QA, Artist reports from dev_diary.md):

| Issue | Agents Reporting | Summary |
|-------|----------------|---------|
| Speed bonus uses game clock not per-order clock (BUG-001) | Coder, QA | Order 2+3 can never qualify for speed bonus |
| flush_accumulator double-penalizes on gate toggle (BUG-002) | Coder, QA, Designer | Player loses metal AND gets waste penalty for one mistake |
| Mold contamination leaks across orders (BUG-003) | Coder, QA | Contaminated mold persists into next order if not needed |
| game_over signal has no UI handler (BUG-004) | Designer, QA | Waste-based game end goes straight to result, no drama |
| Audio entirely absent | Designer, Artist | No pour hum, fill clank, gate click, contamination buzz, waste tick |
| Mold cool/harden animation missing | Artist | Tween chain in Mold._trigger_complete() not implemented |
| Gate routing invisible / unlabeled | Designer, Artist | G1–G4 route labels (A/B, B/C, A+C, C) not shown persistently |
| Speed timer not counting | Designer | SpeedTimer.gd attached to Label but never wired to order_started signal |
| Fill bars jump (no tween) | Designer | Mold fill_bar updates in steps, not smoothly |
| Intake glow too fast (0.4s) | Artist | Should be 0.8s + particle burst |
| Gate toggle no animation | Designer, Artist | Buttons snap on/off, no elastic tween |
| Locked mold unclear | Designer, Artist | Desaturated + padlock but not readable at a glance |
| Rejection flash at wrong location | Designer | Flash shows at mold instead of pour origin |
| Order transition no fanfare | Designer | Green flash + scale pulse missing |
| Hardcoded /root/Main/MoldArea paths | Coder | TD-003 — fragile path coupling |
| GateDebugHUD F1 conflicts with Godot editor | Coder | F1 is Godot's editor help shortcut |

---

## 3. Ship Readiness: MUST FIX (Critical — blocks playability or correctness)

### BUG-001: Speed Bonus Per-Order Clock
- **Severity:** P1  
- **Who filed:** Coder, QA  
- **File:** `ScoreManager.gd:54`, `OrderManager.gd`  
- **Impact:** Orders 2 and 3 can NEVER earn speed bonus (30s threshold vs total game time)  
- **Fix:** Add `order_start_time` to OrderManager, set on `start_next_order()`, pass order elapsed to `calculate_order_score()`  
- **Estimated complexity:** Low (signal wiring + one new variable)

### BUG-002: flush_accumulator Double-Penalty
- **Severity:** P1  
- **Who filed:** Coder, QA, Designer  
- **File:** `MetalFlow.gd:50-54`  
- **Impact:** Gate toggle mid-pour charges waste AND routes to fallback mold — double punishment  
- **Fix:** Route via `FlowController.get_mold_for_pour_position()` WITHOUT calling `add_waste()`  
- **Estimated complexity:** Low (move one function call)

### BUG-003: Mold Contamination Persists Across Orders
- **Severity:** P1  
- **Who filed:** Coder, QA  
- **File:** `Mold.gd:150-158`  
- **Impact:** Mold contaminated in Order 1 carries into Order 2 if that mold isn't needed  
- **Fix:** Always call `clear_mold()` at order start (remove conditional on `is_complete or is_contaminated`)  
- **Estimated complexity:** Low (one-line change + signal verify)

### BUG-004: game_over Signal Has No UI Handler
- **Severity:** P1  
- **Who filed:** Designer, QA  
- **File:** `ResultPanel.gd`, `ScoreManager.gd:46`  
- **Impact:** Waste meter full → no dramatic "GAME OVER" moment, goes straight to results  
- **Fix:** Connect `game_over` in ResultPanel; add screen shake + flash + overlay before showing results  
- **Estimated complexity:** Medium (new signal handler + visual effects)

### BUG-006: Polygon2D Parse Error (PartPopEffect)
- **Severity:** P2  
- **Who filed:** Artist, PRODUCTION_ROADMAP  
- **File:** `PartPopEffect.gd:29-31`  
- **Impact:** Low — only triggers on part completion pop; headless passes cleanly  
- **Note:** PRODUCTION_ROADMAP says "likely editor-only or condition-specific". Needs editor repro to confirm exact trigger.  
- **Fix:** Verify `.tscn` load path for Polygon2D; confirm construction order in code is correct (it appears correct). If no repro, de-prioritize.  
- **Estimated complexity:** Unknown (needs repro first)

### SpeedTimer Not Wired to Order Clock
- **Severity:** P2
- **Who filed:** Designer, PRODUCTION_ROADMAP
- **File:** `SpeedTimer.gd`, `Main.tscn`
- **Impact:** Timer displays "0.0s" permanently — player has no speed bonus feedback
- **Fix:** Wire `OrderManager.order_started` → `SpeedTimer.start_counting()`, `order_completed` → `SpeedTimer.stop_and_show()`
- **Estimated complexity:** Low (signal connection)

### Missing Order Checklist UI (Designer Priority 1)
- **Severity:** P1
- **Who filed:** Designer (actual review doc)
- **File:** `scripts/game/OrderManager.gd:43` + new UI script
- **Impact:** `completed_parts_changed` fires but nothing renders it. Player cannot see order progress.
- **Fix:** Create `OrderUI` node with three part slots (blade/guard/grip). Subscribe to `completed_parts_changed`, mark slots complete with checkmark or fill.
- **Estimated complexity:** Low-Medium

### Debug Prints in Contamination Path
- **Severity:** P2
- **Who filed:** Designer
- **File:** `Mold.gd:164–165`
- **Impact:** `[MOLD] _trigger_contamination INCOMING: wrong_metal=` prints on every wrong-metal pour. Prototype code smell, floods console.
- **Fix:** Remove debug prints or guard with `if OS.is_debug_build()`
- **Estimated complexity:** Trivial

### NEW-001: Pour Position Routing Regression
- **Severity:** P1
- **Who filed:** QA
- **File:** `FlowController.gd` — `get_mold_for_pour_position()`
- **Impact:** When G1 and G2 both open, pouring at intake_b returns "blade" instead of "guard" — wrong mold routed
- **Test coverage:** `test_mold_for_pour_position_routing.gd` explicitly tests this regression (Test 5: G1+G2 both open, pour at intake_b → guard)
- **Estimated complexity:** Unknown (needs fix confirmation)

---

## 4. Ship Readiness: SHOULD FIX (Polish, significant UX)

### Audio Layer (entirely missing)
- **Severity:** P2  
- **Who filed:** Designer, Artist  
- **Impact:** Game feels silent; loses physicality of molten metal  
- **Fix:** Add AudioStreamPlayer nodes to PourZone, Mold, Gate, WasteMeter; wire to game events  
- **Decision needed:** Procedural (AudioStreamGenerator) vs free samples  
- **Estimated complexity:** Medium

### Gate Routing Disclosure
- **Severity:** P2  
- **Who filed:** Designer, Artist  
- **Impact:** Player doesn't know what G1–G4 routes do without experimentation  
- **Fix:** Persistent route labels near MoldArea + labels on GateToggleUI buttons (already in UI, just not visible enough)  
- **Estimated complexity:** Low

### Mold Cool/Harden Animation
- **Severity:** P2  
- **Who filed:** Artist, dev_diary polish gaps  
- **File:** `Mold.gd` `_trigger_complete()`  
- **Impact:** Completion state change is instant, not dramatic  
- **Fix:** Tween chain: white flash → desaturate → darken → scale bounce (already described in Artist Visual Audit)  
- **Estimated complexity:** Medium

### Intake Glow Amplification
- **Severity:** P2  
- **Who filed:** Artist  
- **Current:** 0.4s glow  
- **Target:** 0.8s + particle burst on pour start  
- **Estimated complexity:** Low

### Fill Bar Tween Smoothing
- **Severity:** P3  
- **Who filed:** Designer  
- **Impact:** Fill bars update in discrete jumps  
- **Fix:** Tween `fill_bar.value` in `Mold._update_display()` over 0.25s  
- **Estimated complexity:** Low

### Gate Toggle Animation
- **Severity:** P3  
- **Who filed:** Designer, Artist  
- **Impact:** Buttons snap on/off with no feel  
- **Fix:** Elastic tween on rotation (TRANS_ELASTIC + EASE_OUT) — already in scene but not hooked up  
- **Estimated complexity:** Low

### Locked Mold Visual Distinction
- **Severity:** P3  
- **Who filed:** Designer, Artist  
- **Impact:** Locked mold not immediately readable  
- **Fix:** Stronger desaturation + larger padlock + label "LOCKED"  
- **Estimated complexity:** Low

### Hardcoded MoldArea Paths (TD-003)
- **Severity:** P3 (tech debt)  
- **Who filed:** Coder  
- **Impact:** Fragile; breaks if scene structure changes  
- **Fix:** Cache `MoldArea` reference in `GameController._ready()`, expose via getter, use consistently  
- **Estimated complexity:** Medium

### GateDebugHUD F1 Key Conflict
- **Severity:** P3 (tech debt)  
- **Who filed:** Coder  
- **Impact:** F1 opens Godot editor help, not debug HUD  
- **Fix:** Change to F2 or Ctrl+F1  
- **Estimated complexity:** Trivial

---

## 5. Ship Readiness: NICE TO HAVE (Features, visual polish)

### FEATURE-006: Atmosphere System
- **Status:** Design doc EXISTS at `docs/FEATURE_006_ATMOSPHERE.md` — no longer blocked on design  
- **Scope:** Furnace glow shader (radial pulse), ember particle retune, heat darkening overlay, background gradient  
- **Impact:** Transforms flat dark background into a living forge environment  
- **Estimated complexity:** Medium (shader + particle retuning)

### FEATURE-007: Molten Stream Simulation
- **Status:** Design doc EXISTS at `docs/FEATURE_007_MOLTEN_STREAM.md` — no longer blocked on design  
- **Scope:** Stream glow shader, wobble shader, dual Line2D (core + halo), drip particles, splatter burst, pour point radial glow  
- **Impact:** The single most visually transformative feature for playability  
- **Estimated complexity:** Medium-High

### Flow Channel Lines
- **Severity:** P4  
- **Impact:** Subtle guide lines showing routing paths between gates  
- **Estimated complexity:** Low

### Rejection Flash at Pour Origin
- **Severity:** P4  
- **Impact:** Wrong metal rejection flash appears at mold, not where player was aiming  
- **Estimated complexity:** Low

### Order Transition Fanfare
- **Severity:** P4  
- **Impact:** No audio/visual celebration on order completion  
- **Estimated complexity:** Low

### Screen Shake on Contamination
- **Severity:** P4  
- **Impact:** Contamination should feel impactful  
- **Estimated complexity:** Low

### UI Button Theming
- **Severity:** P4  
- **Impact:** Default Godot buttons vs forge-styled (dark BG, orange border, uppercase)  
- **Estimated complexity:** Low

### Mold Texture/Bevel
- **Severity:** P4  
- **Impact:** Plain ColorRect molds vs beveled/shadowed mold shapes  
- **Estimated complexity:** Low

---

## 6. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **BUG-004 (game_over UI) slips** — game ends with no dramatic moment, player confusion | Medium | High | Reserve fix for Phase A; add to ship checklist |
| 2 | **Audio layer under-scoped** — decision between procedural vs samples not made, blocks implementation | Medium | Medium | Designer resolves audio direction in Phase B kickoff |
| 3 | **FEATURE-006/007 added to ship scope** — design docs now exist, pressure to include them | Medium | High | Explicit scope freeze: FEATURE-006/007 are post-launch |
| 4 | **BUG-006 Polygon2D parse error — real in editor** — only repros in Godot editor, not headless | Low | Medium | Assign coder to repro in editor during Phase A; if no repro, close as won't-fix |
| 5 | **GateDebugHUD F1 conflict causes debug confusion** during playtesting | Low | Low | Fix to F2 in Phase A (trivial change) |

---

## 7. Production Phases

### Phase A — Must Fix (1-2 days)
|| ID | Item | Owner | Files | Complexity |
|----|------|-------|-------|-----------|
| A1 | Fix speed bonus per-order clock (BUG-001) | Coder | `ScoreManager.gd`, `OrderManager.gd` | Low |
| A2 | Fix flush_accumulator double-penalty (BUG-002) | Coder | `MetalFlow.gd` | Low |
| A3 | Fix mold contamination across orders (BUG-003) | Coder | `Mold.gd` | Low |
| A4 | Add game_over UI handler with drama (BUG-004) | Coder + Artist | `ResultPanel.gd`, `ScoreManager.gd` | Medium |
| A5 | Wire SpeedTimer to order clock | Coder | `SpeedTimer.gd`, signal wiring | Low |
| A6 | GateDebugHUD F1 → F2 (TD-004) | Coder | `Main.tscn`, `GameController.gd` | Trivial |
| A7 | BUG-006 Polygon2D repro in editor | Coder | `PartPopEffect.gd` | Unknown (repro first) |
| A8 | Restart button resets all state fully | QA | `GameController.gd`, `Mold.gd` | Verify + fix |
| A9 | Add Order Checklist UI (new) | Coder + Designer | `OrderManager.gd`, new `OrderUI` script | Low-Medium |
| A10 | Remove debug prints from Mold.gd contamination path | Coder | `Mold.gd:164–165` | Trivial |

### Phase B — Should Fix (2-3 days)
| ID | Item | Owner | Files | Complexity |
|----|------|-------|-------|-----------|
| B1 | Audio layer — minimum (pour hum, fill clank, contamination buzz, gate click) | Designer (audio direction) + Coder | `PourZone.gd`, `Mold.gd`, `Gate.gd`, `WasteMeter.gd` | Medium |
| B2 | Mold cool/harden animation (tween chain) | Artist + Coder | `Mold.gd` | Medium |
| B3 | Gate routing disclosure (persistent labels + button labels) | Designer | `Main.tscn`, `GateToggleUI.gd` | Low |
| B4 | Intake glow amplification (0.8s + particle burst) | Artist | `PourZone.gd`, `Main.tscn` | Low |
| B5 | Fill bar tween smoothing | Coder | `Mold.gd` | Low |
| B6 | Gate toggle elastic animation | Coder | `Gate.gd` | Low |
| B7 | Locked mold visual distinction (stronger desaturation + label) | Artist | `Mold.gd`, `Main.tscn` | Low |
| B8 | Hardcoded path refactor TD-003 (cache MoldArea in GameController) | Coder | `GameController.gd`, `FlowController.gd`, `MetalFlow.gd` | Medium |

### Phase C — Nice to Have (2-3 days, post-launch)
| ID | Item | Owner | Files | Complexity |
|----|------|-------|-------|-----------|
| C1 | FEATURE-006 Atmosphere system (design doc exists — implement post-launch) | Artist | `Main.tscn`, `FurnaceAtmosphere`, `EmberParticles` | Medium |
| C2 | FEATURE-007 Molten stream simulation (design doc exists — implement post-launch) | Artist + Coder | `PourZone.gd`, `shaders/` | Medium-High |
| C3 | Flow channel lines (subtle routing guide lines) | Artist | `Main.tscn` | Low |
| C4 | Rejection flash at pour origin | Coder | `PourZone.gd`, `Mold.gd` | Low |
| C5 | Order transition fanfare (audio + visual) | Designer + Artist | `OrderManager.gd`, audio files | Low |
| C6 | Screen shake on contamination | Coder | `Mold.gd` | Low |
| C7 | UI button theming (forge aesthetic) | Artist | `Main.tscn`, button scenes | Low |
| C8 | Mold bevel/texture | Artist | `Mold.gd`, `Main.tscn` | Low |

---

## 8. Team Assignment

| Role | Primary Assignments |
|------|-------------------|
| **Coder** | BUG-001, BUG-002, BUG-003, BUG-004 (ResultPanel wiring), BUG-006 (repro), SpeedTimer wire, F1→F2 fix, hardcoded path refactor, fill bar tween, gate animation, rejection flash at origin, screen shake |
| **Designer** | Audio direction decision (procedural vs samples), gate routing disclosure UX, SpeedTimer UX (display format), restart flow confirmation, score breakdown display |
| **QA** | Write test_pour_position_routing.gd, gate-toggle-during-pour test, game_over UI test, test_ui_panels.gd, test_mold_lock_and_contamination.gd; verify Phase A fixes; sign off on restart flow |
| **Artist** | Mold cool/harden animation (tween chain spec), intake glow amplification, locked mold visual, FEATURE-006 atmosphere (shader + particles), FEATURE-007 molten stream (shaders + drip particles), flow channel lines, UI button theming, mold bevel |

---

## 9. Final Checklist

### Phase A — Must Fix (Coder + QA)

1. [ ] **BUG-001 fixed** — Speed bonus uses `order_start_time` not game clock. QA verifies Orders 2 and 3 can now qualify for speed bonus.
2. [ ] **BUG-002 fixed** — `flush_accumulator` routes without double-charging waste on gate toggle mid-pour.
3. [ ] **BUG-003 fixed** — `clear_mold()` called unconditionally at order start. QA runs contamination cross-order test.
4. [ ] **BUG-004 fixed** — `game_over` signal triggers dramatic UI (screen shake + flash + "GAME OVER" overlay) before result screen.
5. [ ] **SpeedTimer wired** — Timer starts on `order_started`, stops on `order_completed`, displays elapsed seconds.
6. [ ] **GateDebugHUD** — Changed from F1 to F2. Verified no Godot editor conflict.
7. [ ] **BUG-006 repro'd** — Coder opens game in Godot editor and triggers part completion pop. Exact error message documented. Fix applied or bug closed as won't-fix.
8. [ ] **Restart verified** — Restart button fully resets all state: score=0, waste=0, molds cleared, order index=0. No contamination or state leakage.
9. [ ] **Order Checklist UI** — Three part slots (blade/guard/grip) visible during play, subscribed to `completed_parts_changed`. Player can see order progress at a glance.
10. [ ] **Debug prints removed** — `[MOLD] _trigger_contamination` console prints removed or guarded with `OS.is_debug_build()`.
11. [ ] **Headless smoke test** — `godot --headless --quit-after 300` still exits clean after all Phase A changes.
12. [ ] **validate.sh** — Still passes 9/9 after Phase A changes.

### Phase B — Should Fix (Designer + Coder + Artist)

11. [ ] **Audio layer** — Designer confirms audio direction (procedural vs samples). Coder implements minimum viable audio: pour hum, fill clank, contamination buzz, gate click, waste tick. Game sounds alive.
12. [ ] **Gate routing visible** — Persistent route labels visible near MoldArea. GateToggleUI buttons show labels (A/B, B/C, A+C, C).
13. [ ] **Mold hardening animation** — Tween chain plays on mold completion: white flash → desaturate → darken → scale bounce.
14. [ ] **Intake glow** — Glow duration 0.8s, particle burst on pour start.
15. [ ] **Fill bars tween** — Fill progress animates smoothly (0.25s tween), not in discrete jumps.
16. [ ] **Gate toggle elastic** — Gate buttons animate with elastic rotation ease.
17. [ ] **Locked mold clear** — Stronger desaturation + larger padlock icon + "LOCKED" label readable at a glance.
18. [ ] **MoldArea paths refactored** — `GameController._ready()` caches `MoldArea` reference. `FlowController` and `MetalFlow` use getter, no hardcoded `/root/...` paths.

### Phase C — Nice to Have (Post-Launch)

19. [ ] **FEATURE-006 atmosphere** — Implement per `docs/FEATURE_006_ATMOSPHERE.md`: glow shader, ember particle retune, heat darkening overlay.
20. [ ] **FEATURE-007 molten stream** — Implement per `docs/FEATURE_007_MOLTEN_STREAM.md`: stream glow shader, wobble, dual Line2D, drip particles, splatter burst.
21. [ ] **Flow channel lines** — Subtle `Line2D` guides showing routing paths (alpha 0.2).
22. [ ] **Rejection flash at origin** — Wrong metal rejection flash appears at pour point, not at target mold.
23. [ ] **Order fanfare** — Audio + visual celebration on order completion.
24. [ ] **Screen shake on contamination** — Brief viewport offset tween when mold is contaminated.
25. [ ] **UI button theming** — Forge-styled buttons: dark background, orange border, uppercase text.
26. [ ] **Mold bevel/texture** — Bevel/highlight effect on mold sprites.

---

## Notes

- **FEATURE-006 and FEATURE-007 design docs now exist** (`docs/FEATURE_006_ATMOSPHERE.md`, `docs/FEATURE_007_MOLTEN_STREAM.md`). The PRODUCTION_ROADMAP marked them "BLOCKED — awaiting design doc" but the creative team has delivered those docs. They remain classified as post-launch scope for this prototype ship, but are no longer blocked on design.
- **Prototype ship scope is 3 orders loop, score only.** The production roadmap asks "are more levels planned?" — this needs a creative director decision before Phase C.
- **Restart flow needs QA verification.** The dev diary notes "Restart button works and resets all state fully" but this should be explicitly tested, not assumed.
- **Mobile playtesting** — has hold-to-pour been tested on actual hardware? Not mentioned in any review. Recommend Phase B include mobile smoke test.
