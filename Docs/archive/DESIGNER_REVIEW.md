# ForgeSortProto — Game Design Review

**Reviewer:** Designer (Subagent)
**Date:** 2026-04-29
**Files Analyzed:** scripts/game/{GameController,OrderManager,ScoreManager,MetalFlow,FlowController,Mold,PourZone,Gate}.gd, scenes/Main.tscn, design docs
**Repo:** local/ForgeSortProto-0f1b469d

---

## Mental Play-Through (Annotated)

1. **Game Start** → StartButton pressed → `_on_start_pressed()` at GameController.gd:34 → `_reset_game()` + `flow_controller.reset_all_gates()` + `order_manager.start_game()`
2. **First Order** → `OrderManager.start_next_order()` at OrderManager.gd:24 → `order_started.emit(current_order)` → `GameController._on_order_started()` at GameController.gd:56 → `_update_mold_requirements_for_order()` → `_reset_mold()` → `mold.clear_mold()` + `mold.required_metal = required_metal`
3. **Select Metal** → Player picks iron/steel/gold → `metal_source.metal_selected` fires
4. **First Pour** → Mouse down in pour zone → `_start_pour()` at PourZone.gd:179 → `metal_flow.set_active_stream(self)` → `_process()` accumulates pour → `_route_pour()` at MetalFlow.gd:58 → `flow_controller.get_mold_for_pour_position()` → gate routing checked → mold `receive_metal()` called
5. **Mold Fill** → Mold state FILLING → fill bar animates → mold sprite glows
6. **Order Complete** → All parts done → `order_completed.emit()` → `start_next_order()` advances index
7. **Next Order** → New `OrderDefinition` loaded → `_on_order_started()` resets molds → cycle repeats

---

## 1. New Player Experience

**Rating: POOR**

### Findings

1. **No tutorial or onboarding.**
   - There is zero introductory guidance. A new player sees the main scene with molds, gates, and a pour zone but has no labels, tooltips, or first-order scaffolding explaining what to do. The game drops the player directly into the full loop with no "first order is always iron/iron/iron" buffer.
   - File: `scripts/game/GameController.gd` — `_on_start_pressed()` (line 34) just hides the button and starts the game. No `show_tutorial()` call exists anywhere.

2. **Locked molds appear broken at game start.**
   - `Mold._update_display()` at Mold.gd:266 sets `state_label.text = "Locked"` with `Color.DIM_GRAY` for `is_locked = true`. On the very first frame before `order_started` fires, all molds show as locked. A new player clicking a mold sees "Locked" with no explanation.
   - File: `scripts/game/Mold.gd` — `is_locked` starts as `true` (line 37), and `_update_display()` at line 266 renders this immediately in `_ready()`.

3. **No indication which metal is currently selected.**
   - The `MetalSource` node tracks selected metal but there is no visible UI indicator (highlighted button, cursor tint, label near the pour cursor) showing the player what metal is active before they pour. The molten stream color changes mid-pour (`_on_metal_selected()` at PourZone.gd:265) but by then the player has already committed.
   - File: `scripts/game/PourZone.gd` — `_on_metal_selected()` (line 265) only updates stream color, no UI label.

4. **Gate/intake routing is opaque.**
   - The gate routing logic in `FlowController._gate_routing_mold_id()` (FlowController.gd:93) uses a priority-ordered dictionary (`GATE_ROUTING` at line 24) but the player has no visual indication of which gates cover which intakes. Gates toggle green when open (Gate.gd:56) but the connection between a specific gate and a specific mold/intake is never labelled or indicated on-screen.
   - File: `scripts/game/FlowController.gd` — `GATE_ROUTING` constant (line 24) defines gate→intake mapping with no UI counterpart.

5. **Order contents are not clearly communicated.**
   - `OrderManager` emits `order_started(order: OrderDefinition)` but the UI that consumes this signal is not visible in the reviewed scripts. The player must infer what parts are needed from mold label colors or trial-and-error pours. There is no on-screen "Order 1: blade-iron, guard-iron, grip-iron" checklist visible at game start.
   - File: `scripts/game/OrderManager.gd` — `start_next_order()` at line 24 emits the order but no UI script in the reviewed set shows a corresponding handler that renders the order to screen.

