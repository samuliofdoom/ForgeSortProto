# ForgeSortProto — Artist Review
**Date:** 2026-04-29
**Scene:** `scenes/Main.tscn`
**Reviewed Files:** Main.tscn, PourZone.gd, Mold.gd, Gate.gd, PartPopEffect.gd, GameController.gd, ARTIST_VISUAL_AUDIT.md, FEATURE_006_ATMOSPHERE.md, FEATURE_007_MOLTEN_STREAM.md

---

## 1. Visual Inventory

| Node Name | Type | Current Color / Size / State | Assessment |
|---|---|---|---|
| `ForgeBackground` | ColorRect | `#0D0502`, full viewport | OK as base. Dark warm black — correct foundation. |
| `FurnaceGlow/GlowGradient` | ColorRect | `#FF6609` at 0.6 alpha, 500x300 px | Functional but primitive. No shader, no heat gradient. No animated heat shimmer. |
| `FurnaceGlow/FurnaceAtmosphere` | Node (null script) | EMPTY | **Missing.** The node exists in scene but has no content. No furnace mouth, no crucible, no spout. |
| `EmberParticles` | CPUParticles2D | z=-80, pos=(200,0), 40 particles, `(1.0, 0.45, 0.1)`, 3.5s lifetime | Partially OK. Quantity and velocity low vs. design doc spec. No color gradient. |
| `PourZone/PourZoneBG` | ColorRect | `(0.9, 0.4, 0.1, 0.3)`, 380x80 px | Pulsing border works. Acceptable placeholder. |
| `PourZone/StreamLine` | Line2D (runtime) | Iron: `(0.9, 0.35, 0.05)`, width=8px | **Missing glow shader.** Stream is flat 2D. No heat gradient along length. |
| `PourZone/StreamGlow` | ColorRect (runtime) | Per-metal glow color, pulsing alpha 0.3–0.8 | Radial glow blob exists but primitive — no soft radial gradient, just a solid ColorRect. |
| `PourZone/ParticleContainer` | Node2D (runtime) | ColorRect drips, 2–7 px, fall animation | Basic. Drips shrink/fade but no splatter burst on mold impact. |
| `RoutingField/Gate_01–04` | StaticBody2D | Gray `(0.4, 0.4, 0.5)`, 20x60 px ColorRect | Functional but flat. No bevel, no material feel. |
| `RoutingField/Intake_A/B/C` | Area2D | `(0.75, 0.45, 0.3, 0.4)`, 40x30 px ColorRect | Plain rectangles. No funnel shape. No highlight on metal arrival. |
| `MoldArea/BladeMold` etc. | Node2D | `MoldSprite`: `(0.3, 0.25, 0.2)`, 80x60 px ColorRect | No bevel, no depth, no texture. Mold shape is indistinguishable from a brick. |
| `MoldArea/*/FillBar` | ProgressBar | Default Godot style | Functional but unthemed. |
| `MoldArea/*/StateLabel` | Label | Default font, centered below mold | OK. |
| `PartPopEffect` | Node2D | Polygon2D blade/guard/grip shapes, elastic pop animation | Good logic. Polygons look correct. Colors match solid metal spec. |
| `UI/*` buttons | Button (default) | Unstyled Godot default | All buttons are plain. No forge aesthetic. |

---

## 2. Missing Visual Elements

(from ARTIST_VISUAL_AUDIT.md — what exists in design but NOT in scene)

1. **Molten metal stream glow shader** — `Line2D` has no `molten_glow.gdshader`. Stream appears flat.
2. **Stream glow halo** — No second wider `Line2D` behind the stream core.
3. **FurnaceAtmosphere contents** — Empty node. No furnace mouth, no crucible visual, no spout.
4. **Heat haze / distortion** — No screen-space or node-space distortion near the pour stream.
5. **Pour splatter on mold impact** — No burst of 3–5 particles at the mold when metal arrives.
6. **Flow channel guides** — No drawn lines between gates and intakes.
7. **Smoke / steam** — No particle effect where hot metal meets mold.
8. **Mold detail** — ColorRect placeholders only. No bevel, texture, or depth shading.
9. **Background depth layers** — Single flat `ForgeBackground`. No rear silhouettes or parallax.
10. **Intake funnel shape** — Plain `ColorRect` rectangles, not funnels.
11. **Padlock detail** — 3-rectangle construction works but is unsophisticated.
12. **Themed UI buttons** — All default Godot style throughout.
13. **Stream heat gradient** — Stream is solid color top-to-bottom, not hotter-at-top.

---

## 3. FEATURE-006 Implementation Checklist

