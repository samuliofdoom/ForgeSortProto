# FEATURE-007: Molten Metal Stream Rework
**Status:** P0 / Blocked (needs design doc)  
**Design Doc Version:** 1.0  
**Created:** 2026-04-29

---

## 1. Visual Description

The molten metal stream is the primary visual feedback when the player pours. Currently metal flows as a simple `Line2D` from the top of the screen to the pour point — functional but flat. The rework makes it look like glowing liquid metal.

When the player holds and sweeps:

- **Stream body:** A thick glowing line streams from the top of the viewport down to the mouse pour position. The stream has a **core** (bright molten color) and a **soft glow halo** around it. The stream slightly wobbles/undulates along its length to imply liquid movement.
- **Color per metal type:**
  - **Iron:** Molten orange-red `Color(0.9, 0.35, 0.05)` — dull ember glow
  - **Steel:** Molten silver-white `Color(0.85, 0.9, 1.0)` — bright, almost white-blue
  - **Gold:** Molten bright yellow `Color(1.0, 0.95, 0.3)` — warm luminous yellow
- **Stream glow:** A wider, softer halo in a brighter/lighter version of the metal color surrounds the stream. For iron: `Color(1.0, 0.5, 0.1)`. For steel: `Color(0.9, 0.95, 1.0)`. For gold: `Color(1.0, 0.9, 0.4)`.
- **Dripping particles:** Small molten droplets break off from the stream and fall toward the molds. Each drip is a small rectangle that shrinks and fades as it falls. Drip rate is metal-specific: iron drips slowly (every 0.05s), steel medium (0.04s), gold fast/heavy (0.03s).
- **Splatter on impact:** When metal hits a mold (correct or wrong), a small **splatter burst** of 3–5 particles sprays outward from the impact point, then falls with gravity. This communicates "metal arrived."
- **Stream width per metal:** Matches current behavior (driven by `metal_def.spread`):
  - Iron: 8px base
  - Steel: 8px * spread (typically wider, ~10px)
  - Gold: 8px * spread (typically widest, ~12px)

The overall feel: hot liquid metal pouring in a dark forge, light bouncing off the stream, sparks of molten drips flying.

---

## 2. Technical Approach

### 2.1 Current Implementation Review

The existing `PourZone.gd` already implements:
- `_stream_line` (Line2D): Straight line from top of screen to pour point
- `_glow_rect` (ColorRect): Small square glow at pour point, pulses alpha
- `_particle_container` (Node2D): Drip particles using ColorRect + tween falling

**What needs to change:**
1. Stream body needs a glow halo (wider, blurred outline around Line2D)
2. Stream should wobble (add slight sinusoidal displacement along its length)
3. Splatter burst effect on mold impact
4. The glow rect should be replaced by a proper radial glow at the pour point
5. Drip particles should shrink as they fall (implying cooling)

### 2.2 Proposed Node Structure

Add under `PourZone`:
```
PourZone (Area2D, existing)
├── StreamLine          (Line2D, existing — retune)
├── StreamGlowLine      (Line2D, NEW — wider glowing halo around stream)
├── PourPointGlow       (Sprite2D, NEW — radial glow at pour point, replaces _glow_rect)
├── DripParticles       (CPUParticles2D, NEW — replaces manual ColorRect tween drips)
└── SplatterParticles   (CPUParticles2D, NEW — burst on mold impact)
```

### 2.3 Stream Body — Dual Line2D Approach

**Core stream** (`StreamLine`, existing Line2D):
- `width`: `_current_stream_width` (metal-specific)
- `default_color`: molten metal color (as currently implemented)
- `round_precision`: 8 (current)

**Glow halo** (`StreamGlowLine`, new Line2D, renders behind StreamLine):
- `width`: `_current_stream_width * 3.5`
- `default_color`: metal glow color at 30% alpha
- `round_precision`: 8
- `z_index`: slightly lower than stream (-10 relative to stream)
- Same points as StreamLine

### 2.4 Stream Wobble — Shader on Line2D

Add a simple wobble shader to the `StreamGlowLine` (and optionally `StreamLine`) to give it a liquid shimmer:

```gdscript
# shaders/stream_glow.gdshader
shader_type canvas_item;

uniform float wobble_speed = 3.0;     // oscillations per second
uniform float wobble_amount = 0.06;   // max displacement (UV units)
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.1, 0.35);
uniform float stream_length = 1.0;     // normalized length, updated from GDScript

void fragment() {
    // Slight horizontal displacement along stream length (UV.y)
    float wobble = sin(TIME * wobble_speed + UV.y * 20.0) * wobble_amount;
    vec2 displaced_uv = UV;
    displaced_uv.x += wobble;
    
    // Radial from center of Line2D strip
    float dist = abs(UV.x - 0.5) * 2.0; // 0=center, 1=edge
    
    // Glow falloff
    float alpha = glow_color.a * (1.0 - smoothstep(0.0, 1.0, dist));
    
    COLOR = glow_color;
    COLOR.a = alpha;
}
```

