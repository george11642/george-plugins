# Algorithmic Design Patterns

Algorithmic philosophies are computational aesthetic movements expressed through code. This document covers the full process: from manifesto creation through p5.js implementation, including seeded randomness patterns, parameter design, and craftsmanship standards.

---

## The Two-Step Process

1. **Algorithmic Philosophy Creation** — Write a manifesto for a generative art movement (4-6 paragraphs), output as `.md`
2. **p5.js Implementation** — Express the philosophy through code as a self-contained interactive HTML artifact

The philosophy is not a spec or a style guide. It is a computational worldview — a stance about how beauty emerges from process, randomness, and mathematical relationships. The code is a direct expression of that worldview.

---

## How to Write an Algorithmic Philosophy

### Step 1: Name the Movement (1-2 words)

The name should feel like a computational art movement, not a description of what the algorithm does:

- "Organic Turbulence" — not "Perlin Noise Flow Fields"
- "Quantum Harmonics" — not "Wave Interference Pattern"
- "Recursive Whispers" — not "Fractal Tree Generator"
- "Stochastic Crystallization" — not "Voronoi With Randomness"
- "Field Dynamics" — not "Particle Vector Field"

### Step 2: Write the Manifesto (4-6 Paragraphs)

Capture the algorithmic essence: how does this philosophy manifest through code? Each paragraph addresses a different computational dimension.

**Questions to answer in the manifesto:**
- What computational processes and mathematical relationships drive this system?
- How do noise functions and randomness patterns behave?
- What particle behaviors, field dynamics, or force interactions are at work?
- How does the system evolve temporally?
- What parametric variations produce emergent complexity?

**Critical guidelines:**

- **Avoid redundancy**: Each algorithmic aspect mentioned once. Do not repeat points about noise theory, particle dynamics, or mathematical principles.
- **Emphasize craftsmanship repeatedly**: Use phrases like "meticulously crafted algorithm," "the product of deep computational expertise," "painstaking optimization," "master-level implementation" — more than once. This is not cliché; it primes the implementation stage to produce exceptional work.
- **Leave creative space**: Specific enough to guide implementation decisions, general enough that the implementer makes high-craft interpretive choices.
- **Process over product**: Emphasize that beauty lives in the algorithm's execution, not in a final static frame.

---

## Eight Philosophy Examples

### "Organic Turbulence"
**Philosophy**: Chaos constrained by natural law; order emerging from disorder.

**Algorithmic expression**: Flow fields driven by layered Perlin noise. Thousands of particles follow vector forces, their trails accumulating into organic density maps. Multiple noise octaves create turbulent regions and calm zones that shift with time. Color emerges from velocity and density — fast particles burn bright, slow ones fade to shadow, creating chromatic maps of invisible forces.

**System dynamics**: The algorithm runs until equilibrium — a meticulously tuned balance where turbulent regions have accumulated enough density to appear as dark organic masses while calm zones retain the luminosity of sparse trails. Every noise parameter was refined through countless iterations.

**Craftsmanship standard**: The result must look like the product of deep computational aesthetics expertise — the kind of flow field that makes viewers wonder how long the artist spent tuning parameters. Meticulous. Inevitable. As if the particles had no other choice.

---

### "Quantum Harmonics"
**Philosophy**: Discrete entities exhibiting wave-like interference patterns.

**Algorithmic expression**: Particles initialized on a grid, each carrying a phase value that evolves through sine waves with individual frequencies. When particles approach each other, their phases interfere — constructive interference creates bright nodes, destructive interference creates voids. The interference patterns are not computed directly but emerge from thousands of individual particle interactions.

**System dynamics**: Simple harmonic motion at the micro scale generates complex emergent geometry at the macro scale — mandalas, lattices, and radial symmetries that no single particle could produce. The frequency ratios between particles determine the complexity of the interference patterns.

**Craftsmanship standard**: Every frequency ratio was carefully chosen to produce resonant beauty. The parameter space was explored systematically. The result is a meticulously calibrated system where the emergent patterns feel both discovered and inevitable.

---

### "Recursive Whispers"
**Philosophy**: Self-similarity across scales; infinite depth in finite space.