(from `docs/FEATURE_006_ATMOSPHERE.md`)

| # | Item | Status | Action |
|---|---|---|---|
| 1 | **FurnaceAtmosphere node content** | NOT DONE | Add `Polygon2D` furnace mouth (trapezoid) at `(200, 0)`. Add animated heat-shimmer via sine-wave UV offset. Add layered `ColorRect` or `PointLight2D` for core glow. |
| 2 | **Upgrade `EmberParticles` to Layered A/B/C system** | PARTIAL | Currently 40 particles at `(200,0)`. Target: Layer A 80–120 particles with gradient `#FF4400 → #FFCC00`. Layer B: spark bursts (one-shot on gate toggle). Layer C: ambient smoke. |
| 3 | **Ember particle params (Layer A — main embers)** | PARTIAL | Amount: **80–120** (current 40). Lifetime: **2.5–4.0s random** (current 3.5 fixed). Velocity: **40–80 px/s** (current 30–60). Gravity: **`(0, -60)`** (current `(0, -80)`). Spread: **45°** (current 30°). Angular vel: **±150** (current ±100). Scale: **2.0–5.0** (current 1.5–3.5). Add `lifetime_randomness: 0.3`. |
| 4 | **Ember color ramp** | NOT DONE | Current: single `(1.0, 0.45, 0.1)`. Target: gradient ramp start `#FF4400` → end `#FFCC00`. |
| 5 | **Furnace glow shader** | NOT DONE | Replace pulsing `ColorRect` with a radial gradient `PointLight2D` or shader-based glow with soft feathered edge. |
| 6 | **Background depth layers** | NOT DONE | Add 2–3 parallax silhouette layers behind `ForgeBackground`: rear stone/brick shapes, mid forge structure outline, front ambient heat haze. |
| 7 | **Heat-darkening overlay** | NOT DONE | Optional per FEATURE-006: dark vignette overlay that intensifies as waste increases. |

---

## 4. FEATURE-007 Implementation Checklist

(from `docs/FEATURE_007_MOLTEN_STREAM.md`)

| # | Item | Status | Action |
|---|---|---|---|
| 1 | **Create `shaders/molten_glow.gdshader`** | NOT DONE | New file. Apply to `StreamLine` Line2D. Uniforms: `glow_intensity=1.5`, `glow_color`, `glow_width_multiplier=2.5`. Heat gradient: brighter at top (UV.y=0), cooler at bottom. |
| 2 | **Add `StreamGlowLine` Line2D (glow halo)** | NOT DONE | New runtime Line2D in PourZone. Width: `_current_stream_width * 3.5`. Color: glow at 35% alpha. z_index: `StreamLine.z_index - 5`. Apply `stream_glow` shader with wobble. |
| 3 | **Stream width per metal** | EXISTING | Iron=8px, Steel≈10px, Gold≈12px via `metal_def.spread`. Already driven by `_current_stream_width`. Verify wobble shader scales correctly with width. |
| 4 | **Upgrade drip particles — fade + shrink** | EXISTING PARTIAL | Current drips: ColorRect fall + queue_free. Missing: shrink over lifetime, fade alpha. Add `scale` tween shrinking to 0 and `modulate:a` fading in `_spawn_drip_particle()`. |
| 5 | **Splatter burst on mold impact** | NOT DONE | New `CPUParticles2D` (one-shot, 3–5 particles) fired when `Mold.receive_metal()` is called. Radial burst with gravity, metal color, 0.5s lifetime. Attach to Mold node or mold_area. |
| 6 | **Stream wobble shader params** | NOT DONE | Per doc: `stream_glow` shader with `heat = 1.0 - UV.y` and `wobble` uniform for liquid undulation. |
| 7 | **Glow color per metal (halo)** | IN CODE | `_get_metal_glow_color()` exists in PourZone.gd — verify `StreamGlowLine` uses it at runtime. Iron: `(1.0, 0.5, 0.1)`, Steel: `(0.9, 0.95, 1.0)`, Gold: `(1.0, 0.9, 0.4)`. |
| 8 | **Pour point radial glow upgrade** | EXISTING PARTIAL | `_glow_rect` is a solid `ColorRect`. Replace with soft radial gradient sprite or `Sprite2D` with radial texture for proper bloom. |

---

## 5. Color Palette