**Update rate:** Pass `stream_length` as a uniform each frame (or use `1.0` if length normalization is skipped for simplicity).

**Performance note:** Wobble shader is cheap (single sin call). If performance is a concern, wobble can be applied only to `StreamGlowLine` (the glow halo), not the core stream.

### 2.5 Pour Point Glow — Sprite2D with RadialGradientTexture

Replace the `_glow_rect` (ColorRect) with a `Sprite2D` using a `RadialGradientTexture`:

**Setup:**
- `PourPointGlow` (Sprite2D, z_index +10 above stream)
- Texture: `RadialGradientTexture` (fill=true, center=0, edge=1)
- Colors: inner `Color(1.0, 0.9, 0.4, 0.9)` → outer `Color(1.0, 0.5, 0.1, 0.0)` (iron example)
- Scale: `Vector2(_current_stream_width * 6, _current_stream_width * 6)` — larger than current 3x
- `modulate`: pulse alpha `(sin(TIME * 0.01) + 1) * 0.25 + 0.3` (same as current glow pulse)
- Position: `pour_origin` updated each frame

### 2.6 Drip Particles — CPUParticles2D

Replace the current per-drip ColorRect + tween system with a `CPUParticles2D` emitter. This is cleaner and more performant for many particles.

**Parameters:**
| Parameter | Value | Notes |
|---|---|---|
| `amount` | 50 | pool of drips |
| `lifetime` | 1.0–1.5 | fall time to bottom |
| `one_shot` | false | continuous |
| `emission_shape` | `1` (Point) | emit from pour_origin |
| `emission_point_extents` | `Vector2(_current_stream_width * 0.5, 0)` | scatter across stream width |
| `direction` | `Vector2(0, 1)` | downward |
| `spread` | 15° | slight horizontal scatter |
| `gravity` | `Vector2(0, 500)` | faster fall than current 500 px/s |
| `initial_velocity_min` | 0 | no initial burst |
| `initial_velocity_max` | 50 | slight initial downward speed |
| `damping_min/max` | `0, 50` | slow down slightly |
| `color` | metal glow color | matches stream glow |
| `scale_amount_min/max` | `1.0, 2.5` | small drips |
| `scale_curve` | — | drip shrinks over lifetime (use `CurveXYZ` or scale_curve resource) |

**Dynamic updates:** When metal type changes (`_on_metal_selected`), update:
- `emission_point_extents.x` (stream width)
- `color` (new metal glow color)
- `scale_amount_max` (gold is larger)

### 2.7 Splatter Burst — CPUParticles2D (on demand)

When metal lands in a mold, spawn a brief splatter burst from the mold position.

**Implementation:** Create a `CPUParticles2D` with `one_shot = true`, `explode()` on demand, then `queue_free()` after lifetime expires.

**Parameters:**
| Parameter | Value | Notes |
|---|---|---|
| `amount` | 5 | small burst |
| `lifetime` | 0.4–0.6s | short burst |
| `one_shot` | true | |
| `emission_shape` | `1` (Point) | |
| `direction` | `Vector2(0, -1)` | spray upward first |
| `spread` | 120° | wide spray arc |
| `gravity` | `Vector2(0, 400)` | fall back down |
| `initial_velocity_min` | 80 | burst outward |
| `initial_velocity_max` | 150 | varied burst speed |
| `color` | metal glow color | hot molten color |
| `scale_amount_min/max` | `0.5, 1.5` | small splatter dots |

**Trigger:** 
- In `Mold.gd`: `receive_metal()` → emit signal `metal_landed(mold_id, metal_id, world_pos)`
- In `PourZone.gd`: connect to this signal and spawn splatter at mold's `global_position`

**Placement:** Add as child of `MoldArea` or the respective mold node, at mold's world position, z-index slightly above mold sprite (+20).

### 2.8 Integration with MetalFlow.gd

The `metal_poured` signal from `MetalFlow.gd` currently carries `(metal_id, world_position, amount)`. This signal can be used to trigger splatter:
- Connect `MetalFlow.metal_poured` → `PourZone._on_metal_poured()`
- Spawn splatter at `world_position`

Alternatively, `Mold.receive_metal()` is a cleaner trigger since it knows exactly which mold received metal.

---

## 3. Specific Parameter Summary

### Stream Core (Line2D — StreamLine, existing)
```
width: _current_stream_width (iron=8, steel=10, gold=12)
default_color: molten color per metal
round_precision: 8
```

### Stream Glow Halo (Line2D — StreamGlowLine, new)
```
width: _current_stream_width * 3.5
default_color: glow color at 35% alpha
round_precision: 8
z_index: StreamLine.z_index - 5
shader: stream_glow (wobble)
```

