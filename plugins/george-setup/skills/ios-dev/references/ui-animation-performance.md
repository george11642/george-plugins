# UI, Animation, and Performance

## Animations in SwiftUI

### Basic Animation

```swift
struct AnimatedButton: View {
    @State private var isPressed = false

    var body: some View {
        Circle()
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onTapGesture { isPressed.toggle() }
    }
}

// Explicit animation (preferred for event-driven changes)
Button("Tap") {
    withAnimation(.easeInOut(duration: 0.3)) {
        showDetail = true
    }
}
```

### Matched Geometry Effect — Hero Animations

```swift
@Namespace private var heroNamespace

// Source view
Image(item.thumbnail)
    .matchedGeometryEffect(id: item.id, in: heroNamespace)

// Destination view
Image(item.fullImage)
    .matchedGeometryEffect(id: item.id, in: heroNamespace)
// Wrap in if/else controlled by @State — SwiftUI interpolates between the two
```

### Custom Transitions

```swift
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// Usage
if showContent {
    ContentView()
        .transition(.slideAndFade)
}
```

### Phase Animators (iOS 17+)

```swift
// Multi-step animation with discrete phases
struct PulseButton: View {
    @State private var isAnimating = false

    var body: some View {
        Button("Send") { isAnimating = true }
            .phaseAnimator([false, true], trigger: isAnimating) { view, phase in
                view
                    .scaleEffect(phase ? 1.1 : 1.0)
                    .foregroundStyle(phase ? .white : .blue)
            } animation: { phase in
                phase ? .spring(bounce: 0.4) : .easeOut(duration: 0.2)
            }
    }
}

// Keyframe Animator (iOS 17+) — precise control
Image(systemName: "heart.fill")
    .keyframeAnimator(initialValue: AnimValues()) { view, values in
        view.scaleEffect(values.scale).rotationEffect(values.rotation)
    } keyframes: { _ in
        KeyframeTrack(\.scale) {
            SpringKeyframe(1.5, duration: 0.3, spring: .bouncy)
            SpringKeyframe(1.0, spring: .snappy)
        }
        KeyframeTrack(\.rotation) {
            LinearKeyframe(.degrees(0), duration: 0.1)
            CubicKeyframe(.degrees(20), duration: 0.15)
            CubicKeyframe(.degrees(-20), duration: 0.15)
            SpringKeyframe(.degrees(0), spring: .bouncy)
        }
    }
```

## Canvas — Custom Drawing

```swift
Canvas { context, size in
    // Draw a gradient circle
    let rect = CGRect(origin: .zero, size: size)
    let gradient = Gradient(colors: [.blue, .purple])
    context.fill(Path(ellipseIn: rect),
                 with: .linearGradient(gradient,
                                       startPoint: rect.origin,
                                       endPoint: CGPoint(x: size.width, y: size.height)))

    // Draw text
    context.draw(Text("Canvas").font(.title), at: CGPoint(x: size.width/2, y: size.height/2))

    // Apply transforms
    context.translateBy(x: 100, y: 100)
    context.rotate(by: .degrees(45))
}
.frame(width: 200, height: 200)
```

## Metal Basics for GPU Rendering

For real-time effects that Canvas can't handle at 60+ fps:

```swift
// MTKView in UIKit (wrapped for SwiftUI)
struct MetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 120  // ProMotion
        return view
    }

    func makeCoordinator() -> Renderer { Renderer() }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

final class Renderer: NSObject, MTKViewDelegate {
    var commandQueue: MTLCommandQueue!
    // ... pipeline setup

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        // Draw calls
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
```

## Instruments — Profiling

### Time Profiler
1. Product → Profile → Time Profiler
2. Filter by your app's threads
3. Focus on frames taking > 16ms (60fps) or > 8ms (120fps)
4. Check "Hide System Libraries" to focus on your code

### Hangs Instrument
- Detects main thread blocks > 250ms
- Key causes: synchronous I/O, heavy JSON decoding on main thread, Core Data fetch on main context

### Allocations Instrument
- Find memory leaks: "Mark Generation" button between actions
- Track persistent objects to spot retain cycles
- Enable "Record Reference Counts" for detailed tracking

