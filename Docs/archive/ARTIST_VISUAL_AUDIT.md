# ARTIST_VISUAL_AUDIT.md
## ForgeSortProto — Visual State Assessment

---

## 1. CURRENT VISUAL INVENTORY

### Background / Atmosphere
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `ForgeBackground` | ColorRect | `(0.05, 0.02, 0.01)` — near-black dark brown | Covers 400x600, z=-100 |
| `FurnaceGlow/GlowGradient` | ColorRect | `(1.0, 0.4, 0.05)` at 0.6 alpha, 500x300 | Centered at `(200, -30)`, z=-90. Static radial-warmth placeholder. |
| `FurnaceGlow/FurnaceAtmosphere` | Node | Script: `null` | Empty placeholder node, no effect. |
| `EmberParticles` | CPUParticles2D | Color: `(1.0, 0.45, 0.1)` — bright orange | 40 particles, lifetime 3.5s, upward drift (gravity `0, -80`), angular velocity ±100, scale 1.5–3.5. z=-80. |

### Pour Zone
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `PourZoneBG` | ColorRect | `(0.9, 0.4, 0.1)` at 0.3 alpha, 380x80 | Pulsing border via tween loop on alpha 0.5↔0.2. |
| `PourZoneLabel` | Label | Default white text | Static — "Hold & Sweep to Pour" |
| `StreamLine` (dynamic) | Line2D | Width: 8–16 (metal-dependent), rounded | Iron: `(0.9, 0.35, 0.05)`, Steel: `(0.85, 0.9, 1.0)`, Gold: `(1.0, 0.95, 0.3)` |
| `StreamGlow` (dynamic) | ColorRect | Size: `stream_width * 3`, pulsing alpha 0.3–0.8 | Iron glow: `(1.0, 0.5, 0.1)`, Steel: `(0.9, 0.95, 1.0)`, Gold: `(1.0, 0.9, 0.4)` |
| Drip particles (dynamic) | ColorRect pool | 2–7 px squares, metal-colored | Spawned per `base_particle_interval / speed`, fall at 500 px/s |

### Gates
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `Gate_0X/Visual` | ColorRect | `(0.4, 0.4, 0.5)` — gray-blue, 20x60 | Animated rotation PI/4 + color→GREEN when open; PointLight2D added/removed |
| `Gate_0X/CollisionShape2D` | CollisionShape2D | 20x60 | Physics body |

### Intakes
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `Intake_X/Visual` | ColorRect | `(0.75, 0.45, 0.3)` at 0.4 alpha, 40x30 | Flat, no animation |
| `Intake_X/CollisionShape2D` | CollisionShape2D | 40x30 | Area2D |

### Molds
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `MoldSprite` | ColorRect | `(0.3, 0.25, 0.2)` — dark brown-gray, 80x60 | Modulated by state: orange=cooling, red=contaminated, green=complete, yellow=filling |
| `FillBar` | ProgressBar | Default Godot style | Animated fill tween 0.25s; color matches state |
| `StateLabel` | Label | White default | Text changes: "Cooling...", "Done!", "Tap to Clear", "Locked", "XX%" |
| `Padlock` | Node2D (3x ColorRect) | Gray `(0.6, 0.6, 0.65)` | Shown when `is_locked`, pulsing scale animation |

### Part Pop Effect
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| Polygon2D (dynamic) | Polygon2D | Metal-colored, z=150 | Scale pulse: 1.0→1.3→1.0 over 0.4s, then fade 0.2s |
| Pop labels | Label | GREEN "Order Complete!", YELLOW "+score" | Float upward and fade over 1.0s |

### Rejection Effect
| Node | Type | Color / Size | Notes |
|---|---|---|---|
| `RejectionFlash` (dynamic) | ColorRect | ORANGE*0.7, 20x20 | Expands to 2x scale, fades over 0.5s |

### UI (CanvasLayer)
| Node | Notes |
|---|---|
| `MetalSelector` | 3 buttons (Iron/Steel/Gold) + label, default Godot button style |
| `ScoreDisplay` | Label "Score: 0" right-aligned |
| `SpeedTimer` | Label "0.0s" centered top |
| `WasteMeter` | Label + ProgressBar, default Godot style |
| `GateToggleUI` | 4 toggle buttons (G1–G4) with route labels (A/B, B/C, A+C, C), default style |
| `OrderPanel` | Name label, VBoxContainer part list, ProgressBar |
| `ResultPanel` | Dark `ColorRect` BG `(0.1, 0.1, 0.15, 0.95)`, hidden until game over |
| `StartButton` | Default button, centered at `(200, 375)` |
| `GateDebugHUD` | CanvasLayer overlay |

---

## 2. MISSING VISUAL ELEMENTS

