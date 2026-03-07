# Animation and Motion

Animation and motion design for web UIs, Slack GIFs, and PIL-based frame animation. Covers easing functions, animation concepts with implementation patterns, Slack-specific constraints, and graphics quality principles.

---

## Core Animation Concepts

### Shake / Vibrate
Offset object position with oscillation to simulate physical shaking.

```python
import math

# Frame i of num_frames total
t = i / num_frames
amplitude = 8 * (1 - t)  # Decays over time
x_offset = amplitude * math.sin(t * 2 * math.pi * 8)
y_offset = amplitude * math.cos(t * 2 * math.pi * 5)
# Draw object at (base_x + x_offset, base_y + y_offset)
```

**Variations:**
- Add `random.uniform(-1, 1)` scaled by amplitude for organic feel
- Apply to x only (horizontal shake) or both axes (full vibration)
- Use decaying amplitude for impact effect (hit → shake → settle)

---

### Pulse / Heartbeat
Scale object size rhythmically around a base size.

```python
import math

t = i / num_frames
# Smooth pulse: scale oscillates between 0.8 and 1.2
scale = 1.0 + 0.2 * math.sin(t * 2 * math.pi)

# Heartbeat: two quick pulses then pause
# Use a custom waveform
phase = (t * 2) % 1  # Two beats per cycle
if phase < 0.15:
    scale = 1.0 + 0.25 * math.sin(phase / 0.15 * math.pi)
elif phase < 0.35:
    scale = 1.0 + 0.15 * math.sin((phase - 0.15) / 0.20 * math.pi)
else:
    scale = 1.0  # Pause

# Apply: new_size = int(base_size * scale)
```

---

### Bounce
Object falls under gravity and bounces on landing.

```python
# Using easing functions
from core.easing import interpolate

# Fall phase
y = interpolate(start=0, end=base_y, t=t, easing='ease_in')

# Landing with bounce
y = interpolate(start=0, end=base_y, t=t, easing='bounce_out')

# Manual gravity simulation
vy += 0.5  # gravity acceleration per frame
y += vy
if y > floor_y:
    y = floor_y
    vy *= -0.7  # energy loss on bounce
```

---

### Spin / Rotate
Rotate object around its center.

```python
from PIL import Image

angle = (i / num_frames) * 360  # Full rotation
rotated = image.rotate(angle, resample=Image.BICUBIC, expand=False)

# Wobble (oscillating rotation)
angle = 20 * math.sin(t * 2 * math.pi * 2)
rotated = image.rotate(angle, resample=Image.BICUBIC)
```

For PIL shapes, rotate the coordinate points:
```python
def rotate_point(x, y, cx, cy, angle_deg):
    angle = math.radians(angle_deg)
    dx, dy = x - cx, y - cy
    nx = cx + dx * math.cos(angle) - dy * math.sin(angle)
    ny = cy + dx * math.sin(angle) + dy * math.cos(angle)
    return nx, ny
```

---

### Fade In / Out
Gradually appear or disappear by adjusting alpha.

```python
from PIL import Image

# Fade in: alpha 0 → 255
alpha = int(255 * (i / num_frames))

# Fade out: alpha 255 → 0
alpha = int(255 * (1 - i / num_frames))

# Apply to RGBA image
frame_rgba = frame.convert('RGBA')
r, g, b, a = frame_rgba.split()
a = a.point(lambda x: int(x * alpha / 255))
frame_rgba = Image.merge('RGBA', (r, g, b, a))

# Blend between two images
blended = Image.blend(image1, image2, alpha=i/num_frames)
```

---

### Slide
Move object from off-screen to target position with easing.

```python
from core.easing import interpolate

# Slide in from left
start_x = -object_width
end_x = target_x
x = interpolate(start=start_x, end=end_x, t=t, easing='ease_out')

# Slide in from top with overshoot
y = interpolate(start=-object_height, end=target_y, t=t, easing='back_out')

# Slide out to right
x = interpolate(start=current_x, end=canvas_width + object_width, t=t, easing='ease_in')
```

**Easing choice guide:**
- Entering: `ease_out` (fast start, slow finish — feels natural landing)
- Entering with personality: `back_out` (overshoots then settles)
- Exiting: `ease_in` (slow start, fast finish — feels intentional departure)

---

### Zoom
Scale and position for zoom effect.