---

## 2. Core Loop Feedback

**Rating: MEDIUM**

### Findings

1. **Pour stream visual is present but feels thin.**
   - `PourZone._update_stream_visuals()` at PourZone.gd:141 draws a `Line2D` from `top_y=0` to `pour_origin`. The stream width ranges 8–12px depending on metal (`_current_stream_width` at PourZone.gd:46, driven by `metal_def.spread` at PourZone.gd:113). The artist audit noted a glow shader is missing, making the stream "flat and hard to track."
   - File: `scripts/game/PourZone.gd` — `_update_stream_visuals()` line 141, `_apply_metal_properties()` line 106.

2. **Mold fill glow is too subtle.**
   - `_update_fill_glow()` at Mold.gd:302 modulates `modulate.v` only. The artist audit specifically flagged this: "Use a dedicated glow `ColorRect` behind the mold sprite instead of modulating the sprite itself."
   - File: `scripts/game/Mold.gd` — `_update_fill_glow()` line 302, `_create_receiving_glow()` line 379 (only called on receive, not maintained during fill).

3. **Gate toggle PointLight2D pops in/out rather than fading.**
   - `_update_visual()` at Gate.gd:52 adds/removes `PointLight2D` with no fade transition. `modulate` fades on the `ColorRect` but the light itself appears instantly at full energy.
   - File: `scripts/game/Gate.gd` — `_update_visual()` line 52, light addition at Gate.gd:65.

4. **Hardening state has good animation but no audio cue.**
   - The hardening sequence (Mold.gd:200–210) runs a chained tween: WHITE flash → desaturate → darken → scale shrink. This is the best visual feedback in the game. However the production roadmap explicitly marks the audio layer as missing (`PRODUCTION_ROADMAP.md::Issue 5 — Missing Audio Layer`).
   - File: `scripts/game/Mold.gd` — `_animate_hardening()` line 200.

5. **Waste routing rejection feedback is present.**
   - `_trigger_rejection_effect()` at PourZone.gd:285 creates an orange flash+scale animation when metal is routed to waste. This is good impulse feedback for a wrong pour.
   - File: `scripts/game/PourZone.gd` — `_trigger_rejection_effect()` line 285.

---

## 3. Progression & Reward Feel

**Rating: MEDIUM**

### Findings

1. **Speed bonus is binary and opaque.**
   - `ScoreManager.calculate_order_score()` at ScoreManager.gd:52 awards a flat `+50 SPEED_BONUS` if `elapsed < 30.0` seconds. There is no progress bar or countdown toward the threshold — the player never knows they're on track for the bonus until the order completes and the score flashes.
   - File: `scripts/game/ScoreManager.gd` — `calculate_order_score()` line 52, `SPEED_THRESHOLD_SECONDS` constant line 16.

2. **Waste meter is reactive but harsh.**
   - `ScoreManager.add_waste()` at ScoreManager.gd:34 applies `WASTE_PENALTY_PER_UNIT = 1.0` per waste unit with `WASTE_METER_MAX = 100.0`. A single bad pour can consume 10–20% of the meter instantly. The penalty accumulates continuously (no decay), and at 100% the game ends immediately (`game_over.emit` at ScoreManager.gd:39). This creates high stakes but low recovery options.
   - File: `scripts/game/ScoreManager.gd` — `add_waste()` line 34, `WASTE_METER_MAX` line 17.

3. **Contamination penalty is steep.**
   - `ScoreManager.add_contamination()` at ScoreManager.gd:43 deducts a flat `CONTAMINATION_PENALTY = 25` points per contamination event, independent of amount. A single wrong-metal pour into a near-full mold costs both contamination (-25) and waste (-amount). The `_trigger_contamination()` at Mold.gd:163 also prints debug statements to console.
   - File: `scripts/game/Mold.gd` — `_trigger_contamination()` line 163, debug prints at Mold.gd:164–165.

