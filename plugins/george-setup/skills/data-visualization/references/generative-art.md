# Generative Art Reference

Algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Output self-contained HTML artifacts.

## Philosophy-Driven Process

Every generative artwork follows three phases:

1. **Algorithmic Philosophy** (4-6 paragraphs in .md) -- Define the computational aesthetic. Name the movement, articulate how it manifests through noise, particles, fields, forces, and temporal evolution.
2. **Conceptual Seed** -- Identify the subtle reference embedded in the algorithm. It should enhance depth without announcing itself.
3. **p5.js Implementation** -- Express the philosophy through code. The algorithm flows from the philosophy, not from a menu of patterns.

## Core Techniques

### Flow Fields
Perlin noise drives vector fields that guide particle movement. Layer multiple noise octaves for turbulence.
```javascript
let angle = noise(x * noiseScale, y * noiseScale) * TWO_PI * 2;
let v = p5.Vector.fromAngle(angle);
```

### Particle Systems
Thousands of particles following forces, accumulating trails. Color from velocity, density, or age.
```javascript
class Particle {
    constructor() {
        this.pos = createVector(random(width), random(height));
        this.vel = createVector(0, 0);
        this.prevPos = this.pos.copy();
    }
    update(flowField) {
        let index = floor(this.pos.x / scl) + floor(this.pos.y / scl) * cols;
        this.vel.add(flowField[index]);
        this.vel.limit(maxSpeed);
        this.prevPos = this.pos.copy();
        this.pos.add(this.vel);
        this.wrapEdges();
    }
}
```

### Recursive Structures
L-systems, fractal branching, subdivision. Each level adds randomized variation constrained by golden ratios.

### Circle Packing
Randomized placement with collision detection. Cells grow until touching neighbors. Color by size, position, or neighbor count.

### Voronoi Tessellation
Random points relaxed through Lloyd's algorithm. Organic tiling from random seeds.

## Seeded Randomness (Critical)

Every artwork must be reproducible. Same seed = identical output.
```javascript
let seed = 12345;
randomSeed(seed);
noiseSeed(seed);
// All random() and noise() calls are now deterministic
```

## Parameter Design

Define parameters that emerge from the philosophy. Think "what properties of this system should be tunable?" not "which pattern should I use?"

```javascript
let params = {
    seed: 12345,
    // Quantities: how many elements?
    // Scales: how big, how fast?
    // Probabilities: how likely?
    // Ratios: what proportions?
    // Thresholds: when does behavior change?
};
```

Every parameter needs a matching UI slider in the sidebar.

## HTML Artifact Structure

Output a single self-contained HTML file. No external files except p5.js CDN.

### Fixed Elements (always include)
- Layout: header, sidebar, main canvas area
- Anthropic branding: Poppins/Lora fonts, light color scheme, gradient backdrop
- Seed section: display, prev/next/random buttons, jump-to input
- Actions section: regenerate, reset, download PNG buttons

### Variable Elements (customize per artwork)
- The p5.js algorithm (setup/draw/classes)
- Parameters object and matching sidebar sliders
- Colors section (optional: pickers if palette is adjustable, omit if fixed/monochrome)

### Template Usage

Read `templates/viewer.html` before implementation. Use it as the literal starting point -- keep all fixed sections, replace only the algorithm, parameters, and UI controls.

### Canvas Setup
```javascript
function setup() {
    let canvas = createCanvas(1200, 1200);
    canvas.parent('canvas-container');
    initializeSystem();
}
```

## Craftsmanship Requirements

- **Balance**: Complexity without visual noise, order without rigidity
- **Color harmony**: Thoughtful palettes derived from the philosophy, never random RGB
- **Composition**: Even in randomness, maintain visual hierarchy and flow
- **Performance**: Smooth 60fps for animated pieces. Pre-calculate expensive operations. Use spatial hashing for collision detection.
- **Reproducibility**: Same seed always produces identical output

## Philosophy Examples

**"Organic Turbulence"** -- Flow fields from layered Perlin noise. Particles accumulate into organic density maps. Color from velocity and density. Meticulously tuned balance between chaos and calm.

**"Quantum Harmonics"** -- Grid particles with phase values evolving through sine waves. Phase interference creates bright nodes and voids. Simple harmonic motion generates emergent mandalas.

