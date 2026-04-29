# FEATURE-006: Forge Atmosphere
**Status:** P0 / Blocked (needs design doc)  
**Design Doc Version:** 1.0  
**Created:** 2026-04-29

---

## 1. Visual Description

The forge atmosphere creates a dark, warm, industrial mood for the game. When the player looks at the screen they see:

- **Background:** A near-black warm brown canvas (`Color(0.05, 0.02, 0.01)`) filling the entire viewport.
- **Furnace glow:** A large radial orange-red glow emanating from the top-center of the screen (furnace position at approximately `200, -30`). The glow pulses slowly — brightening and dimming on a ~2.5 second sine-wave cycle. The glow has a soft feathered edge (bright orange at center fading to transparent).
- **Ember particles:** 30–50 ember particles continuously rise from the furnace area. Each ember is a small orange-red dot that drifts upward with slight horizontal sway, fading as it rises. Embers vary in size (1.5x–3.5x scale) and have a subtle flicker/hue shift.
- **Depth layering:** The atmosphere renders behind all game elements (z_index -100 to -80), so gameplay elements (molds, gates, UI) always appear on top.

The overall mood: oppressive industrial forge, hot metal glowing in darkness, heat shimmer implied by the pulsing glow.

---

## 2. Technical Approach

### 2.1 Node Structure (additions to `Main.tscn`)

The scene already contains a partial atmosphere setup:

| Existing Node | Purpose |
|---|---|
| `ForgeBackground` (ColorRect) | Dark base — KEEP |
| `FurnaceGlow/ColorRect` | Placeholder glow — REPLACE with RadialGradientFill |
| `EmberParticles` (CPUParticles2D) | Functional ember system — TUNE parameters |
| `FurnaceAtmosphere` (Node) | Empty placeholder — TURN INTO a sub-scene |

**Recommended new node tree:**
```
FurnaceAtmosphere (Node2D, z=-90)
  ├── FurnaceGlowShader (Node2D)
  │   └── GlowSprite (Sprite2D)          # radial gradient texture, shader-driven pulse
  └── EmberEmitter (Node2D, z=-80)
      └── EmberParticles (CPUParticles2D) # existing node, retune
```

### 2.2 Dark Background — ForgeBackground (existing, minor tuning)

The `ForgeBackground` ColorRect at z=-100 already provides the dark base. No structural change needed.

**Minor improvement:** The background color could add a subtle vertical gradient — slightly warmer/redder at the top (near furnace) and slightly cooler/darker at the bottom (near molds) — to imply heat dissipating with distance. This can be done by:
- Adding a `GradientRect` (top-to-bottom gradient) as a child of `ForgeBackground`, slightly lighter at top.
- Or via a shader on `ForgeBackground`.

**Recommended color ramp:**
- Top (near furnace): `Color(0.08, 0.04, 0.02)` — faint warm ember glow
- Bottom (near molds): `Color(0.02, 0.01, 0.01)` — near black

### 2.3 Furnace Glow Effect — Shader-based radial glow

Replace the static `FurnaceGlow/ColorRect` with a `Sprite2D` using a `RadialGradientTexture` and a custom **glow pulse shader**.

