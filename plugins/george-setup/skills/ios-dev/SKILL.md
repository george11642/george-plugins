---
name: ios-dev
description: Use when building iOS, macOS, watchOS, tvOS, or visionOS apps. Triggers: SwiftUI, Swift, UIKit, Xcode, iOS, macOS, watchOS, tvOS, visionOS, SwiftData, Core Data, Keychain, URLSession, Combine, async/await, actor, MainActor, Sendable, AsyncStream, NavigationStack, NavigationPath, NavigationLink, TabView, MVVM, TCA, The Composable Architecture, coordinator pattern, @State, @Binding, @Observable, @Model, @Query, @StateObject, @ObservedObject, @EnvironmentObject, App Store, TestFlight, Fastlane, Xcode Cloud, APNs, push notification, remote notification, WidgetKit, App Intents, StoreKit, in-app purchase, IAP, VoiceOver, Dynamic Type, localization, String Catalog, Localizable.strings, XCTest, snapshot test, ViewInspector, Instruments, Time Profiler, performance profiling, certificate, provisioning profile, code signing, match, deliver, gym, pilot, LazyVStack, LazyHStack, LazyVGrid, GeometryReader, Canvas, Metal, matched geometry effect, phase animator, keyframe animator, AccessibilityLabel, accessibilityHint, accessibilityValue, Codable, CodingKeys, JSONDecoder, Alamofire, RequestInterceptor, EventMonitor, certificate pinning, background URLSession, ModelContainer, ModelContext, NSPersistentContainer, NSFetchRequest, NSPredicate, UserDefaults, SecItem, FileManager, TaskGroup, async let, withCheckedContinuation.
---

# iOS Native Development

Master skill for iOS, macOS, watchOS, tvOS, and visionOS: SwiftUI, Swift concurrency, architecture patterns, data persistence, networking, testing, App Store submission, and the full native development ecosystem. Philosophy: type-safe Swift-native code using modern APIs (@Observable, SwiftData, async/await) over legacy patterns (Objective-C, DispatchQueue, Core Data where avoidable).

## Task Router

| Task | Reference |
|------|-----------|
| SwiftUI views, state management, @State/@Observable, view lifecycle, LazyVStack, ScrollView | [references/swiftui-fundamentals.md](references/swiftui-fundamentals.md) |
| async/await, actors, TaskGroup, AsyncStream, Swift 6 concurrency, Combine vs async | [references/swift-concurrency.md](references/swift-concurrency.md) |
| NavigationStack, NavigationPath, TabView, sheets, MVVM, TCA, DI, modular architecture | [references/navigation-architecture.md](references/navigation-architecture.md) |
| SwiftData, Core Data, UserDefaults, Keychain, FileManager, iCloud sync | [references/data-persistence.md](references/data-persistence.md) |
| URLSession, Codable, Alamofire, certificate pinning, background downloads, multipart | [references/networking-async.md](references/networking-async.md) |
| Animations, Canvas, Metal, Instruments, List performance, image caching | [references/ui-animation-performance.md](references/ui-animation-performance.md) |
| APNs, push notifications, rich notifications, WidgetKit, App Intents, FCM | [references/push-notifications-widgets.md](references/push-notifications-widgets.md) |
| XCTest, ViewInspector, UI tests, snapshot tests, mocking, LLDB, OSLog | [references/testing-debugging.md](references/testing-debugging.md) |
| App Store Connect, code signing, Fastlane, Xcode Cloud, StoreKit 2, ASO | [references/app-store-submission.md](references/app-store-submission.md) |
| VoiceOver, Dynamic Type, localization, String Catalog, RTL, locale formatting | [references/accessibility-localization.md](references/accessibility-localization.md) |

## Before Starting

Ask yourself:
1. **Minimum iOS target?** iOS 17+: use SwiftData + @Observable. iOS 16+: use NavigationStack. iOS 15-: Core Data + ObservableObject.
2. **SwiftUI vs UIKit?** SwiftUI for new screens. UIKit for: complex custom drawing, mature third-party libs that need UIViewController, or when inheriting a UIKit codebase.
3. **Architecture?** MVVM for most apps. TCA for large teams with complex state. Coordinator for deep UIKit interop.
4. **Data persistence?** SwiftData (iOS 17+, simple) vs Core Data (iOS 15-, iCloud sync, complex migrations).
5. **Async pattern?** async/await for one-shot operations. AsyncStream for value streams. Combine only if already in use or need specific operators.

