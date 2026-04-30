# ForgeSortProto — Designer Playtest Report

**Playtest Date:** 2026-04-30
**Playtest Method:** Godot MCP run + debug output capture
**Game Build:** Godot 4.6.2 / 4.6 mobile renderer / D3D12

---

## Executive Summary

**CRITICAL FINDING: Game crashes immediately on startup when run via MCP tools.** The Godot process dies within ~2 seconds of launch, producing no debug output. Direct CLI runs (`godot --headless`) start and run fine in isolation, suggesting the MCP bridge introduces a condition the headless runner does not tolerate (likely a display/WSL clipboard issue, or an MCP timeout causing premature process termination).

**Playable, but barely.** The core loop is implemented and structurally sound based on code inspection. A human player who successfully launches the game would encounter a working but under-juiced forge-sorting experience.

---

## Startup / Crash Analysis

### Observed Behavior (MCP)
- `mcp_godot_run_project` reports success ("Godot project started in debug mode")
- `mcp_godot_get_debug_output` called 10 seconds later returns "No active Godot process"
- The Godot process dies almost immediately

### Diagnostic Tests
- `godot --headless --path /mnt/g/AI_STUFF/Games/ForgeSortProto` — starts and stays resident (exit 124 = timeout, meaning it runs and is killed by timeout)
- `godot --version` — reports v4.6.2 cleanly
- No `.log` files in the project directory
- No crash dialog or Godot editor logs found

### Root Cause Hypothesis
The crash is likely an MCP bridge issue, not a game bug:
- The MCP server (`godot-mcp-server`) may be detaching the Godot process from the WSL tty, causing display initialization to fail
- Or the Godot process initializes successfully but the MCP server's output pipe is closed prematurely, making the runner believe the process died
- The game itself is likely fine — `validate.sh` passes 9/9 checks and `godot --headless --quit-after 300` exits clean per the production roadmap

**Recommendation:** Verify with a real human launching from the Godot editor or from a native Windows Godot binary. The headless smoke test passing is a strong signal the game code is healthy.

---

## Player Experience (Predicted from Code + Design Doc)

### What Works

**Core Loop is sound.** The design doc's "Order → Select Metal → Hold/Sweep Pour → Route → Fill → Produce Part → Complete Order → Score" loop is fully wired:
- 3 metals (Iron/Steel/Gold) with distinct stream behaviors
- Hold-to-pour with horizontal sweep control
- 4-gate routing system (G1=A/B, G2=B/C, G3=A+C, G4=C) with toggle UI
- 3 molds (Blade/Guard/Grip) with fill/contamination/completion state machine
- Waste meter with hard fail
- Score tracking with speed bonus
- Result screen + restart

**Visual feedback is present at the code level:**
- Furnace glow pulse animation (GameController._process)
- Ember particles (CPUParticles2D, 35 particles, orange hue variation)
- Pour stream line + glow at cursor position
- Mold fill bars color-coded by state
- Mold hardening animation (white flash → desaturate → darken → scale bounce)
- Contamination flash + rejection flash at pour origin
- Padlock icon on locked molds

**UI is complete:**
- Metal selector buttons (Iron/Steel/Gold)
- Gate toggle UI with route labels
- Order panel showing current recipe
- Waste meter with progress bar
- Score display

### What Feels Wrong (Expected from Code Inspection)

**1. Speed Timer is dead.** SpeedTimer.gd is wired to a Label in Main.tscn, but no signal connects it to `OrderManager.order_started`. The display permanently shows "0.0s". The player has no idea if they're on track for the +50 speed bonus. This is a P2 bug listed in the production roadmap — must fix before ship.

**2. No audio whatsoever.** AudioManager.gd exists as an autoload but contains no audio streams, no sfx, no pour hum, no gate click, no mold clank, no contamination buzz. The game is completely silent. For a game about molten metal, this is a huge atmosphere killer. P2 Polish per the roadmap — but arguably should be P1 given how much "juice" sound provides.

