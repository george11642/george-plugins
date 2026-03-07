# Swift Concurrency

## async/await Basics

```swift
// Mark a function async to allow suspension
func fetchUser(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Call with await — suspends without blocking the thread
let user = try await fetchUser(id: 42)
```

**Why async/await over completion handlers**: Straight-line code, structured error handling with `throws`, eliminates retain cycle risks, composable with `async let` and task groups, compiler-enforced suspension points.

## Task — Structured vs Unstructured

```swift
// Structured (child of current task — inherits priority, cancellation)
func processItems(_ items: [Item]) async {
    for item in items {
        await processOne(item)  // sequential
    }
}

// Unstructured — creates a new top-level task
// Use in non-async contexts (e.g., button action)
Button("Load") {
    Task {
        do {
            data = try await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Detached — no inheritance of actor, priority, or task-locals
Task.detached(priority: .background) {
    await expensiveBackgroundWork()
}
```

**Rule**: Prefer structured tasks. Use `Task { }` in SwiftUI button actions. Use `Task.detached` only when you explicitly don't want actor inheritance (rare).

## async let — Parallel Execution

```swift
// Sequential: ~2 seconds total
let user = try await fetchUser(id: 1)
let posts = try await fetchPosts(for: 1)

// Parallel with async let: ~1 second (runs concurrently)
async let user = fetchUser(id: 1)
async let posts = fetchPosts(for: 1)
let (resolvedUser, resolvedPosts) = try await (user, posts)
```

Use `async let` when you have a **fixed** number of concurrent operations. Use `TaskGroup` for a **dynamic** number.

## TaskGroup — Dynamic Concurrency

```swift
// Throwing task group
let results = try await withThrowingTaskGroup(of: User.self) { group in
    for id in userIDs {
        group.addTask { try await fetchUser(id: id) }
    }
    var users: [User] = []
    for try await user in group {
        users.append(user)
    }
    return users
}

// Bounded concurrency (avoid overwhelming server)
let results = try await withThrowingTaskGroup(of: User.self) { group in
    var active = 0
    let maxConcurrent = 5
    var iterator = userIDs.makeIterator()

    // Seed initial batch
    while active < maxConcurrent, let id = iterator.next() {
        group.addTask { try await fetchUser(id: id) }
        active += 1
    }
    var users: [User] = []
    for try await user in group {
        users.append(user)
        if let id = iterator.next() {
            group.addTask { try await fetchUser(id: id) }
        }
    }
    return users
}
```

## Actor Isolation

Actors protect mutable state from data races. Only one task accesses actor state at a time.

```swift
actor DataCache {
    private var store: [String: Data] = [:]

    func get(_ key: String) -> Data? { store[key] }
    func set(_ key: String, value: Data) { store[key] = value }

    // nonisolated for pure computations that don't touch mutable state
    nonisolated func cacheKey(for url: URL) -> String {
        url.absoluteString.sha256()
    }
}

let cache = DataCache()
await cache.set("key", value: data)  // requires await from outside
```

## MainActor — UI Updates

`@MainActor` ensures code runs on the main thread.

```swift
// Annotate entire class — all methods run on main thread
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func loadItems() async {
        let fetched = await fetchItems()  // suspends, work done off main
        items = fetched  // back on main (guaranteed by @MainActor)
    }
}

// Hop to main thread for a specific operation
await MainActor.run {
    self.label.text = "Done"
}

// Annotate a single method
@MainActor
func updateUI() { }
```

**SwiftUI rule**: `@MainActor` on your `@Observable` / `ObservableObject` ViewModels is correct. SwiftUI's `body` already runs on the main thread.

## @Sendable — Safe Data Transfer

`Sendable` means a type can be safely passed across concurrency boundaries (no shared mutable state).

```swift
// Structs with Sendable stored properties are implicitly Sendable
struct UserProfile: Sendable {
    let id: Int
    let name: String
}

// @Sendable on closures — captured values must also be Sendable
func process(items: [Item], completion: @Sendable @escaping () -> Void) { }

// Class conformance requires explicit thread-safety guarantee
final class Config: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: String = ""
    var value: String {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
```

