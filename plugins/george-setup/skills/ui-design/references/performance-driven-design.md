# Performance-Driven Design

Design decisions that directly impact web performance — treating speed as a design requirement, not an engineering afterthought. Amazon found every 100ms delay costs 1% in sales. Pinterest reduced load times 40% and saw sign-ups increase 15%.

---

## Design for Speed Philosophy

### Visual Simplicity as Performance Strategy

Every visual element has a performance cost:
- Each DOM node increases layout and paint time
- Every additional font weight is a network request
- Complex CSS selectors slow style recalculation
- Gradients, shadows, and filters trigger GPU compositing

**Performance-conscious design principles**:
- **Fewer DOM nodes**: A design with 3 visual sections is faster than 7. Composition over complexity.
- **Limit font variants**: 2-3 font weight/style combinations per typeface. Each is a separate file download.
- **Prefer SVG over images for icons**: SVGs are infinitely scalable vector code — no image request, perfect at any resolution
- **Flat over layered**: Multiple overlapping translucent layers (glassmorphism stacked 5 levels deep) require expensive compositing
- **Text over images for text**: Never rasterize text into images for performance; screen readers, translations, and zooming all break

### Perceived Performance vs Actual Performance

Users experience perceived performance, not measured performance. Design can improve perceived speed without changing actual speed:

| Technique | Perceived Effect | Implementation |
|---|---|---|
| Skeleton screens | Page "loads instantly" | Show layout structure before data arrives |
| Optimistic UI | Action feels instant | Update UI before server confirms |
| Progressive loading | Content "fills in" | Load above-fold first, defer below |
| Meaningful first paint | Page feels alive | Show something real in first 1s |
| Loading animations | Wait feels shorter | Engaging animation > blank spinner |
| Instant feedback | Input feels responsive | Haptic/visual response < 100ms |

### Skeleton Screens vs Spinners