```python
from PIL import Image

# Zoom in: scale 0.1 → 2.0, crop to canvas size
scale = 0.1 + 1.9 * (i / num_frames)
new_w = int(canvas_w * scale)
new_h = int(canvas_h * scale)
scaled = frame.resize((new_w, new_h), Image.LANCZOS)

# Crop center to canvas size
left = (new_w - canvas_w) // 2
top = (new_h - canvas_h) // 2
cropped = scaled.crop((left, top, left + canvas_w, top + canvas_h))

# Zoom out: scale 2.0 → 1.0
scale = 2.0 - 1.0 * (i / num_frames)
```

---

### Particle Burst / Explode
Particles radiate outward from a center point.

```python
import math, random

class Particle:
    def __init__(self, cx, cy):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(2, 8)
        self.x = cx
        self.y = cy
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed
        self.life = 1.0  # 1.0 = full, 0.0 = dead
        self.decay = random.uniform(0.05, 0.12)
        self.size = random.randint(3, 8)
        self.color = random.choice(palette)

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.vy += 0.3  # gravity
        self.vx *= 0.97  # air resistance
        self.life -= self.decay

    def draw(self, draw):
        if self.life > 0:
            alpha = int(255 * self.life)
            size = int(self.size * self.life)
            r, g, b = self.color
            draw.ellipse(
                [self.x - size, self.y - size, self.x + size, self.y + size],
                fill=(r, g, b, alpha)
            )

# Initialize burst
particles = [Particle(cx, cy) for _ in range(40)]

# Per-frame update
for frame_i in range(num_frames):
    frame = Image.new('RGBA', (w, h), background)
    draw = ImageDraw.Draw(frame)
    for p in particles:
        p.update()
        p.draw(draw)
    frames.append(frame.convert('RGB'))
```

---

## Easing Functions

### Available Easings (from `core.easing`)

```python
from core.easing import interpolate

# t: progress 0.0 to 1.0
value = interpolate(start=0, end=400, t=t, easing='ease_out')
```

| Easing | Shape | Best For |
|---|---|---|
| `linear` | Constant speed | Spinners, progress bars |
| `ease_in` | Slow → fast | Object leaving scene |
| `ease_out` | Fast → slow | Object arriving, settling |
| `ease_in_out` | Slow → fast → slow | Panels opening/closing |
| `bounce_out` | Overshoots + bounces | Playful landing |
| `elastic_out` | Spring overshoot | Notification badges, attention |
| `back_out` | Slight overshoot | Modal appearing, cards sliding in |

### Manual Easing Math

```python
import math

def ease_out(t):
    return 1 - (1 - t) ** 3

def ease_in(t):
    return t ** 3

def ease_in_out(t):
    return 4 * t**3 if t < 0.5 else 1 - (-2*t + 2)**3 / 2

def bounce_out(t):
    if t < 1/2.75:
        return 7.5625 * t * t
    elif t < 2/2.75:
        t -= 1.5/2.75
        return 7.5625 * t * t + 0.75
    elif t < 2.5/2.75:
        t -= 2.25/2.75
        return 7.5625 * t * t + 0.9375
    else:
        t -= 2.625/2.75
        return 7.5625 * t * t + 0.984375

def elastic_out(t):
    c4 = (2 * math.pi) / 3
    if t == 0: return 0
    if t == 1: return 1
    return 2**(-10*t) * math.sin((t*10 - 0.75) * c4) + 1
```

---

## PIL-Based Frame Animation Patterns

### GIFBuilder Workflow

```python
from core.gif_builder import GIFBuilder
from PIL import Image, ImageDraw

builder = GIFBuilder(width=128, height=128, fps=15)

num_frames = 20
for i in range(num_frames):
    t = i / (num_frames - 1)  # 0.0 to 1.0
    frame = Image.new('RGB', (128, 128), (240, 248, 255))
    draw = ImageDraw.Draw(frame)

    # Animation logic here
    y = ease_out(t) * 80 + 20
    draw.ellipse([50, y-10, 78, y+10], fill=(255, 100, 50))

    builder.add_frame(frame)

builder.save('output.gif', num_colors=64, optimize_for_emoji=True)
```

### RGBA Compositing Pattern

For animations with transparency effects:

```python
frame = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
draw = ImageDraw.Draw(frame)

# Draw with alpha
draw.ellipse([20, 20, 60, 60], fill=(255, 100, 50, int(255 * life)))

# Composite onto background
background = Image.new('RGB', (128, 128), (30, 30, 50))
background.paste(frame, mask=frame.split()[3])
```

### Gradient Background

```python
from core.frame_composer import create_gradient_background

# Vertical gradient
bg = create_gradient_background(128, 128, (20, 30, 60), (60, 80, 150))
frame = bg.copy()
draw = ImageDraw.Draw(frame)
```

