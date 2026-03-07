# Navigation and Architecture

## NavigationStack + NavigationPath (iOS 16+)

`NavigationStack` replaces `NavigationView`. Use `NavigationPath` for type-heterogeneous stacks.

```swift
// Simple homogeneous stack
struct AppView: View {
    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(item.title, value: item)
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetail(item: item)
            }
        }
    }
}

// Heterogeneous stack with NavigationPath
@Observable
class Router {
    var path = NavigationPath()

    func push<T: Hashable>(_ value: T) { path.append(value) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeLast(path.count) }
}

struct RootView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: ItemRoute.self) { route in
                    ItemDetail(item: route.item)
                }
                .navigationDestination(for: ProfileRoute.self) { route in
                    ProfileView(user: route.user)
                }
                .environment(router)
        }
    }
}
```

**Why NavigationPath**: Handles `Hashable` values of mixed types. Supports serialization via `Codable` for state restoration.

## Deep Linking with URL Handling

```swift
// Register URL scheme or universal link in Info.plist / Entitlements
// Handle in SwiftUI:

@main
struct MyApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    router.handle(url)
                }
        }
    }
}

// Router parses URL
extension Router {
    func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        switch components.path {
        case "/item":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                path.append(ItemRoute(id: id))
            }
        default: break
        }
    }
}
```

## TabView Patterns

```swift
struct MainTabView: View {
    @State private var selection = Tab.home

    enum Tab { case home, search, profile }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(Tab.profile)
        }
    }
}

// iOS 18+: TabView with new API
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Search", systemImage: "magnifyingglass") { SearchView() }
}
```

## Sheet, FullScreenCover, Popover

```swift
struct ContentView: View {
    @State private var showSheet = false
    @State private var selectedItem: Item?

    var body: some View {
        Button("Show Sheet") { showSheet = true }
            // Bool-based
            .sheet(isPresented: $showSheet) { SheetView() }
            // Item-based (preferred — nil hides, non-nil shows)
            .sheet(item: $selectedItem) { item in DetailSheet(item: item) }
            // Full screen
            .fullScreenCover(isPresented: $showSheet) { FullView() }
            // Popover (iPad shows popover, iPhone shows sheet)
            .popover(isPresented: $showSheet) { PopoverContent() }
    }
}

// Dismiss from inside a sheet
struct SheetView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Button("Done") { dismiss() }
    }
}

// iOS 16+: presentationDetents for bottom sheets
.sheet(isPresented: $showSheet) {
    SheetView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

## MVVM in SwiftUI

```swift
// ViewModel — @Observable (iOS 17+) or ObservableObject
@Observable
@MainActor
final class ItemListViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    private let service: ItemServiceProtocol

    init(service: ItemServiceProtocol = ItemService()) {
        self.service = service
    }

    func loadItems() async {
        isLoading = true
        do {
            items = try await service.fetchItems()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

// View — thin, reads from ViewModel
struct ItemListView: View {
    @State private var vm = ItemListViewModel()

    var body: some View {
        Group {
            if vm.isLoading { ProgressView() }
            else { List(vm.items) { ItemRow(item: $0) } }
        }
        .task { await vm.loadItems() }
        .alert("Error", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error?.localizedDescription ?? "") }
    }
}
```

## Coordinator Pattern in SwiftUI

Use a `Router` / `Coordinator` `@Observable` class injected via Environment:

```swift
// Protocol for testability
protocol AppCoordinator {
    func showItemDetail(_ item: Item)
    func showProfile()
    func dismiss()
}

@Observable
final class AppRouter: AppCoordinator {
    var path = NavigationPath()
    var sheet: Sheet?

    enum Sheet: Identifiable {
        case profile
        var id: Int { hashValue }
    }

    func showItemDetail(_ item: Item) { path.append(item) }
    func showProfile() { sheet = .profile }
    func dismiss() { sheet = nil }
}
```

## The Composable Architecture (TCA) — Overview

TCA (by Point-Free) provides unidirectional data flow with Reducer, State, Action, Effect:

```swift
@Reducer
struct CounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
    }
    enum Action {
        case incrementTapped
        case decrementTapped
    }
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .incrementTapped:
                state.count += 1
                return .none
            case .decrementTapped:
                state.count -= 1
                return .none
            }
        }
    }
}

struct CounterView: View {
    let store: StoreOf<CounterFeature>
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            HStack {
                Button("-") { viewStore.send(.decrementTapped) }
                Text("\(viewStore.count)")
                Button("+") { viewStore.send(.incrementTapped) }
            }
        }
    }
}
```

**Use TCA when**: Large team, complex state with side effects, need time-travel debugging. **Use MVVM when**: Smaller app, simpler state, less ceremony.

## Dependency Injection Patterns

### Environment-Based DI

```swift
// Register service in environment
private struct ItemServiceKey: EnvironmentKey {
    static let defaultValue: any ItemServiceProtocol = ItemService()
}

extension EnvironmentValues {
    var itemService: any ItemServiceProtocol {
        get { self[ItemServiceKey.self] }
        set { self[ItemServiceKey.self] = newValue }
    }
}

// Inject at root
ContentView()
    .environment(\.itemService, MockItemService())  // for previews/tests

// Read in any view or ViewModel via @Environment
@Environment(\.itemService) var service
```

### DI Container (for complex apps)

```swift
final class AppContainer {
    static let shared = AppContainer()

    lazy var networkClient: NetworkClient = NetworkClient()
    lazy var itemRepo: ItemRepository = ItemRepository(client: networkClient)
    lazy var authService: AuthService = AuthService(client: networkClient)
}

// Inject via initializer in ViewModel
init(repo: ItemRepository = AppContainer.shared.itemRepo) { }
```

## Modular App Architecture

```
MyApp/
  App/              # @main, AppDelegate, root navigation
  Features/
    ItemList/       # Feature module: View + ViewModel + Tests
    ItemDetail/
    Auth/
  Core/
    Networking/     # NetworkClient, Endpoint protocol
    Persistence/    # SwiftData/CoreData stack
    Models/         # Shared domain models
  DesignSystem/     # Reusable UI components
```

**Swift Package Manager for modules**: Extract `Core` and `DesignSystem` into local packages for compile-time isolation and faster incremental builds.

```swift
// Package.swift (local package)
.target(name: "CoreNetworking", dependencies: []),
.target(name: "DesignSystem", dependencies: ["CoreNetworking"]),
```

## Navigation Gotchas

| Issue | Fix |
|-------|-----|
| Multiple `.navigationDestination` for same type | Only one wins — put all destinations in the root `NavigationStack` view |
| `NavigationLink` inside `List` causes double tap | Use `NavigationLink(value:)` not `NavigationLink(destination:)` |
| Sheet not dismissing | Ensure `dismiss()` called from the presented view's environment |
| NavigationPath not serializing | Types must conform to `Codable` for `.codable` representation |
| Deep link not updating path | Call `path.removeLast(path.count)` before appending deep link destination |
