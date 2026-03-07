# SwiftUI Fundamentals

## View Protocol and Body

Every SwiftUI view conforms to `View` and provides a `body` computed property. SwiftUI diffs the view tree on every state change — keep `body` fast and pure.

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello")
            .padding()
            .background(.blue)
    }
}
```

**@ViewBuilder**: A result builder that lets you compose multiple views in a closure without explicit `Group` or `TupleView`. Use it for conditional rendering:

```swift
@ViewBuilder
func badge(for user: User) -> some View {
    if user.isPremium {
        Image(systemName: "star.fill").foregroundStyle(.yellow)
    } else {
        EmptyView()
    }
}
```

**some View vs AnyView**: Always prefer `some View` (opaque type). `AnyView` erases type information, disables diffing optimization, and increases allocations. Use `AnyView` only at hard API boundaries (e.g., returning from a function that must have a single concrete return type at runtime).

## State Management — Which Property Wrapper to Use

| Wrapper | When to Use | Owns Data? |
|---------|-------------|------------|
| `@State` | Simple local value (Bool, Int, String, small struct) | Yes |
| `@Binding` | Pass mutable reference to child view | No |
| `@StateObject` | Own an ObservableObject — created once, not re-created on re-render | Yes |
| `@ObservedObject` | Receive an ObservableObject from parent — re-created on re-render | No |
| `@EnvironmentObject` | Inject ObservableObject through the view hierarchy | No |
| `@Environment` | Read system/custom environment values | No |
| `@Observable` (iOS 17+) | Modern replacement for ObservableObject — no `@Published` needed | Yes/No |

```swift
// iOS 17+ — @Observable macro (preferred)
@Observable
class CartModel {
    var items: [Item] = []
    var total: Double = 0
}

struct ShopView: View {
    @State private var cart = CartModel()  // owns it
    var body: some View {
        CartSummary(cart: cart)  // pass by reference, no $ needed
    }
}

struct CartSummary: View {
    var cart: CartModel  // no wrapper needed for reading
    // Use @Bindable for two-way binding:
    // @Bindable var cart: CartModel
}
```

**Key rule**: `@State` for value types, `@StateObject`/`@Observable` for reference types. Never use `@ObservedObject` for objects you create — use `@StateObject` to prevent re-initialization.

## View Lifecycle

```swift
.onAppear { /* view is visible */ }
.onDisappear { /* view leaves hierarchy */ }
.task { /* async work tied to view lifetime — cancels on disappear */ }
.task(id: someValue) { /* re-runs when someValue changes */ }
.onChange(of: value) { newValue in /* react to changes */ }
// iOS 17+:
.onChange(of: value) { oldValue, newValue in }
```

Prefer `.task` over `.onAppear` + `Task { }` — SwiftUI cancels the task automatically when the view disappears.

## Custom ViewModifiers

Extract reusable styling into modifiers to keep `body` clean:

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// Usage:
Text("Hello").cardStyle()
```

## GeometryReader

Reads the available space. Use sparingly — it expands to fill all available space and can break layouts if nested carelessly.

```swift
GeometryReader { proxy in
    let size = proxy.size
    let safeArea = proxy.safeAreaInsets
    Circle()
        .frame(width: min(size.width, size.height) * 0.8)
}
// iOS 17+: prefer .containerRelativeFrame for proportional sizing
Text("Half width")
    .containerRelativeFrame(.horizontal) { width, _ in width * 0.5 }
```

## PreferenceKey — Passing Data Up the Tree

```swift
struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// Child sets preference
child.background(GeometryReader { geo in
    Color.clear.preference(key: HeightKey.self, value: geo.size.height)
})
// Parent reads it
.onPreferenceChange(HeightKey.self) { height in
    self.measuredHeight = height
}
```

## Lazy Containers and ScrollView Patterns

```swift
// LazyVStack — only renders visible views
ScrollView {
    LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}

// LazyVGrid — responsive grid
let columns = [GridItem(.adaptive(minimum: 160))]
ScrollView {
    LazyVGrid(columns: columns, spacing: 16) {
        ForEach(items) { item in ItemCard(item: item) }
    }
}

// ScrollViewReader — programmatic scroll
ScrollViewReader { proxy in
    ScrollView {
        ForEach(messages) { msg in
            MessageRow(msg: msg).id(msg.id)
        }
    }
    .onChange(of: messages.count) {
        proxy.scrollTo(messages.last?.id, anchor: .bottom)
    }
}
```

## SwiftUI 5 / iOS 17+ Updates

### @Observable (replaces ObservableObject)
- No need for `@Published` — all stored properties are observed automatically
- Use `@Bindable` when you need `$binding` syntax on an `@Observable` class
- Passed as plain value to child views — no `@ObservedObject` wrapper needed
- Finer-grained updates: only views reading a specific property re-render

### scrollTargetBehavior
```swift
ScrollView(.horizontal) {
    LazyHStack {
        ForEach(pages) { page in
            PageView(page: page)
                .containerRelativeFrame(.horizontal)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)  // snaps to each page
```

### Phase Animators (iOS 17+)
```swift
PhaseAnimator([false, true]) { phase in
    Circle()
        .scaleEffect(phase ? 1.2 : 1.0)
        .opacity(phase ? 1.0 : 0.5)
} animation: { phase in
    phase ? .spring(duration: 0.3) : .easeOut(duration: 0.2)
}
```

### TipKit (iOS 17+)
```swift
struct InlineTipView: View {
    var tip = MyFeatureTip()
    var body: some View {
        TipView(tip, arrowEdge: .top)
    }
}
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| `@ObservedObject` on locally created object | Use `@StateObject` |
| `AnyView` everywhere | Use `@ViewBuilder` or `Group` |
| Heavy work in `body` | Move to `.task` or `.onAppear` |
| `GeometryReader` wrapping everything | Use `.containerRelativeFrame` (iOS 17+) |
| Calling `body` manually | Never — let SwiftUI call it |
| Mutations in `init` of `@State` | Use `_state = State(initialValue: ...)` in init |

## Environment Values

```swift
// Read system environment
@Environment(\.colorScheme) var colorScheme
@Environment(\.dynamicTypeSize) var typeSize
@Environment(\.dismiss) var dismiss  // from .sheet / NavigationStack

// Custom environment value (iOS 17+: use @Entry macro)
extension EnvironmentValues {
    @Entry var theme: Theme = .default
}
// Inject: .environment(\.theme, .dark)
// Read: @Environment(\.theme) var theme
```

## Lists and Performance

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
            .equatable()  // skip re-render if Equatable and unchanged
    }
    .onDelete { indexSet in items.remove(atOffsets: indexSet) }
    .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }
}
.listStyle(.insetGrouped)

// Sectioned list
List {
    ForEach(groupedItems, id: \.key) { section in
        Section(section.key) {
            ForEach(section.values) { item in ItemRow(item: item) }
        }
    }
}
```

Implement `Equatable` on your row model + use `.equatable()` modifier to skip renders when data hasn't changed.