---

## Slack GIF Constraints

### Dimension Requirements

| GIF Type | Dimensions | Max Duration | File Size Target |
|---|---|---|---|
| Emoji GIF | 128x128 px | Under 3 seconds | < 256KB ideally |
| Message GIF | 480x480 px | No hard limit | < 2MB recommended |

### Parameter Guidelines

| Parameter | Recommended | Notes |
|---|---|---|
| FPS | 10-30 | Lower = smaller file. 12 FPS is a good default |
| Colors | 48-128 | Fewer = smaller. 48 for emoji, 64-128 for message |
| Duration | < 3s for emoji | Longer GIFs loop awkwardly as emoji |

### Validation

```python
from core.validators import validate_gif, is_slack_ready

# Detailed check with output
passes, info = validate_gif('my.gif', is_emoji=True, verbose=True)

# Quick ready check
if is_slack_ready('my.gif'):
    print("Ready to upload to Slack")
```

### Maximum Optimization for Emoji

```python
builder.save(
    'emoji.gif',
    num_colors=48,
    optimize_for_emoji=True,
    remove_duplicates=True  # Removes identical consecutive frames
)
```

---

## Optimization Strategies

Apply these only when file size is a concern (user requests smaller file):

| Strategy | Savings | How |
|---|---|---|
| Reduce FPS | High | 10 FPS instead of 24 — saves ~60% frames |
| Reduce colors | Medium | 48 instead of 128 — significant palette reduction |
| Smaller dimensions | High | 128x128 instead of 480x480 — 14x fewer pixels |
| Remove duplicate frames | Medium | `remove_duplicates=True` — eliminates static holds |
| Shorten duration | High | Fewer frames = smaller file |
| Optimize palette | Low | `optimize_for_emoji=True` applies quantization |

Optimization order: dimensions > duration/FPS > colors > deduplication.

---

## Graphics Quality Principles

Slack GIFs should look polished and creative, not basic. These principles apply to all PIL-based animation:

### Use Thicker Lines

Always set `width=2` or higher for outlines and lines. Thin lines (width=1) look choppy at small dimensions.

```python
draw.ellipse([20, 20, 60, 60], fill=(255, 100, 50), outline=(200, 70, 30), width=3)
draw.line([(10, 64), (118, 64)], fill=(255, 255, 255), width=2)
```

### Add Visual Depth

Layer multiple shapes for complexity:
```python
# Glow effect: draw larger, semi-transparent version behind
draw.ellipse([cx-r-4, cy-r-4, cx+r+4, cy+r+4], fill=(255, 200, 50, 80))  # glow
draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255, 160, 20))                # main shape
draw.ellipse([cx-r+4, cy-r+4, cx+r-4, cy+r-4], fill=(255, 220, 100, 120)) # highlight
```

Use `create_gradient_background()` instead of flat fills.

### Make Shapes More Interesting

Don't draw a plain circle — add highlights, rings, or patterns:
- Stars can have glow halos (draw larger semi-transparent versions behind)
- Combine multiple shapes (star + sparkles, circle + inner ring)
- Use `draw_star()` with custom point ratios for different personalities

### Color and Contrast

- Use vibrant, complementary colors with clear contrast
- Dark outlines on light shapes, light outlines on dark shapes
- Consider the full composition — every frame should be intentionally composed

### Complex Shape Construction

For hearts, snowflakes, or custom shapes:
- Combine polygons and ellipses with calculated coordinates
- Calculate points programmatically for symmetry
- Add details (a heart can have a highlight curve, a star can have inner geometry)

### Combining Animation Concepts

The most compelling GIFs combine multiple techniques:
- Bouncing + rotating (physics-based energy)
- Pulsing + sliding (presence + movement)
- Particle burst + fade (impact + dissipation)
- Shake + zoom (attention-grabbing alert)

---

## CSS Animation Quick Reference (Web UI)

For web UI animation (not PIL/GIF):

```css
/* Standard timing */
.micro-interaction { transition: all 150ms ease-out; }     /* Button press */
.panel-slide       { transition: all 250ms ease-in-out; }  /* Panel open/close */
.modal-appear      { transition: all 300ms cubic-bezier(0.34, 1.56, 0.64, 1); } /* Spring */

/* Always use transform + opacity, never width/height */
.fade-slide-in {
  animation: fadeSlideIn 250ms ease-out forwards;
}
@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* Respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

**Performance rule**: Animate `transform` and `opacity` only. Never animate `width`, `height`, `top`, `left`, `margin`, or `padding` — these trigger layout recalculation and cause jank.