1. **Molten Metal Stream Glow** — Line2D has no glow shader. Stream appears flat and 2D.
2. **Metal Stream Gradient** — Stream is a solid color Line2D. Should fade from bright (pour origin) to dimmer (bottom) or have a heat gradient.
3. **Furnace Core Visual** — The furnace mouth/tip where metal emerges is a `FurnaceAtmosphere` null node. No visible furnace tip, no glowing crucible.
4. **Heat Haze / Distortion** — No screen-space or node-space distortion near the pour stream.
5. **Pour Splashes at Intakes** — Metal entering intakes has no splash or ripple visual.
6. **Flow Channels** — The path between gates and intakes is invisible. No drawn channels/guides.
7. **Smoke / Steam Effects** — No smoke from the furnace or steam where hot metal meets mold.
8. **Mold Detail** — Molds are plain `ColorRect` placeholders. No bevel, texture, or depth.
9. **Gate Channel Indicators** — No drawn lines showing the routing path between gates.
10. **Background Depth** — Single flat `ForgeBackground`. No layers, no forge interior detail.
11. **Intake Funnel Shape** — Intakes are plain `ColorRect` rectangles, not funnel shapes.
12. **Padlock Icon Detail** — Simple 3-rectangle padlock; readable but unsophisticated.
13. **UI Button Styling** — All buttons are default Godot style. No themed forge/metal aesthetic.

---

## 3. SUGGESTED COLOR PALETTE

### Background / Atmosphere
| Name | Hex | RGB | Use |
|---|---|---|---|
| Void Black | `#0D0502` | (0.05, 0.02, 0.01) | Main background |
| Forge Dark | `#1A0A04` | (0.10, 0.04, 0.02) | Gradient top |
| Ember Dark | `#28100A` | (0.15, 0.08, 0.04) | Gradient bottom |
| Furnace Glow Core | `#FF6600` | (1.0, 0.4, 0.0) | Bright furnace center |
| Furnace Glow Edge | `#FF3300` | (1.0, 0.2, 0.0) | Warm furnace edge |
| Heat Ambient | `#FF9933` | (1.0, 0.6, 0.2) | Background heat tint |

### Metal Colors — Molten State
| Metal | Hot Stream | Glow | Solid / Cooled |
|---|---|---|---|
| Iron | `#E65500` (orange) | `#FF8019` | `#8C8580` |
| Steel | `#D9E6FF` (silver-white) | `#E6F0FF` | `#BFC9D1` |
| Gold | `#FFF24D` (bright yellow) | `#FFE666` | `#FFD11A` |

### Mold State Colors
| State | Color | Hex |
|---|---|---|
| Filling | Yellow | `#FFFF00` |
| Cooling / Hardening | Orange | `#FF8000` |
| Contaminated | Red | `#FF0000` |
| Complete | Green | `#00FF00` |
| Locked | Dim Gray | `#555555` |

### Ember Particle Colors (layered)
| Layer | Color | Alpha |
|---|---|---|
| Core ember | `#FF4400` | 1.0 |
| Mid flame | `#FF8800` | 0.7 |
| Outer glow | `#FFCC00` | 0.4 |
| Smoke tip | `#442211` | 0.15 |

---

## 4. PARTICLE SPECIFICATIONS — EMBER EFFECT

The existing `EmberParticles` (CPUParticles2D at z=-80) needs expansion into a layered system:

### Layer A — Main Embers (upgrade existing)
| Parameter | Current | Suggested |
|---|---|---|
| Amount | 40 | **80–120** |
| Lifetime | 3.5s | **2.5–4.0s** (randomized) |
| Initial velocity min/max | 30–60 px/s upward | **40–80 px/s**, slight random X drift ±20 |
| Gravity | `(0, -80)` | **`(0, -60)`** — slower rise for larger particles |
| Spread | 30° | **45°** — wider fountain |
| Angular velocity | ±100 | **±150** — more tumble |
| Scale min/max | 1.5–3.5 | **2.0–5.0** — larger embers |
| Color | Single `(1.0, 0.45, 0.1)` | **Gradient: start `#FF4400`, end `#FFCC00`** via `color_ramp` |
| Hue variation | ±0.1 | **±0.15** |
| Lifetime randomness | not set | **0.3** — desync particles |

### Layer B — Spark Bursts (new, short-lived)
| Parameter | Value |
|---|---|
| Node type | CPUParticles2D |
| Position | Near furnace mouth, `(200, 0)` |
| Amount | 20 per burst |
| One-shot | true |
| Lifetime | 0.3–0.6s |
| Emission | Radial burst from center |
| Velocity | 100–200 px/s outward |
| Gravity | `(0, 50)` — slight fall |
| Scale | 0.5–2.0 |
| Color | `#FFFFFF` → `#FF4400` fade |
| Trigger | On pour start (signal `pour_started`) |

### Layer C — Ambient Smoke (new)
| Parameter | Value |
|---|---|
| Node type | CPUParticles2D |
| Position | `(200, -20)` |
| Amount | 15 |
| Lifetime | 5–8s |
| Spread | 60° |
| Velocity | 10–30 px/s upward |
| Gravity | `(0, -10)` — very slow rise |
| Scale | 3.0–8.0 (grows over lifetime) |
| Color | `#221108` at 0.1 alpha → `#000000` at 0.0 alpha |
| One-shot | false |

---

## 5. METAL STREAM GLOW SPECIFICATIONS

### Current State
`PourZone.gd` creates a `Line2D` (width 8–16, solid color) + `ColorRect` glow (pulsing alpha). This is functional but flat.

