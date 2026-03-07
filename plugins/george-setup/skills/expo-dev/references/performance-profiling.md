# Performance Profiling

Performance optimization for Expo / React Native apps. Covers New Architecture, Hermes, React Compiler, profiling tools, and common bottlenecks.

## New Architecture (Default in SDK 52+)

SDK 52 enables the New Architecture by default for all new projects. Key components:

### JSI (JavaScript Interface)
- Synchronous native calls — no async bridge round-trips
- C++ layer shared between JS and native code
- Eliminates JSON serialization overhead of the old bridge

### Fabric Renderer
- Native views described as React trees (not imperative commands)
- Concurrent React features (Suspense, transitions) fully supported
- Layout calculated in C++ on the UI thread

### TurboModules
- Lazy-loaded native modules (only load when first used)
- Old bridge: all modules initialized at startup → slower cold start
- TurboModules: load on demand → faster startup

### Concurrent React Features (New Architecture Only)
- `useTransition` — mark state updates as non-urgent
- `useDeferredValue` — defer rendering expensive subtrees
- `Suspense` for data fetching with streaming

### Migration Gotchas
- Third-party libs with old bridge (`NativeModules.*`) may break
- Check: `npx expo-doctor` lists incompatible packages
- Run `npx react-native-new-architecture` to audit bridge usage
- `enableNewArchitecture: false` in app.json as temporary escape hatch (SDK 52 only)

---

## Hermes vs JSC

### Hermes (Default Since Expo 48)
- AOT (ahead-of-time) bytecode compilation at build time
- Faster app startup: bytecode is pre-parsed, no parse overhead at runtime
- Lower memory footprint: more compact heap, better GC
- Faster TTI (time-to-interactive): typical 20-40% improvement vs JSC

### JSC (JavaScriptCore)
- Fallback for legacy codebases
- Better raw throughput for long-running pure-JS computation
- Not recommended for new projects

### Switching Engines
**Android** — `android/app/build.gradle`:
```gradle
project.ext.react = [
  enableHermes: true  // set false to use JSC
]
```

**iOS** — Managed Expo: controlled by `jsEngine` in app.json:
```json
{
  "expo": {
    "jsEngine": "hermes"
  }
}
```

When to use JSC: almost never. Hermes is strictly better for React Native workloads. The only edge case is a CPU-bound pure-JS library with no native modules where JSC's JIT may outperform Hermes.

---

## React Compiler (Expo SDK 52+)

Automatic memoization — replaces manual `useMemo`, `useCallback`, `React.memo`.

### Setup (SDK 52 — manual babel config required)
```bash
npx expo install react-compiler-runtime babel-plugin-react-compiler
```

`babel.config.js`:
```js
const ReactCompilerConfig = { target: '18' };

module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [['babel-plugin-react-compiler', ReactCompilerConfig]],
  };
};
```

### Setup (SDK 54+ — automatic)
```json
{
  "expo": {
    "experiments": {
      "reactCompiler": true
    }
  }
}
```

### Verifying Compilation
- React DevTools: compiled components show "Memo ✓" badge in component tree
- Metro bundler output shows compilation diagnostics
- `compilationMode: 'annotation'` — only compile components with `'use memo'` directive (safe migration path)

### Common Incompatibilities
- Mutating props or state directly in render (non-pure functions)
- Reading external mutable state in render (outside useState/useRef)
- Non-stable object references created inline without memoization
- Side effects directly in component body (outside useEffect)

The compiler silently skips components it cannot safely optimize — it never breaks working code.

### Opt-out Per Component
```tsx
function LegacyComponent() {
  'use no memo';
  // React Compiler will not touch this component
  return <View />;
}
```

### After Enabling: Cleanup
Remove manual memoization that the compiler now handles:
```tsx
// Remove these — compiler handles them
const value = useMemo(() => compute(a, b), [a, b]);    // remove
const cb = useCallback(() => handle(a), [a]);           // remove
const Memoized = React.memo(MyComponent);               // remove

// Keep these — still useful
const ref = useRef(null);                               // keep
const [state, setState] = useState(initial);            // keep
```

---

## Profiling Tools

### React DevTools Profiler
- Flamegraph of component render times (which component took how long)
- "Ranked" view: slowest components at top
- "Why did this render?" — shows which props/state changed
- Enable in Expo Go: shake device → "Open React DevTools"

### React Native DevTools (New — replaces Flipper)
- Available via `npx expo start` → press `j` in terminal
- Chrome DevTools interface for JS debugging
- Heap profiler for memory leak detection
- Network inspector

### Flipper (Legacy)
- Still works but being deprecated in favor of React Native DevTools
- Hermes Debugger → heap snapshot for memory analysis
- Layout Inspector for view hierarchy