**Algorithmic expression**: Branching structures that subdivide recursively. Each branch is slightly randomized but constrained by golden ratios and fibonacci angles. L-systems or recursive subdivision generate tree-like forms that feel both mathematical and organic. Subtle Perlin noise perturbations break perfect symmetry at each level. Line weights diminish with each recursion level, mirroring the way fine capillaries fade from arteries.

**System dynamics**: The recursion terminates at a minimum line width threshold, creating natural visual leaf-level detail. The branching angles are derived from natural growth patterns — the same ratios found in phyllotaxis and leaf venation.

**Craftsmanship standard**: Every branching angle is the product of deep mathematical exploration. The resulting structures should feel like they were grown, not generated — the mark of a master-level generative algorithm applied with painstaking care.

---

### "Field Dynamics"
**Philosophy**: Invisible forces made visible through their effects on matter.

**Algorithmic expression**: Vector fields constructed from combinations of mathematical functions — attractors, repellers, vortices, and saddle points. Particles are born at canvas edges and flow along field lines, dying when they reach equilibrium positions or canvas boundaries. Only the traces remain: ghost-like evidence of invisible forces. Multiple fields can be superimposed with different weights.

**System dynamics**: The visualization shows only residue — the accumulated paths of particles that have completed their journeys. Denser regions indicate areas where field lines converge; sparse regions reveal saddle points and unstable equilibria. The final composition is a phase portrait of the invisible field.

**Craftsmanship standard**: A computational dance meticulously choreographed through force balance equations. The field parameters were tuned until the resulting composition has both mathematical correctness and aesthetic beauty — two qualities that, in the best generative work, are the same thing.

---

### "Stochastic Crystallization"
**Philosophy**: Random processes crystallizing into ordered structures.

**Algorithmic expression**: Randomized circle packing or Voronoi tessellation, evolved through Lloyd's relaxation algorithm. Start with random seed points; let them push apart through iterative relaxation until the system reaches equilibrium. Cells are colored based on area, neighbor count, distance from center, or proximity to attractor points. The organic tiling that emerges feels both random and inevitable.

**System dynamics**: The relaxation process is animated — viewers can watch disorder crystallize into order. The final frame is the equilibrium state, but the process of reaching it is as beautiful as the destination.

**Craftsmanship standard**: Every seed produces unique crystalline beauty — the mark of a master-level generative algorithm where randomness and structure have been balanced with expert precision. The parameter tuning is meticulous; no two seeds produce the same crystalline form, yet every seed produces something worth examining.

---

### "Emergent Stillness"
**Philosophy**: Motion that accumulates into apparent rest; the trace of movement as the artwork itself.

**Algorithmic expression**: Long-exposure computational photography. Hundreds of particles follow complex paths — chaotic initially, gradually damping toward attractors. Each frame adds a thin, semi-transparent stroke. After thousands of iterations, the accumulated strokes reveal the underlying attractor geometry that was invisible in any single frame.

**System dynamics**: The artwork only fully exists after the algorithm has run to completion. Early frames show chaos; middle frames show structure emerging; final frames show the attractor geometry revealed by accumulated trails. The composition is not designed — it is discovered through patient algorithmic observation.

**Craftsmanship standard**: The system parameters were tuned so that the accumulation process produces a composition with visual hierarchy, balance, and depth. The result must feel like a scientific finding, not a random output — as if the algorithm discovered something true about the mathematics underlying the attractor.

---

### "Geometric Entropy"
**Philosophy**: Perfect order degrading through controlled randomness; the beauty of systematic imperfection.

**Algorithmic expression**: Begin with a perfect geometric structure — a grid, a tiling, a mandala. Apply progressive distortion controlled by Perlin noise, with distortion intensity increasing from center to edge or from top to bottom. The original structure remains legible in some regions while dissolving into organic complexity in others. The boundary between order and chaos is the most visually interesting zone.

**System dynamics**: The distortion is layered — multiple noise octaves at different scales create both large-scale warping and fine-grain texture. Color shifts systematically with distortion level: ordered regions retain cool, precise tones; chaotic regions develop warm, complex hues.

**Craftsmanship standard**: The transition between order and entropy was calibrated with meticulous precision. The boundary zone is where master-level generative work lives — neither fully controlled nor fully random, but in a state of productive tension that required deep expertise to achieve.

---

### "Chromatic Accumulation"
**Philosophy**: Color as accumulated history; the canvas as a record of process.

