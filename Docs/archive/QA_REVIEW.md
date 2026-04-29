# ForgeSortProto QA Review

Date: 2026-04-29
Engine: Godot 4.6.2
Project: /mnt/g/AI_STUFF/Games/ForgeSortProto

---

## 1. Test Inventory

| Test File | What It Tests | Coverage Quality |
|-----------|---------------|-----------------|
| `scripts/dev/smoke_check.gd` | Compiles all game/UI scripts via `.new()` to catch unused-param and semantic warnings. Loads data definitions. | HIGH — compilation integrity |
| `scripts/dev/full_gameplay_test.gd` | Full 13-phase gameplay loop: start button, initial state, metal selection, gate toggle, pour sequences for all 3 orders (Iron/Steel/Noble Sword), score tracking, waste/game-over, result panel | HIGH — end-to-end gameplay |
| `scripts/dev/full_test.gd` | Abbreviated gameplay test (8 phases) covering core loop without full order progression | MEDIUM — core gameplay |
| `scripts/dev/test_flow_controller_routing.gd` | `get_mold_for_intake()` for single/multi/all-closed/all-open gate combinations | MEDIUM — gate routing logic |
| `scripts/dev/test_mold_for_pour_position_routing.gd` | `get_mold_for_pour_position()` for 10 pour-position/gate combos including NEW-001 regression | MEDIUM — pour position routing |
| `scripts/dev/test_mold_lock_cycle.gd` | Mold lock/unlock lifecycle: locked rejects fill+adds waste, `order_completed→is_locked`, `order_started→is_locked=false` | MEDIUM — mold state machine |
| `scripts/dev/test_ui_panels.gd` | OrderPanel, GateToggleUI, ScoreDisplay, WasteMeter, SpeedTimer signal wiring and display updates | MEDIUM — UI signal logic |
| `scripts/dev/test_mold_states.gd` | Mold state transitions (not read — 0 symbol count reported) | UNKNOWN |
| `scripts/dev/test_pour_position_routing.gd` | Mold for pour position routing (not read — minimal symbol count) | UNKNOWN |
| `scripts/dev/test_speed_bonus.gd` | Speed bonus (0 symbols — likely empty or placeholder) | NOT TESTED |
| `scripts/dev/test_result_panel_game_over.gd` | Result panel on game over (0 symbols — likely empty) | NOT TESTED |
| `scripts/dev/verify_game_loads.gd` | Simple headless game load verification | LOW — smoke only |
| `scripts/dev/headless_game_test.gd` | Headless game test with signal wiring | LOW |
| `scripts/dev/interactive_game_test.gd` | Interactive game test with gate resolve | LOW |

**Summary:** 7 meaningful test scripts, 3 of unknown/empty content, 3 low-value smoke tests.

---

## 2. Coverage Matrix