## Quick Reference

### iOS Version Feature Table

| iOS | Key APIs |
|-----|----------|
| iOS 17 | @Observable, SwiftData, TipKit, interactive widgets, String Catalog, containerBackground |
| iOS 16 | NavigationStack, NavigationPath, presentationDetents, .task(id:), Charts |
| iOS 15 | async/await, .refreshable, .searchable, AttributedString |
| iOS 14 | LazyVStack/HStack/VGrid, @StateObject, .onChange, WidgetKit |
| iOS 13 | SwiftUI, Combine, SF Symbols, Sign in with Apple |

### Swift vs Objective-C Interop

```swift
// Expose Swift to ObjC
@objc class MyClass: NSObject {
    @objc var name: String = ""
    @objc func doWork() { }
}

// Use ObjC from Swift
// Import via bridging header: #import "Legacy.h"
// Or via module map

// Swift enums in ObjC
@objc enum Status: Int { case active, inactive }  // must be Int-backed

// Cannot expose: generics, structs (non-NSObject), tuples, Swift-only protocols
```

### Package Management

```swift
// Swift Package Manager (preferred)
// File → Add Package Dependencies → paste GitHub URL

// Podfile (CocoaPods — legacy but widely used)
platform :ios, '16.0'
target 'MyApp' do
  use_frameworks!
  pod 'Alamofire', '~> 5.9'
  pod 'Kingfisher', '~> 7.0'
end
```

## Decision Trees

### SwiftUI vs UIKit

```
Building a new screen from scratch?
  YES → SwiftUI (unless below exception)
  NO (modifying UIKit screen) → UIKit

Need any of these?
  - Complex drag-and-drop with custom hit-testing
  - UIPageViewController
  - MKMapView with heavy customization
  - AVPlayerViewController
  - Third-party lib requiring UIViewController subclass
  → UIKit; wrap in UIViewControllerRepresentable if embedding in SwiftUI

Targeting iOS 12 or earlier?
  → UIKit only (no SwiftUI)

Default → SwiftUI
```

### SwiftData vs Core Data

```
Minimum deployment target >= iOS 17?
  NO → Core Data

App needs NSPersistentCloudKitContainer (iCloud sync with conflict resolution)?
  YES → Core Data

Need NSFetchedResultsController (animating table/collection updates)?
  YES → Core Data

Need complex migrations with custom NSMigrationPolicy?
  YES → Core Data

Simple CRUD with models, iOS 17+?
  YES → SwiftData (less code, @Model macro, @Query)

Default for new iOS 17+ apps → SwiftData
```

### async/await vs Combine

```
One-shot operation (fetch, save, compute)?
  → async/await

Values produced over time (location, WebSocket, user input)?
  → AsyncStream (if new code) or Combine (if existing pipeline)

Need operators (debounce, throttle, zip, combineLatest)?
  → Combine (these don't exist natively in async/await)

Converting callback API once?
  → withCheckedContinuation

Existing Combine code?
  → Keep it; .values property converts Publisher to AsyncSequence when needed

Default for new code → async/await
```

## Core Principles

1. **@MainActor on ViewModels** — all published state changes must happen on the main thread; annotate the whole class rather than individual properties
2. **Value types for models** — structs over classes for domain models; classes only when identity matters or you need reference semantics
3. **Protocol-first services** — `protocol ItemServiceProtocol` enables mock injection for testing; never `let service = ItemService()` in ViewModel init without a default
4. **Never block the main thread** — JSON decoding, image processing, Core Data fetches: always on background task
5. **Profile before optimizing** — Instruments Time Profiler first, then fix the actual hot path
6. **Semantic colors** — `Color(.label)`, `Color(.systemBackground)` not `Color.black`/`Color.white`; they adapt to dark mode
7. **Accessibility identifiers for UI tests** — add `.accessibilityIdentifier()` to interactive elements from day one
8. **Keychain for credentials** — never UserDefaults for tokens, passwords, or API keys