**Why a shader?**
- Smooth alpha animation for pulsing without CPU tweening
- Natural radial falloff (ColorRect can't feather edges)
- Easy to extend with noise for heat shimmer

**Glow Shader (GDScript fragment):**
```gdscript
# shaders/forge_glow.gdshader
shader_type canvas_item;

uniform float pulse_phase : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_speed = 0.8;        // cycles per second (~2.5s period)
uniform vec4 glow_color : source_color = vec4(1.0, 0.4, 0.05, 1.0);
uniform float glow_radius = 0.5;

void fragment() {
    // Radial distance from center (0=center, 1=edge)
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) / glow_radius;
    
    // Feathered radial falloff
    float alpha = 1.0 - smoothstep(0.0, 1.0, dist);
    alpha = pow(alpha, 1.5); // sharpen falloff
    
    // Pulse: range 0.4–0.8 alpha
    float pulse = (sin(TIME * pulse_speed * 6.28318) + 1.0) * 0.2 + 0.4;
    
    COLOR = glow_color * alpha * pulse;
    COLOR.a *= alpha * pulse;
}
```

**Node setup:**
- `FurnaceGlowShader` (Node2D, z=-90, position `200, -30`)
  - `GlowSprite` (Sprite2D)
    - texture: a small (e.g. 64x64) `RadialGradientTexture` (filled, no hollow)
    - centered, scale ~`Vector2(600, 400)` to cover upper screen area
    - modulate color: `Color(1.0, 0.5, 0.1)` base tint

**Animation:** The shader handles pulsing internally via `TIME`. The C# / GDScript does NOT need to animate anything — shader runs on GPU.

**Existing GameController code:** The current `_process` animation of `FurnaceGlow/GlowGradient.modulate.a` should be **removed** (lines 117-121 in GameController.gd reference `FurnaceGlow/GlowGradient`). This is replaced by the shader.

### 2.4 Ember Particles — CPUParticles2D (existing, retune)

The existing `EmberParticles` node (CPUParticles2D, z=-80) already emits orange particles upward. The parameters need tuning.

**Suggested new parameters:**
| Parameter | Current | Suggested | Notes |
|---|---|---|---|
| `amount` | 40 | 35 | Slight reduction for performance |
| `lifetime` | 3.5 | 4.0 | Embers live longer, drift further |
| `spread` | 30.0 | 45.0 | Wider horizontal spread |
| `gravity` | `Vector2(0, -80)` | `Vector2(0, -60)` | Gentler rise, more floaty |
| `initial_velocity_min` | 30.0 | 20.0 | Slower base rise |
| `initial_velocity_max` | 60.0 | 40.0 | Smaller velocity range |
| `angular_velocity_min/max` | -100/100 | -50/50 | Less spin |
| `linear_accel_min/max` | -20/-50 | -10/-30 | Decelerate as they rise |
| `color` | `Color(1.0, 0.45, 0.1, 1.0)` | `Color(1.0, 0.5, 0.1, 1.0)` | Slightly brighter |
| `hue_variation_min/max` | -0.1/0.1 | -0.08/0.08 | Tighter hue range |
| `anim_speed_min/max` | 0.5/1.5 | 0.8/2.0 | Faster flicker for smaller embers |
| `scale_amount_min/max` | 1.5/3.5 | 1.0/2.5 | Smaller embers (more like real embers) |
| `scale_curve` | — | custom | Embers shrink as they age (fade out) |

**Ember color:** Orange-red `Color(1.0, 0.45, 0.12)` with slight yellow tinge `Color(1.0, 0.6, 0.15)` as variation.

**Emission point:** The emitter position should be at furnace height (`200, 0`) but the emission rectangle should be wide (`spread=45`) to look like a wide furnace mouth.

### 2.5 Heat Distortion / Darkening Overlay (optional enhancement)

A subtle `ColorRect` overlay at z=-85 can darken the lower portion of the screen (near molds) to imply cooler air. This creates visual depth:
- Upper screen (furnace area): transparent
- Lower screen (mold area): `Color(0, 0, 0, 0.3)` — slight black vignette from bottom

**Parameters:**
- Full-screen ColorRect, z=-85
- Uses a vertical gradient texture: top=transparent, bottom=`Color(0,0,0,0.35)`
- No interaction, purely atmospheric

---

## 3. Specific Parameter Summary

### Furnace Glow Shader
```
pulse_speed: 0.8  (0.8 Hz → ~1.25s half-period → full cycle ~2.5s)
glow_color: Color(1.0, 0.4, 0.05)  (orange-red)
glow_radius: 0.5 (UV space, half the sprite)
sprite scale: Vector2(600, 400) centered at (200, -30)
```

### Ember Particles
```
amount: 35
lifetime: 4.0s
spread: 45°
gravity: Vector2(0, -60)
initial_velocity: 20–40 px/s
angular_velocity: -50 to 50 °/s
linear_accel: -10 to -30
color: Color(1.0, 0.5, 0.12)
hue_variation: -0.08 to 0.08
anim_speed: 0.8 to 2.0
scale: 1.0 to 2.5
emitter position: (200, 0)
```

### Heat Darkening Overlay (optional)
```
z_index: -85
top of screen: fully transparent
bottom of screen: Color(0,0,0,0.35)
```

---

## 4. Compatibility Notes

### Complements
- **PourZone stream** (FEATURE-007): The dark forge background makes the molten metal stream glow and ember particles pop visually. The warm orange atmosphere palette matches the molten metal colors.
- **Mold visuals:** The dark atmospheric background with orange glow makes the dark brown mold sprites readable without contrast issues.
- **OrderPanel / UI:** The warm-dark atmosphere does not conflict with the UI (UI renders above z=0).

### Conflicts / Risks
- **Performance:** CPUParticles2D with 35 particles + shader-based glow is lightweight. However, if the game targets very low-end devices, consider switching `EmberParticles` from CPUParticles2D to GPUParticles2D with a simple particle material. The shader is already GPU-based so adds minimal CPU cost.
- **Existing GameController animation:** The current `_process` code that animates `FurnaceGlow/GlowGradient.modulate.a` (lines ~117-121) must be removed when the shader-based glow is activated, otherwise there will be double-animation (shader + tween competing).
- **Existing `FurnaceAtmosphere` node:** The empty `FurnaceAtmosphere` Node under `FurnaceGlow` should be repurposed as the new parent for the shader-based glow, or removed if the new structure is used.
- **Color contrast with mold fill:** The atmosphere's warm orange tint should not be so strong that it washes out the mold fill progress bars or gate toggle UI. Keep glow alpha below 0.8 even at peak.

### Interaction with FEATURE-007
The atmosphere provides the dark "stage" on which FEATURE-007's molten metal stream performs. The two features are independent in code but visually inseparable — the stream glow will layer on top of the furnace glow. Ensure stream glow colors harmonize with the furnace glow palette (iron=orange, steel=white, gold=yellow).

---

## 5. Acceptance Criteria

1. Dark forge background visible on game start, before any gameplay
2. Furnace glow pulses smoothly every ~2.5 seconds without stutter
3. Ember particles continuously rise from furnace area, fade as they climb
4. All atmosphere elements render behind gameplay elements (correct z_index)
5. No duplicate animations (old tween-based glow removed when shader activated)
6. Performance: stable 60 FPS with atmosphere active