4. **No visual reward for completing an order.**
   - `OrderManager.complete_part()` at OrderManager.gd:42 emits `order_completed` and immediately starts `start_next_order()` at line 44. There is no celebration moment, score popup, or pause between orders. The Mold's `part_pop_effect` (Mold.gd:217) fires on `_produce_part()` but there's no equivalent for the order-level completion.
   - File: `scripts/game/OrderManager.gd` — `complete_part()` line 42, `start_next_order()` line 44.

5. **Progression is flat — no difficulty curve signal.**
   - All orders are drawn from `game_data.orders` (OrderManager.gd:25) with no modification. A player who clears order 1 gets order 2 at the same gate configuration difficulty. There is no visible "wave number" or "stage" escalation.
   - File: `scripts/game/OrderManager.gd` — `start_next_order()` line 24, `game_data.orders` at line 25.

---

## 4. UI Clarity

**Rating: MEDIUM**

### Findings

1. **No in-game HUD for score or waste.**
   - `ScoreManager` emits `score_updated` and `waste_updated` signals, but no reviewed script implements a HUD that consumes them. The `result_panel` only shows on `game_over` or `game_completed`. During play, the player has no persistent score or waste readout.
   - File: `scripts/game/ScoreManager.gd` — signals at lines 3–5, emitting calls at lines 35, 36, 44, 54.

2. **Order checklist is not visible during play.**
   - `OrderManager.completed_parts_changed` fires on every part completion (OrderManager.gd:43) but there is no UI element mapped to this. The design doc lists "Order checklist updates instantly" as required feedback, but the implementation is missing from reviewed scripts.
   - File: `scripts/game/OrderManager.gd` — `completed_parts_changed` signal at line 5, emission at line 43.

3. **Mold state labels are functional but rough.**
   - `_update_display()` at Mold.gd:260 sets `state_label.text` to: `"Cooling..."` (ORANGE), `"Done!"` (GREEN), `"Tap to Clear"` (RED), `"Locked"` (DIM_GRAY), `%.0f%%` (YELLOW), or `required_metal.capitalize()` (WHITE). These are informative but visually unpolished — plain `Label` with no background, positioned over the mold. No consideration for localization or accessibility contrast.
   - File: `scripts/game/Mold.gd` — `_update_display()` line 260.

4. **Escape key quits without confirmation.**
   - `_input()` at GameController.gd:117 calls `get_tree().quit()` immediately on KEY_ESCAPE. No confirmation dialog. This is fine for a prototype but should be flagged.
   - File: `scripts/game/GameController.gd` — `_input()` line 117.

5. **Space bar is an undocumented shortcut.**
   - `_input()` at GameController.gd:119 starts the game when Space is pressed and `start_button.visible`. This is convenient but never communicated to the player.
   - File: `scripts/game/GameController.gd` — Space handler at line 119.

---

## 5. Top 5 Priority Issues (Ranked, Fixable)

### 1. Missing Order Checklist UI
**File:** `scripts/game/OrderManager.gd:43` + new UI script
**Problem:** `completed_parts_changed` fires but nothing renders it. Player cannot see order progress without guesswork.
**Fix:** Create an `OrderUI` node with three part slots (blade/guard/grip). Subscribe to `completed_parts_changed` and mark slots complete with a checkmark or fill. Position it at top of screen.

### 2. Mold Fill Glow Too Subtle
**File:** `scripts/game/Mold.gd:302` (`_update_fill_glow()`)
**Problem:** Modulating `modulate.v` does not create a perceptible glow. Artist audit flagged this explicitly.
**Fix:** Add a dedicated `ColorRect` behind the mold sprite (`z_index = -1`), sized 1.2x the mold, with `Color(metal_color * 0.3)` and `modulate.a` pulsed. Leave `_update_fill_glow()` to animate that node instead of `modulate.v`.

### 3. Debug Prints in Contamination Path
**File:** `scripts/game/Mold.gd:164–165`
**Problem:** `[MOLD] _trigger_contamination INCOMING: wrong_metal=` and contamination count are printed every wrong-metal pour. This is a shipped-prototype code smell and floods the console during normal play.
**Fix:** Remove or guard with `if OS.is_debug_build()`.

