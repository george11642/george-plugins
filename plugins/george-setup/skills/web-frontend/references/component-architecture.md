# Component Architecture

Consolidated from: vercel-composition-patterns, vercel-react-best-practices

## Composition Over Boolean Props

### Problem: Boolean Prop Proliferation
```tsx
// BAD - grows exponentially
<Button primary large rounded disabled loading iconLeft="check" />
```

### Solution: Explicit Variant Components
```tsx
// GOOD - clear, tree-shakeable
<PrimaryButton size="lg">Submit</PrimaryButton>
<OutlineButton size="sm">Cancel</OutlineButton>
<IconButton icon={CheckIcon} label="Approve" />
```

## Compound Components

Share implicit state via context for complex UI patterns.

```tsx
// Usage
<Tabs defaultValue="tab1">
  <TabsList>
    <TabsTrigger value="tab1">Account</TabsTrigger>
    <TabsTrigger value="tab2">Settings</TabsTrigger>
  </TabsList>
  <TabsContent value="tab1">Account content</TabsContent>
  <TabsContent value="tab2">Settings content</TabsContent>
</Tabs>
```

### Implementation Pattern
```tsx
const TabsContext = createContext<TabsState | null>(null)

function Tabs({ children, defaultValue }) {
  const [value, setValue] = useState(defaultValue)
  return (
    <TabsContext value={{ value, setValue }}>
      {children}
    </TabsContext>
  )
}

function TabsTrigger({ value, children }) {
  const ctx = use(TabsContext) // React 19
  return (
    <button 
      data-active={ctx.value === value}
      onClick={() => ctx.setValue(value)}
    >
      {children}
    </button>
  )
}
```

## State Management Patterns

### Lift State into Providers
```tsx
// Move state up when siblings need to share
function SearchProvider({ children }) {
  const [query, setQuery] = useState("")
  const results = useMemo(() => search(query), [query])
  return (
    <SearchContext value={{ query, setQuery, results }}>
      {children}
    </SearchContext>
  )
}
```

### Context Interface Pattern
Define a generic interface for dependency injection:
```tsx
interface ContextValue<T> {
  state: T                          // Current state
  actions: Record<string, Function> // Mutations
  meta: { loading: boolean; error: Error | null } // Status
}
```

### Decouple Implementation from Interface
Provider is the ONLY place that knows how state is managed:
```tsx
// Internal: could be useState, useReducer, Zustand, server state
function CartProvider({ children }) {
  const [items, dispatch] = useReducer(cartReducer, [])
  // Consumer doesn't know or care about implementation
  return <CartContext value={{ items, addItem, removeItem }}>{children}</CartContext>
}
```

## Children Over Render Props

```tsx
// PREFER: children for composition
<Card>
  <CardHeader>Title</CardHeader>
  <CardBody>Content</CardBody>
</Card>

// AVOID: render props (unless dynamic)
<Card renderHeader={() => <h2>Title</h2>} renderBody={() => <p>Content</p>} />
```

Use render props only when the parent needs to pass data to the child:
```tsx
<DataTable data={users} renderRow={(user) => <UserRow user={user} />} />
```

## React 19 Simplifications

- **No forwardRef**: `ref` is a regular prop
  ```tsx
  function Input({ ref, ...props }) {
    return <input ref={ref} {...props} />
  }
  ```
- **use() replaces useContext()**: Can be called conditionally
  ```tsx
  const theme = use(ThemeContext)
  ```

## Architecture Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| `<Component isSmall isBordered isRounded />` | Explicit variants: `<SmallBorderedCard />` |
| Prop drilling 3+ levels | Context provider at nearest common ancestor |
| renderX props for static content | Children composition |
| Giant god components (500+ lines) | Extract into compound component set |
| Coupling component to data source | Accept data via props, fetch in parent |
