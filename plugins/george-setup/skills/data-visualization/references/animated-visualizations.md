# Animated Visualizations Reference

PIL-based GIF animation, matplotlib.animation for scientific use, easing functions, and Slack/web optimization.

## Dependencies

```bash
pip install pillow imageio numpy matplotlib
```

---

## PIL Animation Fundamentals

Build GIFs frame-by-frame: create a PIL Image per frame, draw on it with ImageDraw, accumulate frames, save as GIF.

### Core Loop Pattern

```python
from PIL import Image, ImageDraw
import math

WIDTH, HEIGHT = 480, 480
FPS = 20
DURATION = 2.0  # seconds
N_FRAMES = int(FPS * DURATION)

frames = []

for i in range(N_FRAMES):
    t = i / N_FRAMES          # normalized time 0.0 → 1.0
    frame = Image.new('RGBA', (WIDTH, HEIGHT), (240, 248, 255, 255))
    draw = ImageDraw.Draw(frame)

    # --- your animation logic here ---
    # e.g., move a circle
    x = int(WIDTH * t)
    y = HEIGHT // 2
    r = 20
    draw.ellipse([x-r, y-r, x+r, y+r], fill=(0, 102, 255), outline=(0, 0, 128), width=2)

    frames.append(frame.convert('P', palette=Image.ADAPTIVE, colors=64))

# Save as GIF
frames[0].save(
    'animation.gif',
    save_all=True,
    append_images=frames[1:],
    loop=0,              # 0 = infinite loop
    duration=int(1000 / FPS),  # ms per frame
    optimize=True,
)
```

### GIFBuilder Wrapper

When using the slack-gif-creator skill's GIFBuilder utility:

```python
from core.gif_builder import GIFBuilder

builder = GIFBuilder(width=128, height=128, fps=10)

for i in range(12):
    frame = Image.new('RGB', (128, 128), (240, 248, 255))
    draw = ImageDraw.Draw(frame)
    # ... draw frame content ...
    builder.add_frame(frame)

builder.save('emoji.gif', num_colors=48, optimize_for_emoji=True)
```

---

## Drawing Primitives

```python
from PIL import ImageDraw

draw = ImageDraw.Draw(frame)

# Circle / ellipse
draw.ellipse([x1, y1, x2, y2], fill=(r, g, b), outline=(r, g, b), width=3)

# Polygon (stars, triangles, hexagons)
points = [(x1, y1), (x2, y2), (x3, y3)]
draw.polygon(points, fill=(r, g, b), outline=(r, g, b), width=2)

# Line
draw.line([(x1, y1), (x2, y2)], fill=(r, g, b), width=4)

# Rectangle
draw.rectangle([x1, y1, x2, y2], fill=(r, g, b), outline=(r, g, b), width=2)

# Rounded rectangle (Pillow 8+)
draw.rounded_rectangle([x1, y1, x2, y2], radius=10, fill=(r, g, b))
```

---

## Animation Concepts with Code

### Shake / Vibrate

Offset object position with oscillating sine wave. Use `math.sin()` with a multiplied frame index to vary frequency.

```python
import math

def shake_offset(i, n_frames, amplitude=8, frequency=3):
    t = i / n_frames
    x_offset = int(amplitude * math.sin(t * frequency * 2 * math.pi))
    y_offset = int(amplitude * 0.5 * math.cos(t * frequency * 2 * math.pi * 1.3))
    return x_offset, y_offset

for i in range(N_FRAMES):
    frame = Image.new('RGB', (WIDTH, HEIGHT), (255, 255, 255))
    draw = ImageDraw.Draw(frame)
    cx, cy = WIDTH // 2, HEIGHT // 2
    dx, dy = shake_offset(i, N_FRAMES, amplitude=10, frequency=4)
    draw.ellipse([cx+dx-30, cy+dy-30, cx+dx+30, cy+dy+30], fill=(231, 111, 81))
    frames.append(frame)
```

### Pulse / Heartbeat

Scale object size rhythmically between a minimum and maximum radius.