**Algorithmic expression**: Thousands of semi-transparent geometric primitives — circles, lines, triangles — placed according to rules derived from noise fields or mathematical functions. Each primitive adds a thin layer of color. The final image is the sum of all additions: areas of convergence become saturated and opaque; areas of divergence remain pale and transparent.

**System dynamics**: Color accumulates according to the same rules that determine placement — shapes placed densely in certain regions create deep, complex color; sparse regions reveal only the faintest traces. The composition has a natural depth because depth was never designed — it emerged from the accumulation rules.

**Craftsmanship standard**: The placement rules, transparency values, and color choices were refined through systematic iteration. The resulting depth and color complexity must feel like the product of careful curation, not algorithmic accident.

---

## The Conceptual Seed Principle

Before implementing any algorithm, identify the subtle conceptual thread from the user's request.

**The principle**: The concept is a subtle, niche reference embedded within the algorithm — not always literal, always sophisticated. Someone familiar with the subject should feel it intuitively, while others simply experience a masterful generative composition. The algorithmic philosophy provides the computational language. The deduced concept provides the soul — the quiet conceptual DNA woven invisibly into parameters, behaviors, and emergence patterns.

**This is very important**: The reference must be so refined that it enhances the work's depth without announcing itself. Think like a jazz musician quoting another song through algorithmic harmony — only those who know will catch it, but everyone appreciates the generative beauty.

---

## Parameter Design Methodology

**Core principle**: Parameters emerge from the philosophy, not from a menu of options.

The question is never "what parameters should I expose?" The question is: "What qualities of *this particular system* can be meaningfully adjusted?"

### How to Design Parameters

1. **Read the philosophy**: What are the system's key forces, quantities, and behavioral thresholds?
2. **Identify the tunable dimensions**: What can be more/less, faster/slower, larger/smaller without breaking the philosophical intent?
3. **Name parameters for their meaning, not their implementation**: `turbulence` not `noiseScale`, `crystallinity` not `relaxationIterations`

### Parameter Categories to Consider

```javascript
let params = {
  seed: 12345,        // ALWAYS include — reproducibility is non-negotiable

  // Quantities: how many entities?
  // particleCount, branchDepth, seedPoints

  // Scales: how big, how fast?
  // noiseScale, timeScale, fieldStrength

  // Probabilities: how likely is a behavior?
  // branchProbability, turbulenceChance

  // Ratios: what proportions govern the system?
  // goldenRatio, branchAngle, colorBalance

  // Thresholds: when does behavior change state?
  // equilibriumThreshold, minimumLineWidth, colorSaturationCutoff

  // Colors: palette choices for the system
  // backgroundColor, primaryColor, accentColor
};
```

**Never**: Build a parameter list by thinking "what sliders would be fun to have?" Build it by thinking "what does this specific algorithm need to be expressive?"

---

## Seeded Randomness Best Practices

**ALWAYS use a seed. No exceptions.**

Reproducibility is a core property of quality generative art. A work that cannot be reproduced at will is a prototype, not an artwork. Seeded randomness allows:
- Revisiting specific outputs by seed number
- Systematic exploration of parameter space
- Sharing a specific seed number instead of a file

### The Art Blocks Pattern

```javascript
// Seed management — always at top level
let seed = 12345;

function setup() {
  createCanvas(1200, 1200);
  randomSeed(seed);   // p5.js random()
  noiseSeed(seed);    // p5.js noise()
}

// When seed changes (prev/next/random buttons):
function applySeed(newSeed) {
  seed = newSeed;
  randomSeed(seed);
  noiseSeed(seed);
  redraw(); // or loop() + noLoop() to re-render
}
```

### Seed Navigation UI (Required)

Every interactive artifact includes seed navigation:
- Display current seed number prominently
- Previous / Next buttons (decrement/increment)
- Random button (pick any seed)
- Jump-to-seed input field + Go button

Same seed always produces identical output. This is not optional.

---

## Template-First Development

**CRITICAL: Before writing any HTML, read `templates/viewer.html`.**

The template provides:
- Anthropic-branded UI shell (colors, fonts, layout)
- Sidebar structure (Seed section, Parameters section, Colors section, Actions section)
- Seed navigation controls (pre-wired, functional)
- Action buttons (Regenerate, Reset, Download PNG)