| Element | Color | Hex |
|---|---|---|
| **Background base** | Dark warm black | `#0D0502` |
| **Background gradient top** | Dark brown | `#260D04` |
| **Furnace glow (current)** | Orange | `#FF6609` |
| **Furnace glow pulse range** | Alpha 0.4–0.8 | via `sin` ~2.5s cycle |
| **Iron — molten stream** | Bright dull-orange | `#E65500` |
| **Iron — stream glow** | Orange | `#FF8019` |
| **Iron — solid / cooled** | Gray-brown | `#8C8580` |
| **Steel — molten stream** | Silver-white | `#D9E6FF` |
| **Steel — stream glow** | Light silver | `#E6F0FF` |
| **Steel — solid / cooled** | Blue-gray | `#BFC9D1` |
| **Gold — molten stream** | Bright yellow | `#FFF24D` |
| **Gold — stream glow** | Warm yellow | `#FFE666` |
| **Gold — solid / cooled** | Amber | `#FFD11A` |
| **Ember — hot** | Red-orange | `#FF4400` |
| **Ember — cool** | Yellow | `#FFCC00` |
| **Gate closed** | Gray | `#666680` |
| **Gate open** | Green | `#00CC66` |
| **Gate light (open)** | Green, energy 0.6 | via PointLight2D |
| **Intake fill** | Brown-orange | `#BF7333` at 40% alpha |
| **Mold idle** | Dark brown | `#4D3F33` |
| **Mold filling (active)** | Metal color * 0.7 | via `modulate` |
| **Mold hardening** | Gray-blue | `#B3B8BF` |
| **Mold contaminated** | Red | `#FF0000` |
| **Mold complete** | Green | `#00FF66` |
| **UI panel background** | Dark blue-gray | `#1A1A26` at 95% alpha |
| **Rejection flash** | Orange | `#FF8800` at 70% |

---

## 6. Particle Specifications

### Layer A — Main Embers (upgrade existing `EmberParticles`)

| Parameter | Current | Target |
|---|---|---|
| Amount | 40 | **80–120** |
| Lifetime | 3.5s (fixed) | **2.5–4.0s random** |
| Initial velocity min/max | 30–60 px/s | **40–80 px/s** |
| Velocity X drift | none | **±20 random** |
| Gravity | `(0, -80)` | **`(0, -60)`** |
| Spread | 30° | **45°** |
| Angular velocity | ±100 °/s | **±150 °/s** |
| Scale min/max | 1.5–3.5 | **2.0–5.0** |
| Color | single `(1.0, 0.45, 0.1)` | **Ramp: `#FF4400` → `#FFCC00`** |
| Hue variation | ±0.1 | **±0.15** |
| Lifetime randomness | not set | **0.3** |
| Emitter position | `(200, 0)` | `(200, 0)` — keep |

### Layer B — Spark Bursts (new, one-shot)

| Parameter | Value |
|---|---|
| Trigger | On gate toggle |
| Amount | 8–12 per burst |
| Lifetime | 0.3–0.6s |
| Velocity | 80–150 px/s radial |
| Gravity | `(0, 120)` (arc down) |
| Color | `#FF6600` → `#FFAA00` |
| Scale | 1.0–2.0 |
| One-shot | yes |

### Layer C — Ambient Smoke (new)

| Parameter | Value |
|---|---|
| Position | Above furnace `(200, -20)` |
| Amount | 5–8 steady |
| Lifetime | 5–8s |
| Velocity | `(0, -15)` slow rise |
| Spread | 60° |
| Color | `#332222` → transparent |
| Scale | 3.0–6.0, expanding |
| One-shot | no |

### Drip Particles (existing, upgrade needed)

| Parameter | Current | Target |
|---|---|---|
| Shrink during fall | not implemented | Tween scale 1.0 → 0 over duration |
| Fade during fall | alpha fixed | Tween `modulate:a` 1.0 → 0 in last 20% |
| Splatter on mold impact | not implemented | New CPUParticles2D burst: 3–5 particles, radial, gravity, metal color, 0.5s |

---

## 7. Shader Suggestions

### `shaders/molten_glow.gdshader` (NEW — for StreamLine)

```
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float glow_width_multiplier : hint_range(1.0, 4.0) = 2.5;

void fragment() {
    // Line2D UV.y: 0 = start (pour origin/top), 1 = end (pour point/bottom)
    float heat = 1.0 - UV.y;         // 1.0 at top (hot), 0.0 at bottom
    vec4 hot_color = glow_color * vec4(1.0 + heat * 0.5, 1.0 + heat * 0.3, 1.0 + heat * 0.2, 1.0);
    float glow = glow_intensity * (0.5 + heat * 0.5);
    COLOR = hot_color * glow;
}
```

### `shaders/stream_glow.gdshader` (NEW — for StreamGlowLine, halo with wobble)