```python
def pulse_radius(i, n_frames, base=30, amplitude=8, frequency=2):
    t = i / n_frames
    return int(base + amplitude * math.sin(t * frequency * 2 * math.pi))

# Heartbeat variant: two quick beats, then pause
def heartbeat_radius(i, n_frames, base=30):
    t = (i / n_frames) % 1.0
    # Beat 1 at t=0.1, Beat 2 at t=0.25, rest
    beat1 = 10 * math.exp(-((t - 0.10) ** 2) / 0.002)
    beat2 = 7  * math.exp(-((t - 0.25) ** 2) / 0.002)
    return int(base + beat1 + beat2)

for i in range(N_FRAMES):
    frame = Image.new('RGB', (WIDTH, HEIGHT), (255, 255, 255))
    draw = ImageDraw.Draw(frame)
    cx, cy = WIDTH // 2, HEIGHT // 2
    r = pulse_radius(i, N_FRAMES)
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(231, 111, 81))
    frames.append(frame)
```

### Bounce

Object falls under gravity and bounces on landing using `bounce_out` easing.

```python
def ease_bounce_out(t):
    if t < 1 / 2.75:
        return 7.5625 * t * t
    elif t < 2 / 2.75:
        t -= 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elif t < 2.5 / 2.75:
        t -= 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else:
        t -= 2.625 / 2.75
        return 7.5625 * t * t + 0.984375

for i in range(N_FRAMES):
    t = i / (N_FRAMES - 1)
    eased = ease_bounce_out(t)
    y = int(50 + eased * (HEIGHT - 100))  # fall from y=50 to y=HEIGHT-50
    frame = Image.new('RGB', (WIDTH, HEIGHT), (245, 243, 237))
    draw = ImageDraw.Draw(frame)
    cx = WIDTH // 2
    r = 25
    draw.ellipse([cx-r, y-r, cx+r, y+r], fill=(74, 124, 89))
    frames.append(frame)
```

### Spin / Rotate

Rotate an object around its center using PIL's `.rotate()` method, or recalculate polygon points with trigonometry.

```python
def rotated_triangle(cx, cy, r, angle_deg):
    """Returns 3 points of an equilateral triangle rotated by angle_deg."""
    points = []
    for k in range(3):
        angle = math.radians(angle_deg + k * 120)
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        points.append((x, y))
    return points

for i in range(N_FRAMES):
    angle = (i / N_FRAMES) * 360  # full rotation
    frame = Image.new('RGBA', (WIDTH, HEIGHT), (30, 30, 30, 255))
    draw = ImageDraw.Draw(frame)
    pts = rotated_triangle(WIDTH//2, HEIGHT//2, 50, angle)
    draw.polygon(pts, fill=(0, 102, 255), outline=(0, 200, 255), width=2)
    frames.append(frame)

# Wobble variant: sine wave for angle instead of linear
for i in range(N_FRAMES):
    t = i / N_FRAMES
    angle = 15 * math.sin(t * 4 * math.pi)  # ±15° wobble, 2 cycles
    # apply rotation to image
    obj = create_object_image(WIDTH, HEIGHT)
    rotated = obj.rotate(angle, resample=Image.BICUBIC, center=(WIDTH//2, HEIGHT//2))
    frames.append(rotated)
```

### Fade In / Out

Adjust alpha channel using `Image.blend` for cross-fades or alpha compositing for layered fades.

```python
def make_fade_sequence(base_image, n_frames, fade_in=True):
    """Returns frames fading from transparent to opaque (or reverse)."""
    background = Image.new('RGBA', base_image.size, (255, 255, 255, 255))
    fade_frames = []
    for i in range(n_frames):
        t = i / (n_frames - 1)
        alpha = t if fade_in else (1 - t)
        frame = Image.blend(background, base_image.convert('RGBA'), alpha)
        fade_frames.append(frame)
    return fade_frames

# Fade in then hold then fade out
frames  = make_fade_sequence(content_img, 10, fade_in=True)
frames += [content_img.copy()] * 20   # hold
frames += make_fade_sequence(content_img, 10, fade_in=False)
```

### Slide

Move object from off-screen to final position with easing.

```python
def ease_out_cubic(t):
    return 1 - (1 - t) ** 3

def ease_out_back(t, overshoot=1.70158):
    t -= 1
    return t * t * ((overshoot + 1) * t + overshoot) + 1

for i in range(N_FRAMES):
    t = i / (N_FRAMES - 1)
    eased = ease_out_back(t)        # slight overshoot for snappy feel
    # Slide in from left
    start_x = -80
    end_x = WIDTH // 2
    x = int(start_x + eased * (end_x - start_x))
    frame = Image.new('RGB', (WIDTH, HEIGHT), (245, 243, 237))
    draw = ImageDraw.Draw(frame)
    draw.ellipse([x-30, HEIGHT//2-30, x+30, HEIGHT//2+30], fill=(244, 169, 0))
    frames.append(frame)
```