**Fixed sections (never change):**
- Layout structure: header, sidebar, main canvas area
- Anthropic branding: Poppins/Lora fonts, light colors, gradient backdrop
- Seed section: seed display + prev/next/random/jump controls
- Actions section: regenerate, reset, download buttons

**Variable sections (customize per artwork):**
- The entire p5.js algorithm (setup/draw/classes)
- The `params` object
- Parameter controls in sidebar (sliders, inputs)
- Colors section (optional — only if artwork needs user-adjustable colors)

The process:
1. Read `templates/viewer.html`
2. Copy the exact structure
3. Replace only the variable sections with the new algorithm and controls
4. Do NOT rebuild the UI from scratch

---

## p5.js Implementation: Core Structure

### Canvas Setup

```javascript
function setup() {
  createCanvas(1200, 1200);
  randomSeed(seed);
  noiseSeed(seed);
  // Initialize system state
  background(params.backgroundColor);
}

function draw() {
  // For animated works: update system state, render frame
  // For static works: render once, then noLoop()
}
```

### Expressing Philosophy Through Code

The philosophy dictates the algorithm. Avoid the question "which pattern should I use?" Ask instead: "How do I express this philosophy through code?"

| Philosophy Theme | Code Approach |
|---|---|
| Organic emergence | Accumulated growth, feedback loops, natural rules |
| Mathematical beauty | Geometric relationships, trigonometric functions, precise ratios |
| Controlled chaos | Random variation within strict boundaries, bifurcation |
| Field dynamics | Vector fields, particle traces, force equations |
| Self-similarity | Recursion, L-systems, subdivision |
| Wave interference | Sine/cosine superposition, phase relationships |
| Crystallization | Relaxation algorithms, Voronoi, packing |
| Accumulation | Semi-transparent layering, density mapping |

### Color Harmony Patterns

Never assign random RGB values. Use intentional palette strategies:

```javascript
// Palette from philosophy
const palette = {
  deep: color(15, 20, 40),
  mid: color(45, 60, 120),
  bright: color(180, 200, 255),
  accent: color(255, 140, 60)
};

// Color from system state (velocity, density, position)
function velocityColor(v, maxV) {
  let t = v / maxV; // 0 to 1
  return lerpColor(palette.deep, palette.bright, t);
}

// HSBA for systematic color variation
function systemColor(angle, intensity) {
  colorMode(HSB, 360, 100, 100, 100);
  return color(angle % 360, 70, intensity * 100, 80);
}
```

---

## Craftsmanship Requirements

**CRITICAL**: Create algorithms that feel like they emerged through countless iterations by a master generative artist. The standard is not "working code" — it is "gallery-quality computational art."

### Required Properties

**Balance**: Complexity without visual noise. The composition must have regions of density and regions of breathing room. Unrelieved complexity is visual chaos; unrelieved sparsity is emptiness. The best generative work has both.

**Color Harmony**: Thoughtful palettes derived from the philosophy. Not random RGB. Not stock Tailwind colors. Colors that were chosen because they serve the system's meaning.

**Composition**: Even in randomness, the composition should have visual hierarchy — a sense of where the eye enters, where it travels, where it rests. This emerges from parameter tuning, not accident.

**Performance**: Smooth execution. If animated, target 30+ FPS. If computationally heavy, use noLoop() and render to a graphics buffer.

**Reproducibility**: Same seed always produces identical output. This is tested before delivery.

### The Craftsmanship Test

The final artifact should feel like it:
- Took countless hours to create
- Was refined through systematic iteration
- Was produced by someone at the absolute top of their field in computational aesthetics
- Could be shown to any audience as evidence of deep expertise

If it doesn't pass this test, tune parameters further before delivering.

---

## Output Format

Every algorithmic art task produces:

1. **Algorithmic Philosophy** — As `.md` or text output, 4-6 paragraphs
2. **Single HTML Artifact** — Self-contained, built from `templates/viewer.html`

The HTML artifact contains everything:
- p5.js loaded from CDN (`https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.7.0/p5.min.js`)
- The complete algorithm (setup, draw, classes)
- Parameter controls (sidebar sliders/inputs)
- Seed navigation (always present)
- Actions (regenerate, reset, download)
- All styling inline

No external files. No imports beyond p5.js CDN. Runs immediately in claude.ai artifacts or any browser.