## AsyncStream — Reactive Patterns

Replace Combine with `AsyncStream` for sequences of values over time:

```swift
// Create a stream from a callback-based API
let locationStream = AsyncStream<CLLocation> { continuation in
    let manager = LocationManager()
    manager.onLocation = { loc in continuation.yield(loc) }
    manager.onStop = { continuation.finish() }
    continuation.onTermination = { _ in manager.stop() }
    manager.start()
}

// Consume
for await location in locationStream {
    await updateMap(location)
}

// AsyncThrowingStream for fallible sources
let dataStream = AsyncThrowingStream<Data, Error> { continuation in
    socket.onData = { data in continuation.yield(data) }
    socket.onError = { error in continuation.finish(throwing: error) }
}
```

## Combine vs async/await Decision Tree

```
Does the source emit values over time? (user input, location, WebSocket)
  YES → AsyncStream or Combine Publisher
  NO (one-shot fetch/operation) → async/await

Using Combine already and need operators (debounce, zip, combineLatest)?
  YES → keep Combine for that pipeline
  NO → async/await is simpler

SwiftUI @Published still uses Combine internally — OK to mix
```

## Continuations — Bridging Callback APIs

```swift
// Wrap a callback-based API in async
func fetchImage(url: URL) async throws -> UIImage {
    try await withCheckedThrowingContinuation { continuation in
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let data = data, let image = UIImage(data: data) {
                continuation.resume(returning: image)
            } else {
                continuation.resume(throwing: URLError(.badServerResponse))
            }
        }.resume()
    }
}
```

**Rules**: Resume exactly once — resuming zero times leaks the task, resuming twice crashes. Use `withCheckedContinuation` (debug checks) not `withUnsafeContinuation` unless profiling shows it matters.

## Task Cancellation

```swift
func downloadFiles(urls: [URL]) async throws -> [Data] {
    var results: [Data] = []
    for url in urls {
        try Task.checkCancellation()  // throws CancellationError if cancelled
        let (data, _) = try await URLSession.shared.data(from: url)
        results.append(data)
    }
    return results
}

// Check without throwing
if Task.isCancelled { return }

// Cancel from outside
let task = Task { try await downloadFiles(urls: urls) }
task.cancel()

// URLSession respects cancellation automatically
// Custom cancellation via onTermination in AsyncStream
```

## Swift 6 Strict Concurrency

Swift 6 makes data race safety a compile error (not a warning).

```swift
// Enable in Package.swift
.target(
    name: "MyApp",
    swiftSettings: [.swiftLanguageVersion(.v6)]
)

// Common migration patterns:
// 1. Add @MainActor to ViewModels
// 2. Make value types Sendable (usually automatic for structs)
// 3. Use actors for shared mutable state
// 4. nonisolated(unsafe) as escape hatch (rarely)

// Global actor for module-wide isolation
@globalActor
actor DatabaseActor: GlobalActor {
    static let shared = DatabaseActor()
}

@DatabaseActor
func saveRecord(_ record: Record) async throws { }
```

## Actors for Shared Mutable State — Real Pattern

```swift
actor RequestQueue {
    private var pending: [URLRequest] = []
    private var inFlight = 0
    private let maxConcurrent = 3

    func enqueue(_ request: URLRequest) async throws -> Data {
        pending.append(request)
        return try await drainNext()
    }

    private func drainNext() async throws -> Data {
        guard inFlight < maxConcurrent, !pending.isEmpty else { return Data() }
        let req = pending.removeFirst()
        inFlight += 1
        defer { inFlight -= 1 }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| `DispatchQueue.main.async { }` in async context | Use `await MainActor.run { }` |
| Calling async func without `await` | Compiler error — good |
| Fire-and-forget in `@MainActor` class | `Task { await work() }` — structured |
| `Thread.sleep` in async code | Use `try await Task.sleep(for: .seconds(1))` |
| Crossing actor boundary in tight loop | Batch work inside actor, return result |
| `@ObservedObject` on `@MainActor` class | Add `@MainActor` to ViewModel, use `@StateObject` |