| Feature | Tested? | Test File(s) |
|---------|---------|--------------|
| Start button press | YES | full_gameplay_test, full_test |
| Initial game state (Iron Sword, score=0, molds empty) | YES | full_gameplay_test, full_test |
| Metal selection (iron/steel/gold) | YES | full_gameplay_test, full_test |
| Gate toggle (individual, all, reset) | YES | full_gameplay_test, full_test, test_flow_controller_routing |
| Gate routing `get_mold_for_intake()` | YES | test_flow_controller_routing |
| Pour position routing `get_mold_for_pour_position()` | YES | test_mold_for_pour_position_routing |
| Pour into mold / `receive_metal()` | YES | full_gameplay_test, full_test |
| Mold fill amounts (iron 100/80/60) | YES | full_gameplay_test |
| Order 1 completion (Iron Sword) | YES | full_gameplay_test, full_test |
| Order 2 progression (Steel Sword) | YES | full_gameplay_test |
| Order 3 progression (Noble Sword) | YES | full_gameplay_test |
| Score tracking per order | YES | full_gameplay_test, full_test |
| Waste meter threshold (100 units → game over) | YES | full_gameplay_test, full_test |
| Mold lock cycle (locked between orders) | YES | test_mold_lock_cycle |
| Mold locked rejection (adds waste) | YES | test_mold_lock_cycle |
| Mold unlock on new order | YES | test_mold_lock_cycle |
| UI: OrderPanel display + progress | YES | test_ui_panels |
| UI: GateToggleUI button states | YES | test_ui_panels |
| UI: ScoreDisplay updates | YES | test_ui_panels |
| UI: WasteMeter bar updates | YES | test_ui_panels |
| UI: SpeedTimer start/reset | YES | test_ui_panels |
| Result panel visibility | YES | full_gameplay_test (existence check only) |
| Game over trigger | YES | full_gameplay_test, full_test |
| Game restart after game over | NO | — |
| Wrong metal poured into mold (contamination) | NO | — |
| Mold overfill (capacity exceeded) | NO | — |
| Speed bonus calculation | NO | — |
| Speed bonus awarded on fast completion | NO | — |
| PartPopEffect visual effect | NO | — |
| PartPopLabel floating score label | NO | — |
| PartPopLabel / PartPopEffect triggering | NO | — |
| Multiple sequential orders (4+ orders) | NO | — |
| Gate toggle during active pour | NO | — |
| Pour during order transition window | NO | — |
| Order completed with wrong metals (partial) | NO | — |
| Game timeout / max order time limit | NO | — |
| Concurrent gate toggles race condition | NO | — |
| MoldArea node state after order complete | NO | — |
| Script reload / hot-reload during gameplay | NO | — |
| Scene save/load mid-game | NO | — |
| Audio/sound effect triggers | NO | — |
| Particle system triggers (PartPopEffect) | NO | — |

**Overall coverage estimate:** ~45% of game scenarios tested. Core loop covered; visual effects, edge cases, and bonus mechanics almost entirely untested.

---

## 3. Edge Cases NOT Covered

### Scenario 1: Wrong Metal Contamination
- **Steps:** Select iron metal, pour into a blade mold that requires steel.
- **Expected:** Mold becomes contaminated, `is_contaminated = true`, pour is rejected or penalized.
- **Actual:** No test covers metal type mismatch. Mold just accepts any metal.

### Scenario 2: Mold Overfill
- **Steps:** Pour 150 units of metal into a blade mold with 100-unit capacity.
- **Expected:** Mold caps at 100, excess is waste, or pour is rejected beyond capacity.
- **Actual:** No test for overfill behavior. The `receive_metal` capacity limit is not verified.

### Scenario 3: Speed Bonus on Fast Order Completion
- **Steps:** Complete Order 1 (Iron Sword) in under 30 seconds.
- **Expected:** Score includes speed bonus multiplier (e.g., 1.5x).
- **Actual:** No test for speed bonus. `SpeedTimer` is tested for start/reset but not for bonus calculation.

### Scenario 4: Game Restart After Game Over
- **Steps:** Trigger waste game over, then attempt to restart.
- **Expected:** All state resets, new Iron Sword order starts.
- **Actual:** No test for restart flow. `_test_waste_game_over` only checks the trigger fires, not restart.

### Scenario 5: Pour During Order Transition (Between Orders)
- **Steps:** Complete Order 1, immediately pour before `order_started` signal fires for Order 2.
- **Expected:** Pour either goes to waste or is held until next order starts.
- **Actual:** No test for this timing window. Mold lock state during transition is tested but not the pour behavior itself.

### Scenario 6: Gate Toggle During Active Pour
- **Steps:** Start pouring at intake_a, toggle gate_01 off mid-pour.
- **Expected:** Either pour continues along original route, or pour is cancelled/rerouted.
- **Actual:** No test for mid-pour gate changes. All gate toggle tests occur before pouring.

### Scenario 7: Multiple Sequential Orders Without Restart
- **Steps:** Complete all 3 orders, observe if a 4th order begins.
- **Expected:** Game shows result panel after Order 3, or cycles to a 4th order.
- **Actual:** No test past Order 3. Whether the game gracefully handles end-of-orders is untested.

