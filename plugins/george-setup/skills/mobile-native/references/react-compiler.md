# React Compiler

React Compiler automatically memoizes components and hooks at compile time, eliminating the need for manual `useMemo`, `useCallback`, and `React.memo`. It analyzes your code at build time and inserts memoization where it is safe and beneficial.

## What React Compiler Does

Without React Compiler, React re-renders a component whenever its parent re-renders, even if props haven't changed. You work around this with:
- `React.memo(Component)` — skip re-render if props unchanged
- `useMemo(() => compute(), [deps])` — cache computed value
- `useCallback(() => fn(), [deps])` — stable function reference

React Compiler handles all of this automatically. It analyzes your component's render function and inserts the equivalent memoization at the right granularity — not just at the component boundary, but at the expression level.

**Performance impact**: Typical apps see 20-40% reduction in unnecessary re-renders. The gains stack across the component tree: fewer parent re-renders mean fewer child re-renders.

---

## SDK Version Support

| SDK | Status | Setup |
|-----|--------|-------|
| SDK 52 | Supported (manual babel config) | Install plugin + configure babel.config.js |
| SDK 54+ | Built-in | Enable via app.json experiments flag |

---

## Setup: SDK 52 (Manual)

```bash
npx expo install react-compiler-runtime babel-plugin-react-compiler
```

`babel.config.js`:
```js
const ReactCompilerConfig = {
  target: '18',  // React 18 compatibility mode
};

module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [['babel-plugin-react-compiler', ReactCompilerConfig]],
  };
};
```

After changing babel config, clear Metro cache:
```bash
npx expo start --clear
```

### Compilation Modes (SDK 52)

```js
// compilationMode options:
// 'all'        — compile every component and hook (default, most aggressive)
// 'annotation' — only compile components/hooks with 'use memo' directive
// 'infer'      — compile when compiler can prove it's safe (conservative)

const ReactCompilerConfig = {
  target: '18',
  compilationMode: 'annotation',  // safe migration path for large codebases
};
```

With `annotation` mode, opt in components one by one:
```tsx
function MyComponent() {
  'use memo';  // opt this component in
  return <View />;
}
```

---

## Setup: SDK 54+ (Automatic)

Add to `app.json`:
```json
{
  "expo": {
    "experiments": {
      "reactCompiler": true
    }
  }
}
```

No babel config changes needed — `babel-preset-expo` handles everything automatically.

---

## Requirements

- **New Architecture must be enabled** (default since SDK 52). React Compiler requires Concurrent React features.
- **React 18+**: target must match your React version.
- **Pure render functions**: components must follow the Rules of React.

---

## Verifying It's Working

### React DevTools
Compiled components show a "Memo ✓" badge in the component tree. Uncompiled components show nothing (the compiler silently skips components it cannot safely optimize).

### Metro Output
During bundling, Metro prints compilation statistics. Look for lines like:
```
[React Compiler] Compiled 47 components, skipped 3
```

### ESLint Plugin (Recommended)
```bash
npx expo install eslint-plugin-react-compiler
```

`.eslintrc.js`:
```js
module.exports = {
  plugins: ['react-compiler'],
  rules: {
    'react-compiler/react-compiler': 'error',
  },
};
```

This enforces the Rules of React that the compiler depends on — catches violations before they cause silent skip.

---

## Compatibility Requirements (Rules of React)

React Compiler only works correctly with code that follows the Rules of React. Violations cause the compiler to silently skip that component.

### Pure Render Functions
Components must be pure — same props/state → same output, no side effects during render:

```tsx
// GOOD: pure render
function UserCard({ user }: { user: User }) {
  const display = `${user.firstName} ${user.lastName}`;
  return <Text>{display}</Text>;
}

// BAD: side effect in render (impure)
function BadComponent({ id }: { id: string }) {
  analytics.track('render', { id });  // side effect during render
  return <View />;
}
```

### No Prop Mutation
```tsx
// BAD: mutating props
function BadSort({ items }: { items: string[] }) {
  items.sort();  // mutating the prop array!
  return <FlatList data={items} />;
}

// GOOD: copy before mutation
function GoodSort({ items }: { items: string[] }) {
  const sorted = [...items].sort();
  return <FlatList data={sorted} />;
}
```

### No Reading External Mutable State in Render
```tsx
// BAD: reading mutable external ref during render
const cache = { value: 0 };

function BadReader() {
  return <Text>{cache.value}</Text>;  // mutable external state
}

// GOOD: use useState or useRef for mutable values
function GoodReader() {
  const [value, setValue] = useState(0);
  return <Text>{value}</Text>;
}
```

### Stable Hook Call Order
```tsx
// BAD: hooks in conditional
function BadHooks({ show }: { show: boolean }) {
  if (show) {
    const [state] = useState(0);  // conditional hook!
  }
  return <View />;
}
```

---

## Common Incompatibilities

| Pattern | Issue | Fix |
|---------|-------|-----|
| `array.sort()` in render | Mutates prop | Use `[...arr].sort()` |
| `object.prop = value` in render | Mutates object | Use `useState` / create new object |
| `useRef.current` read in render | Mutable external state | Use `useState` |
| Third-party libs with non-pure components | Compiler skips them | Use `'use no memo'` on wrappers |
| `Math.random()` in render | Non-deterministic | Move to `useState` initializer |

---

## Opt-out with 'use no memo'

Force the compiler to skip a specific component or hook:

```tsx
function LegacyAnimation() {
  'use no memo';
  // Complex imperative animation logic that confuses the compiler
  const animRef = useRef(new Animated.Value(0));
  // ...
  return <Animated.View style={{ opacity: animRef.current }} />;
}

function useComplexHook() {
  'use no memo';
  // Hook with intentional side effects the compiler would mishandle
}
```

The directive must be the first statement in the function body. It tells the compiler to leave this component/hook entirely unmodified.

---

## Cleanup After Enabling

Once React Compiler is active, manual memoization is redundant. Remove it to reduce noise:

```tsx
// BEFORE: manual memoization
const expensiveValue = useMemo(
  () => items.filter(i => i.active).map(i => i.name),
  [items]
);
const handlePress = useCallback((id: string) => {
  onSelect(id);
}, [onSelect]);
const List = React.memo(({ items }: Props) => <FlatList data={items} />);

// AFTER: React Compiler handles this
const expensiveValue = items.filter(i => i.active).map(i => i.name);
const handlePress = (id: string) => onSelect(id);
function List({ items }: Props) { return <FlatList data={items} />; }
```

**Migrate gradually**: Don't remove all memoization at once. Start a new project without it, or remove file-by-file while monitoring for regressions.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Component not showing "Memo ✓" | Compiler skipped it (Rules violation) | Check ESLint plugin output |
| App slower after enabling | Compiler overhead on very simple components | Use `compilationMode: 'infer'` |
| Build error after enabling | babel config issue | Clear cache: `npx expo start --clear` |
| Third-party component breaks | Library violates Rules of React | Wrap with `'use no memo'` component |
| Metro hangs during compilation | Very large codebase | Use `compilationMode: 'annotation'` |

If the compiler encounters a component it cannot safely optimize, it always falls back to unoptimized behavior — it never breaks working code.