### 4. No Tutorial / First-Order Scaffolding
**File:** `scripts/game/GameController.gd:34` (`_on_start_pressed()`)
**Problem:** Player is thrown into the full game with no guidance. A tutorial order (always iron-iron-iron, with an arrow pointing to the pour zone) would dramatically improve Day-1 retention.
**Fix:** Add a `_tutorial_mode` flag. On first start, show a semi-transparent overlay with three steps: "1. Select Iron | 2. Hold and pour into the mold | 3. Fill all three molds." Dismiss on completion of first order.

### 5. Gate Light Pops Instead of Fading
**File:** `scripts/game/Gate.gd:65–68`
**Problem:** `PointLight2D` is `add_child()`ed at full energy instantly on gate open, and `queue_free()`d on close. No fade.
**Fix:** Pre-create the light node in `_ready()` with `visible = false`, then on open: `light.visible = true` + `tween_property(light, "energy", 0.6, 0.2)`. On close: `tween_property(light, "energy", 0.0, 0.15)` then `set("visible", false)` in callback.

---

## 6. Top 5 Strengths

1. **Hardening animation is excellent.**
   - `_animate_hardening()` at Mold.gd:200 is a 0.8-second chained tween (WHITE → desaturate → darken → scale shrink) that communicates the physics of cooling metal clearly and satisfyingly. This is the best "game feel" moment in the prototype.

2. **Metal-specific stream properties create meaningful choice.**
   - `_apply_metal_properties()` at PourZone.gd:106 drives `_current_stream_width` and `_current_particle_interval` from `metal_def.speed` and `metal_def.spread`. Iron pours slow/narrow, gold pours fast/wide. This makes metal selection a real tactical decision, not just a color picker.

3. **Gate routing puzzle is well-designed.**
   - `GATE_ROUTING` at FlowController.gd:24 is non-trivial: G3 covers A+C (not all 3), requiring G1/G2/G4 combos for full coverage. The code comment explicitly notes this was a deliberate fix to prevent trivial routing on Order 1. This creates genuine puzzle depth.

4. **Mold state machine is thorough and correct.**
   - Mold.gd implements 6 states (IDLE, FILLING, COMPLETE, HARDENING, CONTAMINATED, LOCKED) with proper transitions. `clear_mold()` cancels hardening timers, `receive_metal()` guards every edge case (locked, hardening, overfill, wrong metal). This is solid engineering that enables clean game feel.

5. **Accumulative pour with accumulator flush on gate toggle is robust.**
   - `MetalFlow._process()` at MetalFlow.gd:20 accumulates pour in real units with `floor()` chunking. `_on_gate_toggled()` at PourZone.gd:257 calls `flush_accumulator()` to prevent silent metal loss mid-pour. This is the correct way to handle discrete simulation with continuous input.

---

## 7. Summary Table

| Category | Rating | Priority | Notes |
|---|---|---|---|
| New Player Experience | POOR | CRITICAL | No tutorial, locked molds at start, opaque routing, no selected-metal indicator |
| Core Loop Feedback | MEDIUM | HIGH | Good hardening animation, thin stream glow, pop-in gate light, no audio |
| Progression & Reward | MEDIUM | HIGH | Binary speed bonus, harsh waste penalties, no order celebration, flat difficulty |
| UI Clarity | MEDIUM | HIGH | No HUD during play, missing order checklist, rough mold labels, Space shortcut undocumented |
| Top Issue 1 | — | CRITICAL | Missing order checklist UI |
| Top Issue 2 | — | HIGH | Mold fill glow too subtle (artist audit confirmed) |
| Top Issue 3 | — | MEDIUM | Debug prints in contamination path |
| Top Issue 4 | — | HIGH | No tutorial / first-order scaffolding |
| Top Issue 5 | — | MEDIUM | Gate PointLight2D pops instead of fading |
| Top Strength 1 | — | — | Hardening animation is excellent |
| Top Strength 2 | — | — | Metal-specific stream properties |
| Top Strength 3 | — | — | Gate routing puzzle depth |
| Top Strength 4 | — | — | Mold state machine correctness |
| Top Strength 5 | — | — | Accumulative pour with flush on gate toggle |

---

*Review compiled from source analysis of 8 GDScript files (1,232 lines total) and design documentation via jcodemunch/jdocmunch MCP tools.*