### Particle Burst

Radial particles with velocity, gravity, and alpha fade.

```python
import random

class Particle:
    def __init__(self, cx, cy):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(2, 8)
        self.x = float(cx)
        self.y = float(cy)
        self.vx = speed * math.cos(angle)
        self.vy = speed * math.sin(angle)
        self.life = 1.0
        self.decay = random.uniform(0.04, 0.09)
        self.r = random.randint(3, 8)
        self.color = random.choice([(231,111,81), (244,162,97), (249,166,32)])

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.vy += 0.3  # gravity
        self.life -= self.decay

GRAVITY = 0.3
particles = [Particle(WIDTH//2, HEIGHT//2) for _ in range(40)]

for i in range(N_FRAMES):
    frame = Image.new('RGBA', (WIDTH, HEIGHT), (30, 30, 30, 255))
    draw = ImageDraw.Draw(frame)

    for p in particles:
        if p.life > 0:
            alpha = int(255 * max(0, p.life))
            color = p.color + (alpha,)
            r = p.r
            draw.ellipse([p.x-r, p.y-r, p.x+r, p.y+r], fill=color)
            p.update()

    frames.append(frame.convert('RGB'))
```

---

## Easing Functions

All easing functions take `t` in [0, 1] and return a value in [0, 1] (approximately — some overshoot).

```python
import math

def ease_linear(t):
    return t

def ease_in_quad(t):
    return t * t

def ease_out_quad(t):
    return 1 - (1 - t) ** 2

def ease_in_out_quad(t):
    return 2*t*t if t < 0.5 else 1 - (-2*t + 2)**2 / 2

def ease_in_cubic(t):
    return t ** 3

def ease_out_cubic(t):
    return 1 - (1 - t) ** 3

def ease_in_out_cubic(t):
    return 4*t**3 if t < 0.5 else 1 - (-2*t + 2)**3 / 2

def ease_out_bounce(t):
    n1, d1 = 7.5625, 2.75
    if t < 1/d1:    return n1 * t * t
    elif t < 2/d1:  t -= 1.5/d1;  return n1*t*t + 0.75
    elif t < 2.5/d1: t -= 2.25/d1; return n1*t*t + 0.9375
    else:           t -= 2.625/d1; return n1*t*t + 0.984375

def ease_out_elastic(t, amplitude=1.0, period=0.3):
    if t == 0 or t == 1: return t
    s = period / (2 * math.pi) * math.asin(1 / amplitude)
    return amplitude * (2**(-10*t)) * math.sin((t - s) * (2*math.pi) / period) + 1

def ease_out_back(t, overshoot=1.70158):
    return 1 + (overshoot + 1) * (t - 1)**3 + overshoot * (t - 1)**2

# Generic interpolator
def interpolate(start, end, t, easing='ease_out'):
    easings = {
        'linear': ease_linear,
        'ease_in': ease_in_quad,
        'ease_out': ease_out_quad,
        'ease_in_out': ease_in_out_quad,
        'bounce_out': ease_out_bounce,
        'elastic_out': ease_out_elastic,
        'back_out': ease_out_back,
    }
    eased = easings.get(easing, ease_out_quad)(t)
    return start + eased * (end - start)
```

### Choosing an Easing

| Effect | Easing | Use case |
|--------|--------|----------|
| Natural deceleration | `ease_out_quad` | Slides, drops landing |
| Dramatic settling | `ease_out_cubic` | Panels sliding into view |
| Playful overshoot | `ease_out_back` | Notifications, badges |
| Physical bounce | `ease_out_bounce` | Balls, dropped objects |
| Springy jolt | `ease_out_elastic` | Button presses, toggles |
| Building momentum | `ease_in_cubic` | Objects falling, departing |
| Smooth loop | `ease_in_out_quad` | Continuously oscillating elements |

---

## GIF Optimization

Size reduction strategies (apply in order of impact):

| Strategy | How | Typical saving |
|----------|-----|---------------|
| Reduce frame count | Lower FPS (10 vs 30) or shorten duration | 50-70% |
| Reduce color palette | `num_colors=48` vs 256 | 20-40% |
| Reduce dimensions | 128x128 vs 480x480 | 75% |
| Remove duplicate frames | `remove_duplicates=True` | 5-15% |
| Optimize palette | `optimize=True` in PIL save | 5-10% |