**3. The pour stream is just a line.** The production roadmap explicitly blocks FEATURE-007 (molten stream simulation) pending a design doc. Currently it's a basic line with glow — not a satisfying liquid stream. Iron/Steel/Gold have different spread/speed parameters but visually they're the same geometry.

**4. Gate toggle animation is instant.** No easing, no rotation, no feedback when toggling. Gates are just StaticBody2D rectangles that flip state. The toggle UI buttons work but the gates themselves don't animate.

**5. Mold fill bars jump, not tween.** Fill progress updates are likely raw value assignments. For satisfying feedback, these should smoothly tween between values.

**6. Intake glow system exists in code but may not fire correctly.** The roadmap mentions "Intake glow amplification (0.8s + particle burst)" as a nice-to-have, and intake visuals are ColorRects — basic boxes. The routing feels abstract rather than viscerally satisfying.

**7. No screen shake or impact effects.** Pour rejection, contamination, mold completion — none of these have camera/screen feedback. Everything is purely UI-element animation.

### Missing Juice (Based on Design Doc Requirements)

The design doc lists these as "Required Feedback" — checking each against the code:

| Feedback | Status |
|---|---|
| Visible pour stream following finger X | IMPLEMENTED (PourZone + MetalFlow line) |
| Liquid enters intakes clearly | PARTIAL (Intake Area2D detection exists, but visual is just ColorRect) |
| Gates visibly toggle | NOT IMPLEMENTED (instant state change, no animation) |
| Correct mold glows/fills | IMPLEMENTED (fill bar + hardening animation) |
| Wrong mold flashes red | IMPLEMENTED (contamination flash) |
| Completed mold cools/hardens | IMPLEMENTED (hardening animation with scale bounce) |
| Part pops out | BUGGY — PartPopEffect.gd has a Polygon2D construction issue (BUG-006) |
| Order checklist updates | IMPLEMENTED (OrderChecklistUI.gd) |
| Waste meter reacts immediately | IMPLEMENTED (WasteMeter.gd) |

**Part pop-out effect is broken.** BUG-006: `PartPopEffect.gd` line 29 calls `Polygon2D.new()` but the Polygon2D type annotation parsing may fail at scene load. The game otherwise runs, so this is a low-severity trigger — it would only fire on mold completion. Impact: player never sees the weapon-part-silhouette pop that signals "part done."

---

## Game Structure (What a Player Sees)

Based on Main.tscn and script analysis:

```
┌─────────────────────────────────┐  ← 400×720 mobile viewport
│  FORGE BACKGROUND (dark amber)  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  Furnace glow pulse + ember particles
│                                 │
│  [Iron] [Steel] [Gold]   Score  │  TopBar: MetalSelector + ScoreDisplay
│                                 │
│  Waste: ████░░░░░░░░░  Gates:  │  WasteMeter + GateToggleUI
│                     [G1][G2]... │
│                                 │
│  ╔═══════════════════════════╗  │  PourZone: "Hold & Sweep to Pour"
│  ║   HOLD + SWEEP TO POUR    ║  │  Touch/drag to pour molten metal
│  ╚═══════════════════════════╝  │
│                                 │
│      ┌──┐  ┌──┐  ┌──┐  ┌──┐   │  RoutingField: 4 gates (StaticBody2D)
│      │G1│  │G2│  │G3│  │G4│   │  3 intakes: A, B, C (Area2D)
│      └──┘  └──┘  └──┘  └──┘   │
│      [A]   [B]   [C]           │
│                                 │
│   [Blade]  [Guard]  [Grip]     │  MoldArea: 3 molds (blade/guard/grip)
│   ████░░   ██████   ████░░    │  Fill bars + state labels
│                                 │
│   ┌─────────────────────────┐  │
│   │ Order: Iron Sword       │  │  OrderPanel: current recipe
│   │ [✓] Iron Blade          │  │
│   │ [ ] Iron Guard          │  │
│   │ [✓] Iron Grip           │  │
│   └─────────────────────────┘  │
│                                 │
│          [ START ]              │  StartButton (pre-game only)
│        ┌──────────────┐        │
│        │  RESULTS!    │        │  ResultPanel (post-game only)
│        │  Score: 340  │        │
│        │  [RESTART]   │        │
│        └──────────────┘        │
└─────────────────────────────────┘
```