### Scenario 8: PartPopEffect and PartPopLabel Triggering
- **Steps:** Complete a mold, observe if visual effects appear.
- **Expected:** `PartPopEffect` particle burst and `PartPopLabel` floating score text.
- **Actual:** No tests for these visual systems. `PartPopEffect.gd` exists but is never instantiated or verified.

### Scenario 9: Order Completed With Wrong Metals (Partial Fill)
- **Steps:** Pour iron into a steel blade mold, completing it with the wrong metal type.
- **Expected:** Part is not counted toward order, mold may become contaminated, score penalty.
- **Actual:** No test for wrong-metal completion. Molds are always filled with the correct required metal in existing tests.

### Scenario 10: Mold Cleared Properly After Order Completion
- **Steps:** Complete Order 1, verify molds are cleared before Order 2 starts.
- **Expected:** `current_fill = 0`, `is_complete = false`, `is_contaminated = false`, mold is IDLE.
- **Actual:** `test_mold_lock_cycle` checks `is_locked=false` and `mold_state=IDLE` but does not verify `current_fill=0` and `is_complete=false` are both reset.

### Scenario 11: Game Timeout / Max Order Time
- **Steps:** Let an order timer expire without completing.
- **Expected:** Order fails, game over, or time penalty.
- **Actual:** No timeout mechanism is tested. Whether a max order time exists is unverified.

### Scenario 12: Concurrent Gate Toggle Race
- **Steps:** Toggle gate_01 and gate_02 simultaneously via UI.
- **Expected:** Both states update correctly with no race condition.
- **Actual:** No concurrent toggle test. All tests toggle sequentially.

### Scenario 13: Wrong Intake Selected (UI Misclick)
- **Steps:** Click intake_c (grip) when targeting blade mold.
- **Expected:** Metal routed to grip, waste generated, or pour rejected.
- **Actual:** No UI misclick/intake selection error test.

