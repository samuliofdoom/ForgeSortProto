# Forge Sort Prototype — Concise Design Doc

## Purpose
Build a one-screen mobile prototype in Godot to test the core forge loop:

> Hold, sweep, pour, route, fill molds, complete orders.

The prototype exists to answer one question: **is sweeping molten metal into routing intakes fun and readable for repeated play?**

## Core Fantasy
The player is a forge-master controlling molten metal with precision. Clean routing creates weapon parts. Bad routing causes waste or contamination.

## Player Verbs
- **Select** metal
- **Hold** to pour
- **Sweep** finger left/right to move the pour stream
- **Toggle** gates
- **Route** metal into molds
- **Fill** molds
- **Clear** contaminated molds
- **Complete** orders

## Core Loop
1. Order appears.
2. Player selects a metal.
3. Player holds in the top pour zone.
4. Player sweeps left/right to spread metal into intake funnels.
5. Gates route metal toward molds.
6. Correct molds fill and produce parts.
7. Parts auto-complete the order.
8. Player scores profit.
9. Next order begins.

Loop shorthand:

> Order → Select Metal → Hold/Sweep Pour → Route → Fill → Produce Part → Complete Order → Score

## Screen Layout
Vertical mobile layout.

### Top: Pour Zone
- Touch/hold inside zone starts pouring.
- Finger slides left/right to move pour origin.
- Release stops pouring.
- Current selected metal determines the stream type.

### Middle: Routing Field
- 3 intake funnels receive poured metal.
- 4–6 tap gates redirect flow.
- Routing should matter; the player must not be able to pour directly into final molds.

### Bottom: Molds + Order Panel
- 3 molds: Blade, Guard, Grip.
- Each mold displays required metal, fill progress, contamination, and completion.
- Order checklist shows required parts.

## Metals
| Metal | Behavior | Purpose |
|---|---|---|
| Iron | Slow, forgiving, medium spread | Basic control |
| Steel | Faster, narrower stream | Timing pressure |
| Gold | Fast, narrow, high penalty if wasted | Precision challenge |

## Molds
Each mold has:
- Part type: Blade / Guard / Grip
- Required metal
- Fill amount
- Current fill
- State: empty / filling / complete / contaminated

Correct metal fills the mold. Wrong metal contaminates it. Overfill creates waste.

## Orders
Use 3 fixed orders.

### 1. Iron Sword
- Iron Blade
- Iron Guard
- Iron Grip

### 2. Steel Sword
- Steel Blade
- Iron Guard
- Iron Grip

### 3. Noble Sword
- Steel Blade
- Gold Guard
- Iron Grip

No randomization for the prototype.

## Failure Rules
Soft failure only.

- Wrong metal in mold → contamination
- Completed mold receiving more metal → waste
- Too much waste → lower score
- Contaminated mold must be cleared before reuse

Optional hard fail: waste meter reaches 100%.

## Scoring
Simple profit formula:

```text
Base order value
- waste penalty
- contamination penalty
+ speed bonus
= final profit
```

Suggested values:
- Iron Sword: 100
- Steel Sword: 160
- Noble Sword: 250
- Waste penalty: -1 per wasted unit
- Contamination penalty: -25
- Speed bonus: +50

## Required Feedback
Minimum readable feedback:
- Visible pour stream following finger X position
- Liquid enters intakes clearly
- Gates visibly toggle
- Correct mold glows/fills
- Wrong mold flashes red
- Completed mold cools/hardens
- Part pops out
- Order checklist updates instantly
- Waste meter reacts immediately

## Godot Scene Structure
```text
Main.tscn
├── GameController
├── UI
│   ├── MetalSelector
│   ├── PourZone
│   ├── OrderPanel
│   ├── WasteMeter
│   └── ResultPanel
├── RoutingField
│   ├── PourNozzle
│   ├── Intake_A
│   ├── Intake_B
│   ├── Intake_C
│   ├── Gate_01
│   ├── Gate_02
│   ├── Gate_03
│   └── Gate_04
└── MoldArea
    ├── BladeMold
    ├── GuardMold
    └── GripMold
```

## Suggested Scripts
```text
GameController.gd
OrderManager.gd
PourZone.gd
MetalSource.gd
FlowController.gd
Gate.gd
Mold.gd
OrderPanel.gd
ScoreManager.gd
```

## Input Responsibilities
```text
PourZone = touch/mouse input
MetalSource = spawns selected metal stream
FlowController = routes metal through intakes/gates
Mold = receives metal and resolves fill/contamination
OrderManager = tracks required parts
```

## AI Coding Agent Task Breakdown

### Task 1 — Data + Orders
Implement metal definitions, mold definitions, and 3 fixed orders.

### Task 2 — Pour Input
Implement hold-to-pour and horizontal sweep control in the top pour zone.

### Task 3 — Routing
Implement 3 intakes and 4–6 gates that redirect flow to molds.

### Task 4 — Mold Logic
Implement correct fill, contamination, overfill waste, completion, and clearing.

### Task 5 — Order Completion
Auto-complete parts into orders, advance through all 3 orders, then show results.

### Task 6 — Feedback Pass
Add basic animation, fill bars, flashes, sounds, and clear state changes.

## Explicit Non-Goals
Do not build:
- Adventuring
- Idle combat
- Inventory grid
- Armor
- Random customers
- Upgrade shop
- Damascus / metal mixing
- Temperature systems
- Procedural levels
- Complex economy

## Success Criteria
Continue only if:
1. The goal is understood within 10 seconds.
2. Sweeping the pour feels good for 30 seconds.
3. The player makes meaningful routing decisions.
4. Mistakes are obvious and recoverable.
5. The player wants to replay to reduce waste or improve time.

If this fails, fix the pour/routing loop before adding RPG systems.