```python
# Maximum optimization for Slack emoji
frames[0].save(
    'emoji.gif',
    save_all=True,
    append_images=frames[1:],
    loop=0,
    duration=100,      # 10 FPS
    optimize=True,
    colors=48,         # PIL color count hint
)

# Using imageio for more control
import imageio
imageio.mimsave(
    'animation.gif',
    [frame for frame in frames],
    fps=15,
    loop=0,
    palettesize=64,
    subrectangles=True,   # only encode changed region per frame
)
```

---

## Slack GIF Constraints

| Context | Dimensions | FPS | Max duration | Colors |
|---------|-----------|-----|-------------|--------|
| Custom emoji | 128 x 128 | 10-15 | 3 seconds | 48 |
| Message attachment | 480 x 480 | 10-30 | Any | 128 |

```python
SLACK_EMOJI   = {'width': 128, 'height': 128, 'fps': 10, 'colors': 48}
SLACK_MESSAGE = {'width': 480, 'height': 480, 'fps': 20, 'colors': 128}

# Validate before sending
def validate_slack_gif(path: str, is_emoji: bool = True) -> dict:
    from PIL import Image
    import os
    img = Image.open(path)
    w, h = img.size
    n_frames = getattr(img, 'n_frames', 1)
    file_kb = os.path.getsize(path) / 1024
    constraints = SLACK_EMOJI if is_emoji else SLACK_MESSAGE
    return {
        'size_ok': w == constraints['width'] and h == constraints['height'],
        'file_size_kb': file_kb,
        'n_frames': n_frames,
        'passes': w == constraints['width'] and h == constraints['height'],
    }
```

---

## matplotlib.animation for Scientific Use

Use `FuncAnimation` for data-driven animations (time series progression, algorithm visualization, physics simulations).

```python
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np

fig, ax = plt.subplots(figsize=(8, 6))
ax.set_xlim(0, 10)
ax.set_ylim(-2, 2)
line, = ax.plot([], [], lw=2, color='#0066ff')

x_data, y_data = [], []

def init():
    line.set_data([], [])
    return (line,)

def animate(i):
    x = np.linspace(0, 10, 500)
    y = np.sin(x - 0.1 * i)   # phase shift per frame
    line.set_data(x, y)
    return (line,)

ani = animation.FuncAnimation(
    fig, animate, init_func=init,
    frames=100, interval=50,   # 50ms = 20 FPS
    blit=True                  # only redraw changed artists (faster)
)

# Save to GIF
ani.save('sine_wave.gif', writer='pillow', fps=20, dpi=80)

# Save to MP4 (requires ffmpeg)
ani.save('sine_wave.mp4', writer='ffmpeg', fps=20, dpi=150)

plt.close(fig)
```

### Scientific Animation Patterns

```python
# Scatter plot with evolving data (e.g., agent positions over time)
scat = ax.scatter([], [], s=20, c='steelblue', alpha=0.6)

def animate_scatter(i):
    positions = compute_positions_at_step(i)  # returns (x_array, y_array)
    scat.set_offsets(np.column_stack(positions))
    ax.set_title(f"Step {i}")
    return (scat,)

# Heatmap evolution (e.g., diffusion simulation)
im = ax.imshow(initial_grid, cmap='viridis', animated=True)

def animate_heatmap(i):
    grid = simulation_step(i)
    im.set_array(grid)
    im.autoscale()
    return (im,)
```

### PIL vs matplotlib.animation

| Criterion | PIL GIFs | matplotlib.animation |
|-----------|----------|----------------------|
| Output type | GIF | GIF, MP4, HTML |
| Best for | Creative/Slack GIFs, custom graphics | Scientific data, plots |
| Flexibility | Full pixel control | Limited to matplotlib primitives |
| Performance | Manual per-frame | blit=True handles optimization |
| File size control | Full (color count, FPS) | Limited |
| Complexity | Build from scratch | Handled by API |
| Dependencies | Pillow only | matplotlib + ffmpeg (for MP4) |

Use PIL when you need creative control over every pixel (Slack GIFs, custom graphics, non-data art).
Use `matplotlib.animation` when you're animating existing matplotlib plots (time series, simulations, algorithm visualization).