### Pour Point Radial Glow (Sprite2D — PourPointGlow, new)
```
scale: Vector2(stream_width * 6, stream_width * 6)
modulate alpha: pulse 0.3–0.8 on ~2Hz
texture: RadialGradientTexture (fill, center-to-edge fade)
```

### Drip Particles (CPUParticles2D — DripParticles, new)
```
amount: 50
lifetime: 1.0–1.5s
emission_point_extents: Vector2(stream_width * 0.5, 0)
gravity: Vector2(0, 500)
color: metal glow color
scale: 1.0–2.5, shrinks over lifetime
emission rate: continuous (driven by _current_particle_interval per-metal)
```

### Splatter Burst (CPUParticles2D, on-demand one-shot)
```
amount: 5
lifetime: 0.4–0.6s
one_shot: true
direction: Vector2(0, -1)
spread: 120°
gravity: Vector2(0, 400)
velocity: 80–150
color: metal glow color
scale: 0.5–1.5
triggered by: Mold.receive_metal() or MetalFlow.metal_poured
```

---

## 4. Interaction with FEATURE-006 (Forge Atmosphere)

The molten stream and forge atmosphere are visually inseparable — they share the same color palette and must harmonize:

### Color Harmony
| Element | Iron | Steel | Gold |
|---|---|---|---|
| Stream core | `Color(0.9, 0.35, 0.05)` | `Color(0.85, 0.9, 1.0)` | `Color(1.0, 0.95, 0.3)` |
| Stream glow halo | `Color(1.0, 0.5, 0.1, 0.35)` | `Color(0.9, 0.95, 1.0, 0.3)` | `Color(1.0, 0.9, 0.4, 0.35)` |
| Drip/splatter | `Color(0.95, 0.4, 0.08)` | `Color(0.9, 0.92, 1.0)` | `Color(1.0, 0.92, 0.35)` |
| Furnace glow (FEATURE-006) | `Color(1.0, 0.4, 0.05)` | `Color(1.0, 0.5, 0.1)` | `Color(1.0, 0.5, 0.1)` |

The iron stream should appear slightly darker/duller than the bright furnace glow, to imply the stream is cooler than the furnace source. Steel and gold streams are already bright and will stand out well against the orange furnace glow.

### Z-Index Compatibility
- Atmosphere (FEATURE-006): z -100 to -80
- Stream Glow Halo: z -10 (just below stream core)
- Stream Core: z 0 (at pour zone level)
- Pour Point Glow: z 10 (above stream)
- Drip Particles: z 5
- Splatter: z +20 (above mold level)
- All gameplay elements (molds, gates): z 0–50

This ordering ensures stream is always visible above atmosphere but below UI elements.

### Performance Interaction
- FEATURE-006 adds: 1 shader + 35 CPUParticles2D
- FEATURE-007 adds: 2 Line2Ds (negligible) + 1 Sprite2D + 2 CPUParticles2D (50 + 5 particles)
- Combined atmosphere + stream: ~100 particles + 1 simple shader — well within 60 FPS budget on modern hardware
- On low-end devices: reduce `EmberParticles` amount to 20 and `DripParticles` to 30

---

## 5. Compatibility Notes

### What was changed in current code that must be preserved
- `_stream_line` and `_glow_rect` in PourZone are referenced by `_show_stream_visuals()` / `_hide_stream_visuals()` — these functions must be updated to also show/hide the new `StreamGlowLine` and `PourPointGlow`
- `_get_metal_color()` and `_get_metal_glow_color()` are used to color the stream — these should be the **single source of truth** for metal colors, reused for all new stream elements
- `metal_selected` signal updates stream color — same signal drives the new drip/splatter color updates

### Breaking changes
- `_glow_rect` is replaced by `PourPointGlow` (Sprite2D). The old node name should be removed from the scene and code.
- The `_spawn_drip_particle()` tween-based system is replaced by `DripParticles` (CPUParticles2D). Remove `_spawn_drip_particle()` and `_last_particle_time` tracking when the new system is active.

### Mold splatter signal
- If using `Mold.receive_metal()` as splatter trigger, add a `metal_received` signal to `Mold.gd` that carries `(mold_id, metal_id, world_pos)`.
- Or use existing `MetalFlow.metal_poured` signal (already emitted when metal is successfully routed).

---

## 6. Acceptance Criteria

1. Stream visually has a glowing halo around the core line
2. Stream wobbles/shimmers subtly (liquid feel)
3. Dripping particles fall from stream and shrink as they descend
4. Splatter burst occurs when metal hits a mold (correct or wrong metal)
5. Pour point has a larger, softer radial glow
6. All three metal types (iron/steel/gold) have distinct glowing colors
7. Stream color updates correctly when player switches metal type mid-pour
8. Performance: stable 60 FPS with stream active
9. Correct z-ordering: stream above atmosphere, below UI
10. Old `_glow_rect` and tween-based drip system removed, replaced by new nodes