### Common Profiling Workflow
```
1. Run on device (not simulator)
2. Profile in Release build: Product → Scheme → Edit → Run → Build Config = Release
3. Time Profiler: find hot functions
4. Allocations: check for memory growth
5. Energy Organizer: check battery impact
```

## List / LazyVStack Performance

```swift
// Make rows Equatable to avoid unnecessary re-renders
struct ItemRow: View, Equatable {
    let item: Item

    static func == (lhs: ItemRow, rhs: ItemRow) -> Bool {
        lhs.item.id == rhs.item.id && lhs.item.updatedAt == rhs.item.updatedAt
    }

    var body: some View { /* ... */ }
}

// Use .equatable() modifier
ForEach(items) { item in
    ItemRow(item: item).equatable()
}

// Avoid @State in row views — causes re-render on every parent refresh
// Bad: @State var isExpanded = false inside ItemRow
// Good: track expanded IDs in parent: @State private var expandedIDs: Set<UUID> = []

// Prefetch images (avoid blocking scroll)
AsyncImage(url: item.thumbnailURL) { image in
    image.resizable().scaledToFill()
} placeholder: {
    Color.gray.opacity(0.2)
}

// For very long lists (10k+ items), use List over LazyVStack
// List uses UITableView/UICollectionView under the hood — better cell reuse
```

## Image Caching

```swift
// NSCache-backed in-memory cache
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB
    }

    subscript(url: URL) -> UIImage? {
        get { cache.object(forKey: url as NSURL) }
        set {
            if let image = newValue {
                cache.setObject(image, forKey: url as NSURL,
                                cost: Int(image.size.width * image.size.height * 4))
            } else {
                cache.removeObject(forKey: url as NSURL)
            }
        }
    }
}

// Or use Nuke/Kingfisher library for disk caching + progressive loading
// Nuke: ImagePipeline.shared.loadImage(with: url) { ... }
// KingFisher: imageView.kf.setImage(with: url)
```

## Background Threads for Heavy Work

```swift
// Move JSON decoding off main thread
func loadItems() async {
    let data = try await URLSession.shared.data(from: url).0
    // Decoding happens on the calling task's thread (not necessarily main)
    let items = try JSONDecoder().decode([Item].self, from: data)
    // Assign to @MainActor property — automatically hops to main
    await MainActor.run { self.items = items }
}

// Image processing
func processImage(_ image: UIImage) async -> UIImage {
    // Runs on background thread via Task
    return await Task.detached(priority: .userInitiated) {
        image.applyFilter()  // CPU-intensive
    }.value
}

// Core Data: always fetch on background context
func loadRecords() async throws -> [Record] {
    try await container.performBackgroundTask { context in
        let request = NSFetchRequest<Record>(entityName: "Record")
        return try context.fetch(request)
    }
}
```

## Performance Anti-Patterns

| Anti-Pattern | Impact | Fix |
|---|---|---|
| `body` triggers network call | Re-renders spam network | Move to `.task` |
| `AnyView` in tight loop | Type erasure overhead | Use `@ViewBuilder` / `Group` |
| `ForEach` without `id` | O(n) diffing | Always provide stable `id` |
| Heavy work in `init` | Init called on every render | Lazy properties |
| Synchronous URLSession on main thread | Hang/freeze | async/await |
| UIImage created on main thread in table | Scroll jank | Background decode |
| Core Data fetch on `viewContext` for bulk import | Main thread block | `newBackgroundContext()` |
| Retained `self` in escaping closure | Memory leak | `[weak self]` |

## SwiftUI Rendering Optimization

```swift
// drawingGroup() — renders subtree to Metal layer
// Use for views with many overlapping transparent layers
ComplexOverlayView()
    .drawingGroup()

// compositingGroup() — treat as single layer for effects
View1().overlay(View2())
    .compositingGroup()
    .opacity(0.8)

// Reduce view identity changes (SwiftUI destroys/recreates on identity change)
// Bad: ForEach(items.filter { $0.isActive }) — changes size → triggers recreation
// Good: ForEach(items) { item in ItemRow(item: item).opacity(item.isActive ? 1 : 0) }
```