### Recommended: Glow Shader on Line2D

Create `shaders/molten_glow.gdshader`:

```gdshader
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float glow_width_multiplier : hint_range(1.0, 4.0) = 2.5;

void fragment() {
    // Line2D provides UV.y = 0 at start, 1 at end
    float heat = 1.0 - UV.y; // hotter at top (pour origin)
    vec4 hot_color = glow_color * vec4(1.0 + heat * 0.5, 1.0 + heat * 0.3, 1.0 + heat * 0.2, 1.0);
    float glow = glow_intensity * (0.5 + heat * 0.5);
    COLOR = hot_color * glow;
}
```

### Line2D Parameters
| Property | Iron | Steel | Gold |
|---|---|---|---|
| Width | 10 | 7 | 12 |
| Default color | `#E65500` | `#D9E6FF` | `#FFF24D` |
| Glow shader: glow_color | `#FF8019` | `#E6F0FF` | `#FFE666` |
| Glow shader: glow_intensity | 1.2 | 1.0 | 1.5 |

### Pour Point Glow Blob
Replace the `ColorRect` with a `PointLight2D` or radial-gradient `ColorRect` with softer edges:

| Property | Value |
|---|---|
| Size | `stream_width * 4` diameter |
| Color | Metal glow color |
| Alpha | Pulsing 0.4–0.8 at 2 Hz |
| Blend mode | Additive |

### Stream Width by Metal
| Metal | spread multiplier | base width | stream width |
|---|---|---|---|
| Iron | 1.2 | 8 | **10** |
| Steel | 0.8 | 8 | **6–7** |
| Gold | 1.5 | 8 | **12** |

---

## 6. PRIORITY LIST OF VISUAL IMPROVEMENTS

### P0 — Blocking Bugs
1. **BUG-006 (Polygon2D parse error)** — `PartPopEffect.gd` `spawn_part_pop()` creates `Polygon2D` nodes dynamically. If this is causing a parse error in the scene, it needs investigation. The polygon coordinates look syntactically correct; likely a `.tscn` format issue or resource UID problem.

### P1 — Core Feedback (Required for Playability)
2. **Stream glow shader** — Without a glow effect the stream is flat and hard to track visually. Add `molten_glow.gdshader` to `Line2D`.
3. **Mold fill glow intensity** — `_update_fill_glow()` modulates `modulate.v` but the effect is too subtle. Use a dedicated glow `ColorRect` behind the mold sprite instead of modulating the sprite itself.
4. **Gate open/close animation polish** — Current tween has both `set_ease(EASE_OUT)` and `set_trans(TRANS_ELASTIC)` on rotation, which is correct, but the PointLight2D pops in/out rather than fading.

### P2 — Atmosphere (FEATURE-006 unblocked)
5. **FurnaceAtmosphere node** — Populate the empty `FurnaceAtmosphere` null node with:
   - Furnace mouth shape (trapezoid or curved spout) at `(200, 0)` using `Polygon2D` or `Line2D`
   - Animated heat-shimmer effect (sine-wave offset on UV or position)
   - Core glow using layered `ColorRect` or `PointLight2D`
6. **Ember particle upgrade** — Layer A/B/C system described in Section 4.
7. **Background depth** — Add 2–3 parallax layers behind `ForgeBackground`:
   - Rear: large stone/brick shape silhouettes, very dark
   - Mid: forge structure outline
   - Front: ambient heat haze overlay

### P3 — Molten Stream (FEATURE-007 unblocked)
8. **Stream heat gradient** — Top of stream (pour origin) brighter, bottom dimmer. Use `Line2D.gradient` with a `Gradient` resource: hot color at top, cooler at bottom.
9. **Pour splash at intakes** — On `metal_poured` signal, spawn a brief burst of 5–8 small particles where stream enters the intake funnel.
10. **Intake funnel shape** — Replace `ColorRect` with a `Polygon2D` funnel/trapezoid shape.

### P4 — Polish
11. **Flow channel lines** — Draw subtle guide lines between gates using `Line2D` with low alpha (0.2) to show routing paths.
12. **Mold texture** — Add subtle bevel/highlight effect to mold `ColorRect` using a second `ColorRect` overlay with a gradient or a simple shader.
13. **UI button theming** — Replace default Godot buttons with forge-styled buttons: darker background, orange border, uppercase text.
14. **Screen shake on contamination** — Add a brief `get_tree().root.shake` or viewport offset tween when mold is contaminated.

---

## NOTES

- **FEATURE-006** and **FEATURE-007** design docs do not exist in `docs/`. Once written, they should specify furnace animation timing, ember spawn rates, and stream shader parameters respectively.
- The `Polygon2D` bug (BUG-006) in `PartPopEffect.gd` warrants a dedicated look — while the polygon coordinate literals look correct, dynamic node creation in Godot 4 requires careful UID handling.
- All color values use sRGB `Color()` literals — no `linear_to_srgb()` calls needed for static definitions.
- The game is currently playable but visually a prototype placeholder — the visual pass (Task 6 per the design doc) has not been completed.