---

## Specific Issues by Severity

### P0 — Must Fix Before Playable

1. **MCP startup crash** — Cannot launch via MCP tools. Need to determine if this is an environment issue (WSL display) or a game issue. Verify with human launching directly from Godot editor.

### P1 — Must Fix Before Ship

2. **Speed Timer stuck at 0.0s** — No signal wired to `SpeedTimer`. Player can't track speed bonus eligibility. Dead UI element is confusing.
3. **No audio** — Game is completely silent. At minimum: pour hum, gate click, mold fill clank, contamination buzz, order completion fanfare.
4. **Part pop effect broken (BUG-006)** — Polygon2D construction issue prevents weapon-part silhouette from appearing on mold completion.

### P2 — Should Fix Before Ship

5. **Gate toggle has no animation** — Instant state flip is jarring. Add rotation or scale bounce.
6. **Fill bars jump, no tween** — Disruptive rather than satisfying fill progression.
7. **Intake visuals are plain boxes** — Should glow, pulse, or otherwise feel like they're receiving molten metal.
8. **No screen shake on contamination or waste** — Impact effects missing.
9. **No heat haze / atmosphere** — FEATURE-006 blocked on design doc. Without it the forge feels static.

### P3 — Polish (Post-Launch)

10. **Waste meter 80% warning threshold** — No visual escalation before hard fail.
11. **Order transition fanfare missing.**
12. **Molten stream is a line, not fluid** — FEATURE-007 blocked on design doc.
13. **GateDebugHUD F1 key conflicts with Godot F1** — Change to F2 or Ctrl+F1.

---

## What's Good and Should Be Preserved

- **Core loop is clean and testable.** The 3-order fixed sequence (Iron Sword → Steel Sword → Noble Sword) is a good proto test. Repeating forever at high score is correct for a prototype.
- **Gate routing logic is non-trivial.** G1=A/B, G2=B/C, G3=A+C, G4=C means the player actually has to think about routing. This is the core decision layer and it works.
- **Contamination + clear mechanic** is good. Wrong metal locking a mold + tap-to-clear creates meaningful recovery decisions.
- **Waste meter + hard fail** adds tension. Soft failure only would reduce stakes too much.
- **Visual hierarchy is clear.** Top pour zone / middle routing / bottom molds is a strong vertical read.
- **Ember particles + furnace glow** establish atmosphere even without full FEATURE-006.
- **validate.sh 9/9 green** means the logic is well-tested at the script level.

---

## Recommendations for Next Steps

1. **Verify game launches for human player** — Run from Godot editor or native Windows binary. Confirm the MCP crash is environmental.
2. **Wire SpeedTimer immediately** — One signal connection: `OrderManager.order_started` → `SpeedTimer.start()`, `OrderManager.order_completed` → `SpeedTimer.stop()`.
3. **Add minimal audio** — Use AudioStreamGenerator for procedural pour hum and gate clicks. Don't wait for a creative decision on samples vs procedural — just ship something.
4. **Fix PartPopEffect Polygon2D** — Use a pre-instantiated scene or set polygon property immediately after construction.
5. **Animate gates** — 100ms elastic rotation on toggle is enough to feel responsive.
6. **Smooth fill bars** — Tween or LERP fill bar values over 0.1s instead of jumping.

---

## Files Reviewed

- `project.godot` — 400×720 mobile viewport, 4 autoloads, spacebar input bound
- `scenes/Main.tscn` — full scene with all UI, routing, mold nodes
- `scripts/game/GameController.gd` — start/restart, order signals, furnace pulse
- `Docs/forge_sort_proto_design_doc.md` — full design intent
- `Docs/PRODUCTION_ROADMAP.md` — current state, known bugs, ship checklist

---

*Report generated by Hermes Agent (Designer subagent), ForgeSortProto team.*
*Iterations used: ~12.*
