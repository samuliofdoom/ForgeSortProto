# ForgeSortProto — Coder Review

**Audit Date:** 2026-04-29
**Scripts Audited:** 11 game scripts (scripts/game/*.gd)
**Repo:** ForgeSortProto (local index, jcodemunch)
**Godot Version:** 4.6.2

---

## 1. Signal Wiring Audit

| Signal | Emitted By | Connected By | File:Line | Status |
|---|---|---|---|---|
| `gate_toggled(gate_id, state)` | FlowController.gd:49,53,116 | Gate.gd:33 (CONNECT_ONE_SHOT) | FlowController.gd | OK |
| `gate_toggled(gate_id, is_open)` | Gate.gd:79 (gate_interacted, not gate_toggled) | PourZone.gd:41 | Gate.gd:79 | NOTE-1 |
| `flow_routed` | FlowController.gd:100 | Intake.gd:69 | FlowController.gd | OK |
| `metal_received` | Intake.gd:56 | — (UNCONNECTED) | Intake.gd | WARN |
| `metal_poured` | MetalFlow.gd:63 | — (UNCONNECTED) | MetalFlow.gd | WARN |
| `waste_routed` | MetalFlow.gd:81 | PourZone.gd:43 | MetalFlow.gd | OK |
| `order_completed` | OrderManager.gd:53 | GameController.gd:22 | OrderManager.gd | OK |
| `order_started` | OrderManager.gd:38 | GameController.gd:21 | OrderManager.gd | OK |
| `game_completed` | OrderManager.gd:30 | GameController.gd:20 | OrderManager.gd | OK |
| `game_over` | ScoreManager.gd:61 | GameController.gd:25 | ScoreManager.gd | OK |
| `pour_started` | PourZone.gd:201 | — (UNCONNECTED) | PourZone.gd | WARN |
| `pour_ended` | PourZone.gd:215 | — (UNCONNECTED) | PourZone.gd | WARN |
| `pour_position_changed` | PourZone.gd:210 | — (UNCONNECTED) | PourZone.gd | WARN |
| `metal_selected` | MetalSource.gd:15 | PourZone.gd:70 | MetalSource.gd | OK |
| `pour_state_changed` | MetalSource.gd:26,31 | — (UNCONNECTED) | MetalSource.gd | WARN |
| `part_produced` | Mold.gd:168 | — (UNCONNECTED in game) | Mold.gd | WARN |
| `mold_completed` | Mold.gd:145 | — (UNCONNECTED in game) | Mold.gd | WARN |
| `mold_filled` | Mold.gd:113 | — (UNCONNECTED) | Mold.gd | WARN |
| `mold_contaminated` | Mold.gd:135 | — (UNCONNECTED) | Mold.gd | WARN |
| `mold_cleared` | Mold.gd:182 | — (UNCONNECTED) | Mold.gd | WARN |
| `mold_tapped` | Mold.gd:79 | — (UNCONNECTED) | Mold.gd | WARN |
| `score_updated` | ScoreManager.gd:29,51,57,67 | — (UNCONNECTED) | ScoreManager.gd | WARN |
| `waste_updated` | ScoreManager.gd:48 | — (UNCONNECTED) | ScoreManager.gd | WARN |
| `contamination_penalty` | ScoreManager.gd:55 | — (UNCONNECTED) | ScoreManager.gd | WARN |

**NOTE-1:** Gate.gd:79 emits `gate_interacted`, not `gate_toggled`. PourZone listens to FlowController's `gate_toggled`, which is correct.

---

## 2. Null-Safety Issues

| File:Line | Issue | Severity |
|---|---|---|
| GameController.gd:13-16 | `get_node("/root/OrderManager")`, `get_node("/root/MetalFlow")`, `get_node("/root/ScoreManager")`, `get_node("/root/FlowController")` — all bare `get_node()` without null checks. Will crash if any root node is missing. | HIGH |
| MetalSource.gd:11 | `get_node("/root/GameData")` — bare get_node, no null check | HIGH |
| OrderManager.gd:15-16 | `get_node("/root/GameData")`, `get_node("/root/ScoreManager")` — bare get_node | HIGH |
| Mold.gd:44-50 | Uses `if not order_manager:` guard before `get_node()`, but score_manager, game_data, metal_flow use bare `get_node()` | MEDIUM |
| FlowController.gd:27 | Uses `get_node_or_null("/root/GameController")` — correctly nullable, but game_controller is used later without null check at line 125 | MEDIUM |
| Gate.gd:67 | `visual.get_node("GateLight").queue_free()` — no null check on `get_node()` return; also has_node check at line 66 should guard this | LOW |

---

## 3. Resource Leak Risks

| File:Line | Issue | Fix |
|---|---|---|
| Gate.gd:41 | `create_tween()` stored via `set_meta` but previous tween is never killed before creating new one. If toggle_gate is called rapidly, old tween continues running. | Call `visual.get_meta("_tween").kill()` before `remove_meta()` |
| Gate.gd:64 | `visual.add_child(light)` — GateLight added dynamically but no reference stored; relies on `has_node` lookup for removal | Store light reference: `@onready var _gate_light: PointLight2D` |
| PourZone.gd:76 | `_setup_pulsing_border` creates looping tween not stored in variable. If called twice, two looping tweens run simultaneously. No way to stop it. | Store tween: `_pulsing_tween = create_tween().set_loops()` and kill/stop before recreating |
| Mold.gd:223 | `_update_display` creates tween every frame (during FILLING state) with no guard. Multiple rapid `receive_metal` calls spawn multiple concurrent tweens on the same property. | Store and kill previous tween before creating new one |
| Mold.gd:374,381,389,397,406,413,418,433 | `_create_contamination_effect`, `_trigger_wrong_metal_flash`, `_create_receiving_glow`, `_animate_hardening`, `_animate_complete_settle`, `_create_complete_effect`, `_create_clear_effect` — all create tweens with no storage or cleanup. Called frequently; tweens accumulate if nodes are freed while tweening. | Store tween references; kill existing before creating new |
| Intake.gd:107 | `add_child(particles)` with `particles.finished.connect(_on_particles_finished.bind(particles))` — correct pattern. But `_spawn_particle_burst` can be called multiple times rapidly, spawning many particles before first batch finishes. | Rate-limit or cancel previous batch |
| PartPopEffect.gd:39,109 | `create_tween().tween_callback(polygon.queue_free)` / `label.queue_free` — correct pattern, tween owns cleanup | OK |
| PourZone.gd:163 | `create_tween()` for drip particle stored locally, tween_callback calls `queue_free` — correct pattern | OK |

---

## 4. Edge Case Analysis

| # | Scenario | Expected | Actual | File:Line |
|---|---|---|---|---|
| 1 | Player toggles gate rapidly (click-click-click) | Gate visually updates each toggle, only final state matters | Old tween continues animating while new one starts; visual may jump or conflict | Gate.gd:41 |
| 2 | Metal poured on locked mold (order complete, next not started) | Metal rejected, waste penalty applied | Correctly handled — `is_locked` returns early with waste penalty | Mold.gd:84-87 |
| 3 | Wrong metal poured into mold mid-fill | Contamination triggered, mold permanently ruined | Correctly handled — `_trigger_contamination` fires | Mold.gd:117-135 |
| 4 | Gate toggled while actively pouring | Pour continues OR is flushed; no metal lost | Correctly implemented — `flush_accumulator` called before pour stops | PourZone.gd:222-233 |
| 5 | Mold tapped while in HARDENING state | No effect (cannot clear mid-cooling) | Correctly handled — tap only clears if contaminated | Mold.gd:76-80 |
| 6 | Order starts with mold partially filled from previous order | Mold fully cleared before new requirements applied | `clear_mold()` called in `_on_order_started` before setting required_metal | Mold.gd:205-216 |
| 7 | `game_data` or `score_manager` node missing at runtime | Game handles gracefully | CRASH — bare `get_node()` with no fallback | GameController.gd:13-16, OrderManager.gd:15-16 |
| 8 | `mold_area` node missing from scene | `_setup_molds` returns early | Correctly uses `get_node_or_null` | GameController.gd:64 |
| 9 | Player holds pour while moving mouse out of zone | Pour ends, stream hidden | Uses `event.position` (screen-space) for zone check — works but mixing with world-space `get_global_mouse_position()` in _start_pour | PourZone.gd:167-176 |
| 10 | `FlowController.get_mold_for_pour_position` called with null game_controller | Returns empty dict, no crash | Correctly guarded with `if not mold_area` | FlowController.gd:125-126 |

---

## 5. Architecture Issues

### 5.1 Hardcoded Node Paths
All root-level node lookups use string paths:
- `get_node("/root/OrderManager")` — fragile if scene hierarchy changes
- `get_node("/root/MetalFlow")`
- `get_node("/root/ScoreManager")`
- `get_node("/root/FlowController")`
- `get_node("/root/MetalSource")`
- `get_node("/root/GameData")`

**Recommendation:** Use a `GameBus` singleton (autoload) or dependency injection via `@export` in scene files.

### 5.2 Godot Singleton Pattern Missing
The project has no autoload singleton. All cross-system communication goes through absolute root paths. This creates tight coupling — e.g., `Mold.gd` directly references `/root/OrderManager`, `/root/ScoreManager`, `/root/GameData`, `/root/MetalFlow`. Adding a new mold instance requires the scene to be structured exactly as expected.

### 5.3 Signal Proliferation
12 of 24 declared signals are unconnected. `part_produced`, `mold_completed`, `mold_filled`, `mold_contaminated`, `mold_cleared`, `score_updated`, `waste_updated` are all emitted but have zero game-script handlers. These are "fire and forget" signals with no consumer.

### 5.4 Z-Index Inefficiency
`GameController.gd:_process` animates `FurnaceGlow/GlowGradient.modulate.a` every frame (lines 117-121). The FEATURE-006 design doc explicitly calls for a shader-based pulse replacing this CPU-driven tween. The current approach wastes CPU on what a GPU shader should handle.

### 5.5 Tight Coupling: Mold → OrderManager
`Mold._on_order_completed` sets `is_locked = true`. `Mold._on_order_started` clears mold and resets `is_locked`. This bidirectional coupling means Mold must know about order lifecycle. A `MoldStateMachine` or `LockedState` enum would decouple this.

### 5.6 Timer Without Node Reference Storage
`Mold._hardening_timer` is a local variable, not a class member. While it's added as child and properly `queue_free`d in `clear_mold()`, there's no stored reference for external cancellation (e.g., if the Mold itself is freed while timer runs).

---

## 6. FEATURE-006 Implementation Plan

**Design Doc:** `FEATURE_006_ATMOSPHERE.md` (Forge Atmosphere)

### 6.1 What the Design Requires
- Dark forge background: `Color(0.05, 0.02, 0.01)` full viewport
- Furnace glow: radial shader-based pulse at `(200, -30)`, ~2.5s sine cycle
- Ember particles: 30-50 rising embers with drift, 1.0-2.5x scale
- All atmosphere elements: `z_index -100 to -80` (behind gameplay)
- Shader-based pulse replacing GameController's `_process` tween

### 6.2 Code Changes Required

**`GameController.gd`** (lines 117-121):
- REMOVE the `_process` furnace glow animation — the shader handles pulsing via `TIME`
- REMOVE the `_furnace_pulse_time` variable

**`Main.tscn`** (scene changes):
- CREATE new node structure under existing `FurnaceAtmosphere` (Node2D, z=-90):
  ```
  FurnaceAtmosphere (Node2D, z=-90)
    FurnaceGlowShader (Node2D, position 200, -30)
      GlowSprite (Sprite2D) — RadialGradientTexture, custom glow shader
    EmberEmitter (Node2D, z=-80)
      EmberParticles (CPUParticles2D) — retune parameters
  ```
- REPLACE `FurnaceGlow/ColorRect` placeholder with `GlowSprite` + shader
- RETUNE `EmberParticles` (see Ember Parameter Table in design doc)

**New file: `shaders/forge_glow.gdshader`**:
```gdscript
shader_type canvas_item;
uniform float pulse_speed = 0.8;
uniform vec4 glow_color : source_color = vec4(1.0, 0.4, 0.05, 1.0);
uniform float glow_radius = 0.5;
void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) / glow_radius;
    float alpha = pow(1.0 - smoothstep(0.0, 1.0, dist), 1.5);
    float pulse = (sin(TIME * pulse_speed * 6.28318) + 1.0) * 0.2 + 0.4;
    COLOR = glow_color * alpha * pulse;
    COLOR.a *= alpha * pulse;
}
```

**`EmberParticles` parameter retune** (per design doc):
- `amount`: 40 → 35
- `lifetime`: 3.5 → 4.0
- `spread`: 30.0 → 45.0
- `gravity`: `Vector2(0, -80)` → `Vector2(0, -60)`
- `initial_velocity_min/max`: 30/60 → 20/40
- `angular_velocity_min/max`: -100/100 → -50/50
- `linear_accel_min/max`: -20/-50 → -10/-30
- `scale_amount_min/max`: 1.5/3.5 → 1.0/2.5

---

## 7. FEATURE-007 Implementation Plan

**Design Doc:** `FEATURE_007_MOLTEN_STREAM.md` (Molten Metal Stream Rework)

### 7.1 What the Design Requires
- Dual Line2D stream: core (existing) + glow halo (new)
- Stream wobble shader for liquid feel
- Pour point: Sprite2D with RadialGradientTexture replacing `_glow_rect`
- Drip particles: CPUParticles2D (new) replacing manual ColorRect+tween drips
- Splatter burst on mold impact: CPUParticles2D on-demand
- Z-index: stream above atmosphere (-80 to 0), below UI

### 7.2 Code Changes Required

**`PourZone.gd`**:

ADD new child nodes (in `_setup_visuals`):
- `StreamGlowLine` (Line2D) — wider halo, behind StreamLine, 30% alpha glow color
- `PourPointGlow` (Sprite2D) — replaces `_glow_rect`, RadialGradientTexture
- `DripParticles` (CPUParticles2D) — NEW, replaces `_spawn_drip_particle` tween system
- `SplatterParticles` (CPUParticles2D) — NEW, one-shot burst on mold impact

REMOVE:
- `_glow_rect` (replaced by PourPointGlow)
- `_spawn_drip_particle` function (replaced by DripParticles CPUParticles2D)
- The manual ColorRect+tween drip system in `_spawn_drip_particle`

MODIFY `_update_stream_visuals`:
- Update both `StreamLine` and `StreamGlowLine` points
- Remove per-frame `_glow_rect` position/size/alpha updates (handled by shader or static Sprite2D)

MODIFY `_start_pour`:
- Emit `SplatterParticles.one_shot = true` burst on pour start
- Configure `DripParticles` emission rate based on metal type

MODIFY `_end_pour`:
- Stop `DripParticles` emission
- Fire final splatter burst

NEW integration in `MetalFlow.gd` or `Mold.gd`:
- On `mold_filled` or `receive_metal` → call `PourZone.splatter()` to fire splatter burst

ADD stream wobble shader (`shaders/stream_wobble.gdshader`):
```gdscript
shader_type canvas_item;
uniform float wobble_amount = 2.0;
uniform float wobble_frequency = 3.0;
void fragment() {
    float offset = sin(TIME * wobble_frequency + UV.y * 10.0) * wobble_amount;
    // Displace texture coordinate horizontally
}
```

---

## 8. Top 5 Bugs Found

| # | File:Line | Bug | Fix |
|---|---|---|---|
| 1 | **GameController.gd:13-16** | Bare `get_node()` calls for all root managers without null checks. If any expected node is absent (e.g., during scene transition or test injection), the game crashes immediately. | Wrap all four in `get_node_or_null()` with null guards and `_setup_molds()`/`_reset_game()` guards: `if not order_manager: push_error("OrderManager not found"); return` |
| 2 | **Gate.gd:41** | `_update_visual` stores new tween via `set_meta("_tween", tween)` but never calls `.kill()` on the previous tween. Rapid gate toggling leaves orphaned tweens animating the same properties, causing visual glitches. | Before creating new tween: `if visual.has_meta("_tween"): visual.get_meta("_tween").kill()` |
| 3 | **PourZone.gd:76** | `_setup_pulsing_border()` creates a looping tween with `set_loops()` but does not store the tween reference. If called multiple times (e.g., node re-added to scene), multiple independent looping tweens accumulate with no way to stop them. | Store as `@onready var _pulsing_tween: Tween = null`; in `_setup_pulsing_border`, kill/stop existing before creating new |
| 4 | **Mold.gd:223** | `_update_display` is called on every `receive_metal` (which can be every frame during pouring) and creates a new tween each time without killing previous ones. This spawns dozens of concurrent tweens on `fill_bar.value`, causing visual stutter and incorrect bar positions. | Store `_display_tween: Tween` as class member; `if _display_tween: _display_tween.kill()` before creating new one |
| 5 | **FlowController.gd:27,125** | `game_controller = get_node_or_null("/root/GameController")` — nullable, good. But `get_mold_for_pour_position` at line 125 uses `game_controller.get_mold_area()` without null-checking `game_controller` itself. If GameController is absent, this crashes. | Add `if not game_controller: return {"mold_id": "", "intake_id": ""}` guard at line 124 |

---

*End of review. Next steps: P0 fixes for bugs 1-5, then implement FEATURE-006 and FEATURE-007 per the plans above.*