**Use skeleton screens when**:
- Content has predictable structure (card grids, lists, tables, profiles)
- Load time is 1-5 seconds
- Structure is known before content (you know you'll have 3 cards)
- On initial page/section load

**Use spinners (loading indicator) when**:
- Content structure is unknown until loaded (search results of unknown count)
- Load time is < 1 second (skeleton screen would flash too quickly)
- Action is indeterminate (file upload without known size)
- Inside small components (button loading state, inline refresh)

**Never use** a blank white screen with nothing showing — it is always worse than either option.

**Skeleton screen implementation**:
```css
.skeleton {
  background: linear-gradient(
    90deg,
    var(--color-neutral-200) 25%,
    var(--color-neutral-100) 50%,
    var(--color-neutral-200) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: var(--border-radius-md);
}

@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

@media (prefers-reduced-motion: reduce) {
  .skeleton {
    animation: none;
    background: var(--color-neutral-200);
  }
}
```

### Optimistic UI Updates

Treat the server response as confirmation, not initiation:

```javascript
// Optimistic like button
const [liked, setLiked] = useState(post.isLiked);
const [count, setCount] = useState(post.likeCount);

const handleLike = async () => {
  // Update UI immediately
  setLiked(!liked);
  setCount(liked ? count - 1 : count + 1);

  try {
    await api.toggleLike(post.id);
  } catch (error) {
    // Revert on failure
    setLiked(liked);
    setCount(count);
    showToast("Failed to update — please try again");
  }
};
```

**Appropriate for**: likes, follows, bookmarks, form auto-save, drag-and-drop reordering
**Inappropriate for**: payments, irreversible deletes, permission changes — these need server confirmation

---

## Asset Optimization as Design Decision

### SVG vs PNG vs WebP — Decision Matrix

| Format | Best For | File Size | Scalable | Transparency | Animation |
|---|---|---|---|---|---|
| SVG | Icons, logos, diagrams | Tiny–Small | Yes (infinite) | Yes | Yes (CSS/SMIL) |
| WebP | Photos, complex illustrations | Smallest | No | Yes | Yes (animated) |
| AVIF | Photos (modern browsers) | Even smaller | No | Yes | No |
| PNG | Screenshots, pixel art, legacy | Medium–Large | No | Yes | No |
| JPEG | Photos without transparency | Small–Medium | No | No | No |
| GIF | Simple animations (legacy) | Large | No | Limited | Yes |

**Design decisions**:
- All UI icons: SVG — request 1 SVG sprite vs N individual icon image requests
- Product screenshots: WebP with JPEG fallback
- Hero images: WebP/AVIF, max 200KB for above-fold, 400KB for below-fold
- User avatars: WebP with aggressive compression (faces are forgiving at lower quality)
- Background textures: CSS if possible; SVG if pattern; WebP only if photographic

### Icon Strategies: Font vs Sprite vs Inline

**Icon fonts** (Font Awesome, IcoMoon):
- Pros: Easy to size/color with CSS, single file request
- Cons: Renders as font (aliasing issues), single color only, FOUT (flash of unstyled icons), accessibility issues
- Verdict: Legacy approach — avoid for new projects

**SVG sprite** (recommended for most projects):
```html
<!-- sprites.svg — loaded once, referenced everywhere -->
<svg xmlns="http://www.w3.org/2000/svg" style="display:none">
  <symbol id="icon-arrow" viewBox="0 0 24 24">
    <path d="M5 12h14M12 5l7 7-7 7"/>
  </symbol>
  <symbol id="icon-check" viewBox="0 0 24 24">
    <path d="M20 6L9 17l-5-5"/>
  </symbol>
</svg>

<!-- Usage anywhere in the page -->
<svg class="icon" aria-hidden="true">
  <use href="/sprites.svg#icon-arrow"/>
</svg>
```

**Inline SVG** (recommended for critical icons, animated icons):
```jsx
// As React component — zero requests, fully styleable
const ArrowIcon = ({ className }) => (
  <svg viewBox="0 0 24 24" className={className} aria-hidden="true">
    <path d="M5 12h14M12 5l7 7-7 7"
          stroke="currentColor"
          strokeWidth="2"
          fill="none"
          strokeLinecap="round"/>
  </svg>
);
```

### Image Lazy Loading Patterns

```html
<!-- Native browser lazy loading — use for all below-fold images -->
<img
  src="product-card.webp"
  loading="lazy"
  decoding="async"
  width="400"
  height="300"
  alt="Product description"
/>
```

**The `width` and `height` attributes are critical** — they let the browser reserve space and prevent layout shift (CLS). Never omit them.

For above-fold images (the LCP element):
```html
<!-- Do NOT lazy load the hero/LCP image -->
<img
  src="hero.webp"
  loading="eager"
  fetchpriority="high"
  width="1200"
  height="600"
  alt="..."
/>
```

### Progressive JPEG and Blur-Up Technique

The blur-up technique provides instant visual feedback while the full image loads:

```jsx
const ProgressiveImage = ({ lowResSrc, highResSrc, alt }) => {
  const [loaded, setLoaded] = useState(false);

  return (
    <div className="relative overflow-hidden">
      {/* Low-res placeholder — loads instantly, heavily blurred */}
      <img
        src={lowResSrc}  // 20x20px placeholder, base64 or tiny URL
        className={`absolute inset-0 w-full h-full object-cover
                    scale-110 blur-lg transition-opacity duration-500
                    ${loaded ? 'opacity-0' : 'opacity-100'}`}
        aria-hidden="true"
        alt=""
      />
      {/* Full image — fades in when loaded */}
      <img
        src={highResSrc}
        className={`w-full h-full object-cover transition-opacity duration-500
                    ${loaded ? 'opacity-100' : 'opacity-0'}`}
        onLoad={() => setLoaded(true)}
        alt={alt}
      />
    </div>
  );
};
```

### Background Image Optimization

```css
/* Modern: use image-set() for responsive background images */
.hero {
  background-image: image-set(
    url("hero.avif") type("image/avif"),
    url("hero.webp") type("image/webp"),
    url("hero.jpg")  type("image/jpeg")
  );
  background-size: cover;
  background-position: center;
}

/* Prevent LCP delay — preload critical background images */
```

```html
<link rel="preload"
      as="image"
      href="hero.webp"
      type="image/webp"
      fetchpriority="high">
```

---

## Animation Performance

### GPU-Accelerated Properties Only

The browser's rendering pipeline has a fast path: if you only animate **transform** and **opacity**, the browser can handle animation entirely on the GPU compositor thread without touching layout or paint.

**Safe to animate (GPU-accelerated)**:
```css
/* These run on the GPU — no layout recalculation */
.animated {
  transform: translateX(100px);    /* move */
  transform: scale(1.1);           /* scale */
  transform: rotate(45deg);        /* rotate */
  opacity: 0.5;                    /* fade */
  filter: blur(4px);               /* filter (GPU, but expensive) */
}
```

**Expensive to animate (triggers layout or paint)**:
```css
/* Each of these recalculates layout on every animation frame —
   causes jank, destroys 60fps */
.jank-animation {
  top: 100px;       /* layout */
  left: 200px;      /* layout */
  width: 200px;     /* layout */
  height: 150px;    /* layout */
  margin: 10px;     /* layout */
  padding: 20px;    /* layout */
  font-size: 2rem;  /* layout */
  background-color: red; /* paint */
  box-shadow: 0 4px 20px black; /* paint */
}
```

**Translate the "move" pattern**:
```css
/* Bad: animates layout property */
@keyframes slide-in-bad {
  from { left: -100%; }
  to   { left: 0; }
}

/* Good: animates transform */
@keyframes slide-in-good {
  from { transform: translateX(-100%); }
  to   { transform: translateX(0); }
}
```

### prefers-reduced-motion — Always Respect

This media query is non-negotiable — it serves users with vestibular disorders, epilepsy, and motion sensitivity. The animation can cause physical symptoms for these users.

```css
/* Correct pattern: animate by default, reduce on request */
.card {
  transition: transform 200ms var(--ease-out),
              box-shadow 200ms var(--ease-out);
}
.card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-lg);
}

@media (prefers-reduced-motion: reduce) {
  .card {
    transition: box-shadow 150ms; /* Keep subtle, non-motion feedback */
  }
  .card:hover {
    transform: none; /* Remove the movement */
    box-shadow: var(--shadow-lg); /* Keep the visual feedback */
  }
}
```

**In React with Framer Motion**:
```javascript
import { useReducedMotion } from 'framer-motion';

const MyComponent = () => {
  const shouldReduce = useReducedMotion();

  return (
    <motion.div
      initial={{ opacity: 0, y: shouldReduce ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: shouldReduce ? 0.1 : 0.3 }}
    />
  );
};
```

### will-change — Sparingly

`will-change` hints to the browser that an element will animate, prompting it to create a compositor layer ahead of time. This reduces jank at the cost of memory.

```css
/* Good: applied only to elements that will actually animate */
.dropdown-panel {
  will-change: transform, opacity;
}

/* Bad: applied globally — wastes GPU memory */
* {
  will-change: transform; /* NEVER DO THIS */
}

/* Best practice: apply with JS right before animation, remove after */
```

```javascript
element.addEventListener('mouseenter', () => {
  element.style.willChange = 'transform';
});
element.addEventListener('animationend', () => {
  element.style.willChange = 'auto';
});
```

### 60fps Budget (16ms per Frame)

At 60fps, each frame has 16.67ms to complete. The browser needs ~6ms for its own work, leaving ~10ms for your code.

**Frame budget breakdown**:
- JavaScript execution: ≤ 3ms
- Style recalculation: < 1ms (avoid forcing layout)
- Layout: < 1ms (avoid triggering reflow)
- Paint: < 1ms (keep painted areas small)
- Compositing: handled by GPU

**Detecting jank**: Open DevTools → Performance tab → record animation → look for frames exceeding 16ms (shown as red/yellow in the flame chart)

**Common jank causes**:
- Reading layout properties (`offsetWidth`, `getBoundingClientRect`) inside animation loops forces synchronous layout
- Animating too many elements simultaneously
- Large DOM trees with complex selectors during animation
- JavaScript running on the main thread during animation (move to Web Workers if possible)

---

## Battery and Accessibility

### Avoiding Continuous Animations

Continuous animations (infinite loops, parallax, particle systems) drain battery — especially on mobile:

- **Auto-playing carousels**: Battery drain + vestibular disorder risk. Use manual-only or very slow auto-play with pause-on-focus
- **Particle systems / canvas effects**: Acceptable for hero moments, never as always-on background
- **Animated backgrounds**: Use static image alternatives; animate only on interaction
- **Lottie animations**: Pause when out of viewport (`IntersectionObserver`)

```javascript
// Pause animation when not visible
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      lottieInstance.play();
    } else {
      lottieInstance.pause();
    }
  });
});
observer.observe(animationContainer);
```

### Dark Mode as Battery Saver (OLED)

OLED and AMOLED screens (most modern phones) consume near-zero power for black pixels. True dark mode (#000000 backgrounds) can reduce battery consumption by 30-40% in dark UI sections.

Design implications:
- Use true black (#000) or very near-black (#0a0a0a) for OLED-optimized dark mode
- Surface elevation in dark mode: slightly lighter backgrounds (not lighter colors — use neutral scale)
- Avoid bright accent colors on OLED dark backgrounds — vibrant colors drain battery too
- Twitter's AMOLED dark mode (true black) reduced power by ~30% vs their "lights out" gray

---

## Core Web Vitals as Design Goals

Google's Core Web Vitals are direct design-to-engineering translation points. Poor vitals = lower search rankings.

### LCP — Largest Contentful Paint (target: < 2.5s)

LCP measures when the largest visible element loads. Usually the hero image or headline.

**Design for fast LCP**:
- Identify the LCP element in your design (usually hero image)
- Specify it as critical: `fetchpriority="high"`, no `loading="lazy"`
- Size it: provide `width` and `height` on `<img>` to eliminate layout shift
- Format it: WebP or AVIF, aggressive compression
- Preload it: `<link rel="preload" as="image" href="hero.webp">`
- Consider: Is the LCP element CSS background? Move to `<img>` (CSS backgrounds can't be preloaded as easily)
- Serve from CDN: LCP image should be served from edge, close to user

**Design choices that hurt LCP**:
- Hero section that requires JavaScript to render (SSR/SSG the critical content)
- Hero image loaded as CSS background (can't benefit from fetchpriority)
- Lazy-loading the above-fold hero (never do this)
- Large uncompressed hero images (compress to < 200KB)

### CLS — Cumulative Layout Shift (target: < 0.1)

CLS measures how much the page shifts during load. Frustrating and disorienting for users.

**Design for zero CLS**:

1. **Reserve space for all images**: Always provide dimensions
```html
<!-- Specify width + height — browser calculates aspect ratio -->
<img src="card.webp" width="400" height="300" loading="lazy" alt="...">

<!-- For responsive images, use aspect-ratio in CSS -->
.card-image {
  aspect-ratio: 4 / 3;
  width: 100%;
}
```

2. **Reserve space for ads and embeds**:
```css
.ad-slot {
  min-height: 250px; /* Standard ad unit height */
  background: var(--color-bg-subtle); /* Placeholder while loading */
}
```

3. **Avoid inserting DOM above existing content**:
- Banners, cookie notices, chat widgets: position fixed, not document flow
- Avoid top-of-page banners that push content down after page load

4. **Font loading strategy** — avoid FOUT:
```html
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
```
```css
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-display: optional; /* Use fallback if font doesn't load fast enough */
}
```

### INP — Interaction to Next Paint (target: < 200ms)

INP measures the time from user interaction to visual response. Replaced FID in March 2024.

**Design for responsive INP**:
- Heavy click handlers: Move heavy computation to Web Workers or setTimeout
- Long lists: Virtualize (react-window, TanStack Virtual)
- Complex animations triggered by click: Use CSS transitions (GPU) not JS-driven frame loops
- Forms: Real-time validation must be debounced — don't recalculate on every keystroke

---

## Performance Budget

### Setting Visual Weight Limits

A performance budget is a design constraint, like a color palette:

```
Page budget: 300KB total JavaScript
            200KB images (hero)
            50KB fonts (2 weights max)
            30KB CSS
            = ~580KB total
```

**Translate budgets into design decisions**:
- Max 2 typefaces, max 3 weights → tight budget for fonts
- Max 3 hero images per page → forces prioritization
- No custom animations in below-fold components → defer non-critical JavaScript
- All icons: inline SVG → zero image requests for icons

### Lighthouse as Design Feedback Tool

Run Lighthouse (Chrome DevTools → Lighthouse) against any prototype or staging URL:

**Performance score 90+ design checklist**:
- [ ] LCP < 2.5s: Hero image compressed, preloaded, no lazy-load
- [ ] CLS < 0.1: All images sized, no layout-shifting banners
- [ ] INP < 200ms: No heavy main-thread blocking
- [ ] No render-blocking resources: Critical CSS inlined, non-critical CSS deferred
- [ ] Images sized: No oversized images (Lighthouse flags these specifically)
- [ ] Efficient cache policy: Static assets have long cache TTL

**Lighthouse CI for design system**:
Integrate Lighthouse into the CI pipeline so performance regressions are caught when new components are added — not after they ship.

```yaml
# GitHub Actions example
- name: Lighthouse CI
  run: npx lhci autorun --collect.url=http://localhost:3000
  env:
    LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

**Score thresholds**:
- 90-100: Green — excellent
- 50-89: Orange — needs improvement
- 0-49: Red — poor

Design systems should target 90+ for demo pages and component documentation. Individual pages in production can vary based on content, but tracking baselines is critical for catching regressions.