### Systrace (Native Performance)
- Android: `adb shell atrace` for native thread analysis
- Shows JS thread, UI thread, render thread timing
- Identifies native bottlenecks outside JS

### Sentry Performance
- Transaction tracing with frame rate monitoring
- `Sentry.startTransaction` wraps screen navigation
- Automatic slow render detection (frames < 60 FPS)
- `tracesSampleRate: 0.2` in production (20% sample)

---

## Common Bottlenecks

### FlatList Performance
```tsx
<FlatList
  data={items}
  keyExtractor={(item) => item.id}          // stable key, avoid index
  getItemLayout={(_, index) => ({           // skip measurement (fixed height only)
    length: ITEM_HEIGHT,
    offset: ITEM_HEIGHT * index,
    index,
  })}
  removeClippedSubviews={true}             // unmount off-screen items (Android)
  windowSize={5}                           // render 5 viewports worth (default 21)
  maxToRenderPerBatch={10}                 // items per JS batch
  initialNumToRender={10}                  // items on first render
/>
```

### Image Loading
Use `expo-image` (not RN's `Image`):
```tsx
import { Image } from 'expo-image';

<Image
  source={{ uri: imageUrl }}
  placeholder={blurhash}          // show blurhash while loading
  contentFit="cover"
  priority="high"                  // preload critical images
  cachePolicy="memory-disk"       // cache in memory + disk
/>
```

### Heavy Computation on JS Thread
Move to:
- **Web Worker** via `expo-web-workers` (pure JS computation)
- **Native module** for CPU-intensive work (crypto, image processing)
- **Reanimated worklets** for animation-related computation (runs on UI thread)

### Unnecessary Re-renders
Diagnose with React DevTools "Highlight Updates" (Settings → General):
- Every re-render flashes a color
- Green = 1 render, yellow = more, red = many
- Fix with: React Compiler (automatic), or `React.memo` / `useMemo` (manual)

---

## Memory Management

### Detecting Leaks
1. React Native DevTools → Memory tab → Take heap snapshot
2. Navigate away from screen, take another snapshot
3. Compare: retained objects from screen 1 that should be GC'd = leak

### Common Leak Sources
```tsx
// BAD: listener not cleaned up
useEffect(() => {
  EventEmitter.addListener('event', handler);
  // Missing return cleanup!
}, []);

// GOOD: cleanup on unmount
useEffect(() => {
  const sub = EventEmitter.addListener('event', handler);
  return () => sub.remove();
}, []);
```

### Image Cache Management
```tsx
import { Image } from 'expo-image';

// Clear cache when memory pressure detected
await Image.clearMemoryCache();
await Image.clearDiskCache();

// Per-image policy
<Image cachePolicy="none" />          // no caching
<Image cachePolicy="memory" />        // memory only
<Image cachePolicy="disk" />          // disk only
<Image cachePolicy="memory-disk" />   // both (default)
```

---

## 60 FPS Target

### JS Thread Budget
- 16ms per frame at 60 FPS, 8ms at 120 FPS
- JS thread and UI thread are separate — heavy JS does not block animations IF you use Reanimated

### Animated vs Reanimated
```tsx
// Animated (old) — runs on JS thread, can drop frames during heavy JS work
const opacity = useRef(new Animated.Value(0)).current;
Animated.timing(opacity, { toValue: 1, useNativeDriver: true }).start();

// Reanimated (preferred) — runs on UI thread, frame-perfect
import Animated, { useSharedValue, withTiming } from 'react-native-reanimated';
const opacity = useSharedValue(0);
opacity.value = withTiming(1);
```

Even `useNativeDriver: true` in old Animated moves to UI thread — but Reanimated worklets offer more power and flexibility.

### InteractionManager
Defer heavy work until after navigation animations complete:
```tsx
import { InteractionManager } from 'react-native';

useEffect(() => {
  const task = InteractionManager.runAfterInteractions(() => {
    // Heavy data processing, large list pre-computation, etc.
    loadLargeDataSet();
  });
  return () => task.cancel();
}, []);
```

### 120 FPS (ProMotion / High Refresh Rate)
- iOS: automatically uses 120 FPS on ProMotion displays with New Architecture
- Android: `android:refreshRate` in manifest, or Dynamic Frame Rate API
- Reanimated: `useFrameCallback` for per-frame logic at native refresh rate

---

## SDK 52 Performance Wins

- New Architecture default → JSI, TurboModules, Fabric all active
- 40% faster cold start (Hermes AOT + TurboModules lazy loading)
- 30% smaller JS bundle (tree shaking improvements in Metro)
- `expo-video`: C++ event emitter, hardware-accelerated playback
- SharedObject memory pressure handling for better GC behavior