**"Recursive Whispers"** -- Branching structures subdividing recursively. Golden ratio constraints with noise perturbations. L-systems generating tree-like forms. Line weights diminish with recursion depth.

**"Field Dynamics"** -- Invisible forces made visible through particle traces. Multiple attracting/repelling/rotating fields. Particles born at edges, dying at equilibrium.

**"Stochastic Crystallization"** -- Random circle packing or Voronoi relaxed to equilibrium. Color from cell size, neighbor count, or distance from center.

## Variation and Exploration

Seed navigation is built into every artifact. For curated collections:
- Add seed preset buttons ("Variation 1: Seed 42", "Variation 2: Seed 127")
- Add gallery mode showing thumbnails of seeds 1-100 side by side

## Template Files

Located at `templates/` within this skill directory (`~/.claude/skills/data-viz/templates/`):

- **viewer.html** -- Required HTML starting point with Anthropic branding, sidebar layout, seed controls, and action buttons
- **generator_template.js** -- p5.js best practices: parameter organization, seeded randomness, class structure, performance tips, utility functions

Read both templates before starting any implementation.

---

## Algorithmic Philosophy Framework

The philosophy is not decoration — it is the source code of the algorithm. Every parameter, behavior, and visual decision must be traceable back to the philosophy. A philosophy written without algorithmic specificity produces generic art; a philosophy that names its computational mechanisms produces work with identity.

### Philosophy-First Process (Non-Negotiable Order)

1. **Name the movement** (2-3 words): e.g., "Organic Turbulence", "Quantum Harmonics", "Recursive Whispers". The name defines the aesthetic territory before any code is considered.
2. **Write the manifesto** (4-6 paragraphs): articulate the computational worldview. Each paragraph should answer one of: What forces govern this system? How does time evolve it? What is the relationship between order and chaos here? What does the algorithm *refuse* to do? What emerges that was not explicitly programmed?
3. **Identify the conceptual seed**: the subtle reference embedded in the work. It should be felt by those who know it, invisible to those who don't. Think of it as algorithmic harmony — a jazz musician quoting another song through structure, not melody.
4. **Derive parameters from philosophy**: do not start with "what sliders should I add?" — start with "what properties of this system are philosophically meaningful to vary?" Parameters that emerge from philosophy feel necessary; parameters added for completeness feel like a menu.
5. **Implement**: the algorithm flows from the philosophy. Not the reverse.

### The Critical Understanding

What is received: a subtle input or user instruction — a seed, not a constraint.
What is created: a computational aesthetic movement with its own internal logic.
What the algorithm does: expresses that movement through 90% algorithmic generation and 10% essential parameters.

The philosophy should make the next implementer feel they have no choice but to build something specific — not because you told them what to build, but because the philosophy makes everything else feel wrong.

### Craftsmanship Requirements (Repeat These in Every Philosophy)

Every philosophy must emphasize, multiple times and in different framings:
- The final algorithm must appear as though it took countless hours of refinement
- Every parameter was tuned through deep iteration, not guessed
- The balance between chaos and structure was achieved through painstaking calibration
- This is the product of someone at the absolute top of their field in computational aesthetics
- The algorithm runs until it reaches equilibrium — not just until the timer runs out

These are not flattery. They are instructions. An implementer who believes the algorithm must feel "meticulously crafted" will tune differently than one who believes "good enough" is acceptable.

### Detailed Philosophy Examples

**"Organic Turbulence"**
Chaos constrained by natural law, order emerging from disorder. This movement holds that true organic form cannot be designed — it must be discovered through the collision of competing forces. Flow fields driven by layered Perlin noise form the substrate: multiple octaves stacked to create regions of turbulent energy and islands of calm, never uniform, never entirely random. Thousands of particles follow these vector forces, their trails accumulating into organic density maps where fast particles burn bright and slow ones fade to shadow — color as a function of kinetic energy, not aesthetic choice.

The algorithm runs until it reaches equilibrium: a meticulously tuned balance where chaos and order have negotiated a settlement. Every noise scale, every force multiplier, every alpha value was refined through countless iterations by a master of computational aesthetics. Nothing was left at its default. The work that appears effortless is the product of painstaking optimization — the kind of refinement that can only come from someone who has run this algorithm ten thousand times and knows where it wants to go.