```
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.1, 0.35);
uniform float wobble_amount : hint_range(0.0, 1.0) = 0.08;
uniform float wobble_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    float heat = 1.0 - UV.y;
    // Liquid wobble: sine wave along stream length
    float wobble = sin(TIME * wobble_speed + UV.y * 12.0) * wobble_amount * heat;
    vec4 col = glow_color * vec4(1.0 + heat * 0.3, 1.0 + heat * 0.2, 1.0 + heat * 0.1, 1.0);
    COLOR = col * glow_intensity * (0.6 + wobble);
}
```

### Stream Glow Parameters Summary

| Property | Value |
|---|---|
| Core stream width (iron) | 8 px |
| Core stream width (steel) | 10 px |
| Core stream width (gold) | 12 px |
| Halo width | stream_width × 3.5 |
| Halo alpha | 0.35 |
| Halo z_index | StreamLine.z - 5 |
| Pour point glow radius | stream_width × 3 (ColorRect or radial Sprite2D) |
| Pour point glow pulse | sin(t * 0.01) * 0.25 + 0.3 → alpha range 0.3–0.8 |

---

## 8. Top 5 Visual Priorities

### P1 — Stream Glow Shader (FEATURE-007 unblocked)
**Action:** Create `shaders/molten_glow.gdshader` and apply to `StreamLine` Line2D in `PourZone._setup_visuals()`. Add second `StreamGlowLine` halo Line2D (3.5× width, glow color at 35% alpha, wobble shader).
**Why:** The stream is the primary gameplay visual. Without glow it is flat and unreadable against the dark forge background. This is the single highest-impact visual improvement.
**Files touched:** `PourZone.gd`, new `shaders/molten_glow.gdshader`, new `shaders/stream_glow.gdshader`

### P2 — Splatter Burst on Mold Impact (FEATURE-007)
**Action:** In `Mold.receive_metal()`, call `part_pop_effect.spawn_splatter(metal_id, global_position)` after the fill logic. Implement `spawn_splatter()` using a one-shot `CPUParticles2D` (3–5 particles, radial velocity 80–150 px/s, gravity, metal color, 0.5s lifetime).
**Why:** Players have no feedback when metal actually arrives at a mold. The splatter burst communicates "metal arrived" at a glance.
**Files touched:** `Mold.gd`, `PartPopEffect.gd`

### P3 — FurnaceAtmosphere Contents (FEATURE-006 unblocked)
**Action:** Replace the empty `FurnaceAtmosphere` null node with: (a) a `Polygon2D` furnace mouth at `(200, 0)` — trapezoid shape in dark iron color; (b) a `PointLight2D` or layered `ColorRect` for the furnace core glow with a proper radial gradient; (c) optional heat-shimmer sine offset on UV.
**Why:** The furnace is the source of all gameplay. A visible furnace mouth/trunnel makes the top of the screen feel like an actual forge, not just empty space with a glow.
**Files touched:** `Main.tscn` (add nodes), optional `FurnaceAtmosphere.gd` (script)

### P4 — Ember Particle Layer Upgrade (FEATURE-006)
**Action:** On `EmberParticles` CPUParticles2D: increase `amount` to 80–120, set `lifetime_randomness: 0.3`, set `initial_velocity_min/max: 40.0, 80.0`, set `gravity: (0, -60)`, set `spread: 45.0`, set `angular_velocity_min/max: -150.0, 150.0`, set `scale_amount_min/max: 2.0, 5.0`, set `hue_variation_min/max: -0.15, 0.15`. Add `color_ramp` gradient from `#FF4400` to `#FFCC00`.
**Why:** The current 40-particle system looks sparse and monotonous. FEATURE-006 calls for 80–120 with a color gradient. This is a single node parameter change in Main.tscn plus a new Gradient resource.
**Files touched:** `Main.tscn` (EmberParticles params), new `sub_resource type="Gradient"` for ember color ramp

### P5 — Mold Sprite Upgrade (detail pass)
**Action:** Replace each mold's `MoldSprite` (flat `ColorRect`) with: (a) a `Polygon2D` shaped like the part (blade = tall narrow, guard = wide flat, grip = tall narrow); (b) add a bevel effect via a second slightly-lighter `Polygon2D` outline behind it; (c) connect `_update_fill_glow()` to drive a dedicated glow `ColorRect` (hidden behind sprite) rather than modulating `modulate.v` on the sprite itself.
**Why:** Molds are the core gameplay target. Distinct silhouette shapes (blade vs guard vs grip) immediately communicate which mold is which without reading labels. Glow-as-modulation is too subtle; a dedicated glow rect will be much more visible.
**Files touched:** `Main.tscn` (MoldArea children), `Mold.gd` (`_update_fill_glow()`, `_update_display()`)
