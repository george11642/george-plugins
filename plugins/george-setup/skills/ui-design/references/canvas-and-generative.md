# Canvas Design & Generative Art

## Canvas Design (Static Visual Art)

### Philosophy-Driven Process
1. **Create a Design Philosophy** (4-6 paragraphs): name the movement, articulate visual principles
2. **Express on Canvas**: interpret the philosophy as a .pdf or .png

### Philosophy Elements
- **Form & space**: how shapes occupy and divide the canvas
- **Color & material**: palette choices, texture, surface quality
- **Scale & rhythm**: repetition, variation, visual beats
- **Composition & balance**: asymmetric tension, focal points
- **Visual hierarchy**: what the eye sees first, second, third

### Philosophy Examples
| Name | Essence | Visual Language |
|------|---------|-----------------|
| Concrete Poetry | Monumental form + bold geometry | Massive color blocks, sculptural typography, Brutalist spatial divisions |
| Chromatic Language | Color as information system | Geometric precision, color zones create meaning, minimal labels |
| Analog Meditation | Quiet contemplation through texture | Paper grain, ink bleeds, vast negative space, whispered typography |
| Organic Systems | Natural clustering + modular growth | Rounded forms, organic arrangements, nature-through-architecture color |
| Geometric Silence | Pure order and restraint | Grid precision, dramatic negative space, Swiss formalism |

### Canvas Creation Rules
- Museum/magazine quality: every element meticulously placed, as if labored over for countless hours by someone at the absolute top of their field
- Text is minimal, visual-first — sparse labels, not paragraphs. Information lives in design, not words
- Use repeating patterns and perfect geometric shapes. Treat the work like a scientific diagram from an imaginary discipline
- Limited, intentional color palette that feels cohesive and deliberate
- Nothing overlaps unintentionally; proper margins on all sides. Check at 200% zoom
- Use different fonts from `canvas-fonts/` directory
- Typography as art: bring font onto canvas as visual element, not typeset digitally
- Take a second pass to refine — remove, don't add. Ask: "How can I make what's already here more of a piece of art?"
- Embrace the paradox of using analytical visual language to express ideas about human experience

### The Subtle Reference Principle
The topic or subject is a subtle, niche reference embedded within the art itself — not literal, always sophisticated. Someone familiar with the subject should feel it intuitively, while others simply experience a masterful abstract composition. Think like a jazz musician quoting another song — only those who know will catch it, but everyone appreciates the music.

### Output Formats
- Single-page .pdf or .png (unless multi-page requested)
- Accompanying .md file with the design philosophy
- Multi-page: treat as coffee table book — each page a unique twist

## Generative / Algorithmic Art (p5.js)

### Philosophy-Driven Process
1. **Create an Algorithmic Philosophy**: computational aesthetic movement
2. **Implement in p5.js**: interactive HTML artifact with parameter controls

### Algorithmic Elements
- Computational processes, emergent behavior, mathematical beauty
- Seeded randomness (`randomSeed()`, `noiseSeed()`) for reproducibility
- Particle systems, flow fields, force dynamics
- Parametric variation and controlled chaos

### Algorithm Categories
| Type | Techniques | Visual Result |
|------|-----------|---------------|
| Flow Fields | Perlin noise vectors, particle trails | Organic density maps |
| Particle Systems | Forces, attraction/repulsion, lifespan | Emergent formations |
| Recursive Structures | L-systems, subdivision, fractals | Self-similar branching |
| Harmonic Systems | Sine waves, interference, Lissajous | Geometric mandalas |
| Cellular | Voronoi, circle packing, Conway | Tessellations, growth |
| Stochastic | Random walks, diffusion, brownian | Organic noise textures |

### p5.js Implementation Template
```javascript
let seed = 12345;
let params = {
  seed: seed,
  // Algorithm-specific parameters
};

function setup() {
  createCanvas(1200, 1200);
  randomSeed(seed);
  noiseSeed(seed);
}

function draw() {
  // Express the philosophy through code
}
```

### Interactive Artifact Requirements
- Self-contained HTML file (p5.js from CDN, everything inline)
- **Seed navigation**: prev/next/random/jump controls
- **Parameter sliders**: real-time updates when adjusted
- **Actions**: regenerate, reset defaults, download PNG
- Same seed always produces identical output

### Craftsmanship Standards
- Balance: complexity without visual noise
- Color harmony: intentional palettes, not random RGB
- Composition: visual hierarchy even in randomness
- Performance: smooth real-time execution
- Every parameter carefully tuned

### Resources
- Template: `templates/viewer.html` (Anthropic-branded UI shell)
- Generator reference: `templates/generator_template.js`
- p5.js CDN: `https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.7.0/p5.min.js`