**"Quantum Harmonics"**
Discrete entities exhibiting wave-like interference patterns — the central paradox of quantum mechanics rendered visible through computation. Particles initialized on a grid, each carrying a phase value that evolves through sine waves calibrated to produce resonant harmonics. When particles approach, their phases interfere: constructive interference creates bright nodes of intensity, destructive interference creates voids of absence. The grid is not a visual metaphor — it is the computational lattice through which interference propagates.

Simple harmonic motion generates complex emergent mandalas. No mandala was designed; each emerges from the interference of carefully chosen frequency ratios. The result of painstaking frequency calibration where every ratio was chosen to produce resonant beauty — a process that looks like mathematics but feels like music theory. The algorithm is complete when the interference pattern achieves visual resonance: a state recognized aesthetically, not calculated.

**"Recursive Whispers"**
Self-similarity across scales, infinite depth in finite space. Branching structures that subdivide recursively, each branch slightly randomized but constrained by golden ratio proportions that enforce a harmonic relationship between parent and child. L-systems or recursive subdivision generate tree-like forms that feel both mathematical and organic — the same tension between rule and variation found in natural growth. Subtle noise perturbations break perfect symmetry at each level, preventing the mechanical regularity that betrays algorithmic generation.

Line weights diminish with recursion depth in proportion to the inverse square of the level — not arbitrarily, but because that ratio matches the visual weight of branches in natural systems. Every branching angle is the product of deep mathematical exploration. The algorithm knows when to stop: when the structures have achieved a density that rewards close examination without overwhelming distant viewing. That threshold was not programmed — it was discovered.

**"Field Dynamics"**
Invisible forces made visible through their effects on matter. The philosophy of this movement holds that the most interesting visualization is never of the thing itself, but of its influence on the environment. Vector fields constructed from mathematical functions or noise — attractor wells, rotational vortices, repulsion zones — define a landscape of force that particles navigate without awareness of its shape. Particles are born at boundaries, flow along field lines, die at equilibrium or at edges.

The visualization shows only the traces: ghost-like evidence of invisible choreography. Multiple fields attract, repel, and rotate simultaneously, creating regions of complexity where their influences overlap. The algorithm is meticulously choreographed through force balance — each field parameter tuned so that particles neither escape immediately nor stagnate, but trace paths of calculated beauty. This is a master-level implementation of a system that rewards the viewer who studies it over time.

**"Stochastic Crystallization"**
Random processes crystallizing into ordered structures — the emergence of pattern from noise as a philosophical statement about the nature of order itself. Random points relax through Lloyd's algorithm toward Voronoi equilibrium, cells pushing apart until every point is equidistant from its neighbors. Or random circle packing proceeds until every space has been claimed. What begins as chaos achieves a kind of democracy of space. Color is assigned based on cell size, neighbor count, or distance from center — emergent properties of position, not decorative choices.

The organic tiling that emerges feels both random and inevitable — the mark of a master-level generative algorithm that has internalized the difference between these two things. Every seed produces unique crystalline beauty. The algorithm is complete not when the relaxation converges, but when the visual result achieves the particular quality of order-within-randomness that gives this movement its name. Recognizing that moment requires the aesthetic judgment of someone who has run this system across thousands of seeds.

### Parameter Design Methodology

Parameters should emerge from the philosophy, not be assembled from a menu of "things sliders can control." Ask:

- What quantity in this system changes its fundamental character when varied? (e.g., noise scale changes the spatial frequency of turbulence — it is philosophically significant)
- What ratio governs a key relationship? (e.g., the ratio of attraction to repulsion determines whether particles form clusters or distribute uniformly)
- What threshold marks a phase transition? (e.g., the particle count above which trails create a coherent field vs. isolated lines)
- What probability governs emergence? (e.g., the branching probability that separates sparse trees from dense canopies)

Parameters that cannot be explained by the philosophy should not exist. A "randomness" slider that does nothing specific is not a parameter — it is the absence of thought.

### Seeded Randomness as Non-Negotiable

Every artwork must be reproducible. Same seed = identical output. This is not a technical requirement — it is a philosophical one. An artwork that cannot be recalled is not an artwork; it is an event. Seeded randomness transforms the algorithm from a process into a space of possible works, each addressable by its coordinate (the seed). The seed navigation UI is the gallery; the algorithm is the medium; each seed is a unique work.

```javascript
// Always at the top of setup(), before any random() or noise() call
randomSeed(seed);
noiseSeed(seed);
```