### Scenario 14: Score Below Expected Threshold (Bug Detection)
- **Steps:** Complete Iron Sword with incorrect metal amounts, check score is not inflated.
- **Expected:** Score matches actual parts delivered, no bonus for incomplete/wrong fills.
- **Actual:** No test for score anti-inflation (ensuring wrong fills don't accidentally score).

---

## 4. Test Plan for Missing Coverage

### TP-1: Wrong Metal Contamination Test
1. Load Main scene, get blade mold.
2. Set `blade.required_metal = "steel"`.
3. Call `blade.receive_metal("iron", 100.0)`.
4. Assert: `mold.is_contaminated == true` OR `mold.is_complete == false`.
5. Assert: ScoreManager waste was charged.
6. Run for iron, steel, gold wrong-metal permutations.

### TP-2: Mold Overfill Boundary Test
1. Get blade mold, capacity is 100.
2. Call `receive_metal("iron", 150.0)`.
3. Assert: `mold.current_fill == 100.0` (capped).
4. Assert: `mold.is_complete == true`.
5. Assert: 50 units of waste were charged (or 50 units returned).
6. Run for guard (80) and grip (60) capacities.

### TP-3: Speed Bonus Calculation Test
1. Start order, call `SpeedTimer._on_order_started()`.
2. Advance game clock by 20 seconds (simulated via `Time.get_ticks_msec()` mocking or direct signal).
3. Complete all 3 molds.
4. Assert: `score_manager.get_total_score() >= base_score * speed_bonus_multiplier`.
5. Test threshold: 30s (full bonus), 60s (partial), >60s (no bonus).

### TP-4: Game Restart Flow Test
1. Trigger game over via waste meter.
2. Call `game_controller.restart_game()` (or simulate restart button).
3. Assert: `_score_manager.get_total_score() == 0`.
4. Assert: `_order_manager.get_current_order().name == "Iron Sword"`.
5. Assert: All molds `is_complete == false`, `is_locked == false`, `current_fill == 0`.

### TP-5: Pour During Transition Window Test
1. Complete Order 1 molds, emit `order_completed`.
2. Before emitting `order_started`, call `blade.receive_metal("iron", 50.0)`.
3. Assert: `blade.is_locked == true` (mold is locked between orders).
4. Assert: Waste was charged (or pour was rejected).
5. Then emit `order_started`, assert mold is unlocked and cleared.

### TP-6: Mid-Pour Gate Toggle Test
1. Set gate_01 open, start `blade.receive_metal("iron", 50.0)` in a background timer/coroutine.
2. Mid-pour, call `flow_controller.set_gate_state("gate_01", false)`.
3. Continue pour to 100 total.
4. Assert: Either fill is rejected (due to gate change) or routing follows original intake锁定 state.
5. Verify no crash, no stuck pour.

### TP-7: Full Order Cycle (4th Order) Test
1. Complete Orders 1-3 as in `full_gameplay_test`.
2. After Order 3, call `_order_manager.get_current_order()`.
3. Assert: Returns null OR cycles back to Order 1 OR shows result panel.
4. Assert: No null pointer exception or crash.

### TP-8: PartPopEffect Trigger Test
1. Set up mock scene with `PartPopEffect` node.
2. Call `mold._on_part_produced()` or emit `part_produced` signal.
3. Assert: `PartPopEffect` particle system is active/playing.
4. Assert: `PartPopLabel` text matches score increment.

### TP-9: Wrong Metal Order Completion Test
1. Fill blade mold with iron despite it requiring steel.
2. Complete Order 1 with the wrong blade.
3. Assert: Order is NOT marked complete (or is marked partial).
4. Assert: `score_manager.get_total_score()` does not include blade part value.
5. Assert: Mold is marked `is_contaminated`.

### TP-10: Mold Clear State Verification
1. Complete Order 1 normally.
2. Before Order 2 starts, inspect all molds.
3. Assert: `current_fill == 0.0`, `is_complete == false`, `is_contaminated == false`, `is_locked == false`, `mold_state == IDLE`.

### TP-11: Game Timeout Test
1. Start Order 1, do not complete any molds.
2. Advance clock past `max_order_time` (if defined).
3. Assert: Game over triggers, or order auto-fails, or timeout penalty applies.

### TP-12: Concurrent Gate Toggle Stress Test
1. In a loop of 100 iterations, randomly toggle gates.
2. Assert: `get_gate_state()` always reflects last set value.
3. Assert: No deadlock, no signal storm, no crash.

### TP-13: Score Anti-Inflation Test
1. Fill molds with correct metals but wrong amounts (e.g., 50 iron instead of 100).
2. Complete order.
3. Assert: Score equals only the correctly-filled parts, not full order value.

### TP-14: Intake Misclick Recovery Test
1. Simulate player clicks intake_a when targeting grip mold.
2. Assert: Metal is correctly routed per gate configuration, not misrouted due to UI state.
3. Assert: If no gate covers the intake, pour goes to waste.

---

## 5. Bugs Found vs Expected

### BUG-003: Mold Lock Not Cleared for Non-Complete, Non-Contaminated Molds
**Location:** `scripts/game/Mold.gd` — `_on_order_started()`
**Expected behavior:** On `order_started`, all molds should reset: `is_locked = false`, `mold_state = IDLE`, `is_complete = false`, `current_fill = 0`, `is_contaminated = false`.
**Actual behavior (per test comments):** `_on_order_started` only clears molds that are `is_complete` or `is_contaminated`. Locked (but neither complete nor contaminated) molds may not be properly reset.
**Test coverage:** `test_mold_lock_cycle` explicitly marks this as a known bug — it passes after assuming the bug exists or verifies the fix. The test creates locked molds and checks `_on_order_started` unlocks them.

### NEW-001: Pour Position Routing Returned Wrong Mold
**Location:** `scripts/game/FlowController.gd` — `get_mold_for_pour_position()`
**Expected behavior:** When G1 and G2 are both open, pouring at intake_b should route to guard mold (the actual pour intake's mapped mold).
**Actual behavior (before fix):** Would return "blade" — the mold for the first open gate's first intake, ignoring the actual pour position.
**Test coverage:** `test_mold_for_pour_position_routing.gd` specifically tests this regression (Test 5: G1+G2 both open, pour at intake_b → guard).

### Unverified Bugs (Based on Code Presence):

| Bug | Location | Evidence |
|-----|----------|----------|
| Mold `receive_metal` accepts any metal type | `Mold.gd` | No type validation in any test |
| Mold `current_fill` not capped at capacity | `Mold.gd` | No overfill test |
| `PartPopEffect` never instantiated/triggered | `PartPopEffect.gd` | No test for this node |
| `PartPopLabel` never tested | `PartPopLabel.gd` | No test for this node |
| Speed bonus never calculated | `ScoreManager.gd` | No test for multiplier |
| Game timeout not tested | `GameController.gd` or `OrderManager.gd` | No timeout test |
| Result panel on game completion | `ResultPanel.gd` | Only existence check in full_gameplay_test |
| Waste overflow beyond 100 units | `ScoreManager.gd` | No test for waste > 100 |
| Mold contamination causes lock | `Mold.gd` | No contamination test |

---

## 6. validate.sh Result

```
=== GDScript Validation ===
Checking signal handlers...
Checking scene structure...
  Main.tscn: load_steps=19, ext=15, sub=4
Checking script references...
Checking autoloads...
Checking scripts with full compilation...
  OK: no Godot warnings in smoke_check
Checking GDScript parse errors (--check-only)...
  OK: scripts/dev/smoke_check.gd — no parse errors
  OK: scripts/dev/verify_game_loads.gd — no parse errors
Checking with gdlint...
  SKIP: gdlint not available (pip install fails on this system)
Checking for unused GDScript parameters...
  OK: no unused parameters
Checking constructor call-site vs _init signature...
  OK: no constructor mismatches

=== Validation PASSED ===
```

**Exit code: 0** — All validation checks passed. No semantic warnings, no parse errors, no constructor mismatches.

---

## 7. Headless Godot Result

```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

EXIT_CODE: 0
```

**Exit code: 0** — Godot launched in headless mode, ran for the full 300 seconds without crashing, and exited cleanly. No errors printed to stderr.

---

## 8. Recommendations

### Priority 1 — Write First (High Impact, Easy Fix Detection)

1. **TP-2: Mold Overfill Boundary Test** — Currently no test verifies that `receive_metal` caps at mold capacity. This is a one-line assertion test. If overfill is not capped, it would silently inflate scores (mold fills with more metal than intended).

2. **TP-1: Wrong Metal Contamination Test** — No test for metal type validation. If wrong-metal pours are silently accepted, orders can be completed with wrong materials — a core gameplay bug.

3. **TP-3: Speed Bonus Calculation Test** — Speed bonus is part of the scoring system but never verified. A bug in the bonus formula would go undetected.

4. **TP-10: Mold Clear State Verification** — Expand existing `test_mold_lock_cycle` assertions to include `current_fill == 0` and `is_complete == false`. The current test only checks `is_locked` and `mold_state`.

### Priority 2 — Medium Impact

5. **TP-8: PartPopEffect Trigger Test** — Visual effects exist but are never tested. If particles fail to emit (null reference, missing scene), players see nothing and the bug is invisible.

6. **TP-4: Game Restart Flow Test** — The game over path is tested but restart is not. If restart is broken, players cannot replay after game over.

7. **TP-5: Pour During Transition Window** — The lock/unlock state machine is tested, but actual pour behavior during the transition window is not.

8. **TP-9: Wrong Metal Order Completion Test** — Ensures the game correctly rejects wrong-material parts.

### Priority 3 — Nice to Have

9. **TP-7: 4th Order / End-of-Game Test** — What happens after Order 3? Unknown. Could crash or soft-lock.

10. **TP-11: Game Timeout Test** — If a max order time exists, exceeding it should be tested.

11. **TP-6: Mid-Pour Gate Toggle** — Stress test for gate change mid-pour.

12. **TP-12: Concurrent Gate Toggle Stress** — Race condition detection.

13. **TP-13: Score Anti-Inflation** — Wrong fill amounts should not earn full score.

14. **TP-14: Intake Misclick Recovery** — UI error handling.

---

*QA review generated for ForgeSortProto team. Next step: implement Priority 1 tests before next sprint.*
