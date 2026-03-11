---
name: mobile-native
description: Use when building mobile apps with Expo, React Native, iOS (Swift/SwiftUI), or Android (Kotlin/Jetpack Compose). Triggers on mobile app, native app, React Native, Expo, Expo Router, EAS Build, NativeWind, SwiftUI, Swift, UIKit, Xcode, iOS, macOS, watchOS, visionOS, SwiftData, NavigationStack, Jetpack Compose, Kotlin, Coroutines, Flow, Room, Retrofit, Hilt, Material 3, Play Store, App Store, TestFlight, mobile CI/CD, OTA updates, native UI, Reanimated, native animations, mobile performance, DOM components, native data fetching.
---

# Mobile & Native Development

Unified skill for cross-platform (Expo/React Native) and platform-native (iOS/Swift, Android/Kotlin) mobile development. Covers UI, navigation, data, deployment, and performance across all mobile platforms.

## Task Router

### Expo / React Native (Cross-Platform)

| Task | Reference |
|------|-----------|
| Expo Router file conventions, dynamic routes, groups | [references/route-structure.md](references/route-structure.md) |
| Native tab bar, NativeTabs, iOS 26 features | [references/tabs.md](references/tabs.md) |
| SF Symbols with expo-symbols, icon animations | [references/icons.md](references/icons.md) |
| Native iOS controls (Switch, Slider, Picker) | [references/controls.md](references/controls.md) |
| Blur effects, liquid glass (expo-glass-effect) | [references/visual-effects.md](references/visual-effects.md) |
| Reanimated animations, gestures, scroll-driven | [references/animations.md](references/animations.md) |
| Search bar integration, useSearch hook, filtering | [references/search.md](references/search.md) |
| CSS gradients (experimental_backgroundImage) | [references/gradients.md](references/gradients.md) |
| Camera, audio, video, file saving | [references/media.md](references/media.md) |
| SQLite, AsyncStorage, SecureStore | [references/storage.md](references/storage.md) |
| WebGPU, Three.js, 3D graphics | [references/webgpu-three.md](references/webgpu-three.md) |
| Stack headers, toolbar buttons, menus | [references/toolbar-and-headers.md](references/toolbar-and-headers.md) |
| Form sheets, modals, detents | [references/form-sheet.md](references/form-sheet.md) |
| Tailwind v4 + NativeWind v5 setup | [references/tailwind-setup.md](references/tailwind-setup.md) |
| API routes (+api.ts), EAS Hosting | [references/api-routes.md](references/api-routes.md) |
| EAS Workflows, CI/CD YAML | [references/cicd.md](references/cicd.md) |
| Dev client, native module testing | [references/dev-client.md](references/dev-client.md) |
| Deployment orchestration | [references/deployment.md](references/deployment.md) |
| TestFlight beta testing | [references/testflight.md](references/testflight.md) |
| iOS App Store submission | [references/ios-app-store.md](references/ios-app-store.md) |
| Google Play Store submission | [references/play-store.md](references/play-store.md) |
| App Store metadata and ASO | [references/app-store-metadata.md](references/app-store-metadata.md) |
| EAS Workflows for deploys | [references/workflows.md](references/workflows.md) |
| SDK upgrades, breaking changes | [references/upgrading.md](references/upgrading.md) |
| New Architecture migration | [references/new-architecture.md](references/new-architecture.md) |
| React 19 changes | [references/react-19.md](references/react-19.md) |
| React Compiler setup | [references/react-compiler.md](references/react-compiler.md) |
| Native Tabs (SDK 55) | [references/native-tabs.md](references/native-tabs.md) |
| expo-av to expo-audio migration | [references/expo-av-to-audio.md](references/expo-av-to-audio.md) |
| expo-av to expo-video migration | [references/expo-av-to-video.md](references/expo-av-to-video.md) |
| Performance profiling, Hermes, 60 FPS | [references/performance-profiling.md](references/performance-profiling.md) |
| Version management, buildNumber | [references/eas-version-management.md](references/eas-version-management.md) |
| OTA updates, EAS Update, channels | [references/eas-update-strategy.md](references/eas-update-strategy.md) |
| Streaming responses, expo/fetch, SSE | [references/expo-fetch-streaming.md](references/expo-fetch-streaming.md) |
| DOM components (web code in native webview) | [references/dom-components.md](references/dom-components.md) |
| Network requests, React Query, caching, offline | [references/data-fetching.md](references/data-fetching.md) |

### React Native Performance Rules (Vercel)

| Task | Reference |
|------|-----------|
| FlashList, virtualization, item memoization | `references/list-performance-*.md` |
| GPU animations, derived values, gesture detection | `references/animation-*.md` |
| Native navigators over JS navigators | [references/navigation-native-navigators.md](references/navigation-native-navigators.md) |
| expo-image, Pressable, safe areas, menus, modals | `references/ui-*.md` |
| State minimization, dispatcher pattern, React Compiler | `references/react-state-*.md`, `references/react-compiler-*.md` |
| Monorepo native deps, single versions | `references/monorepo-*.md` |
| Font config plugins, design system imports | `references/fonts-*.md`, `references/imports-*.md` |

### iOS Native (Swift / SwiftUI)

| Task | Reference |
|------|-----------|
| SwiftUI views, @State/@Observable, view lifecycle | [references/swiftui-fundamentals.md](references/swiftui-fundamentals.md) |
| async/await, actors, TaskGroup, AsyncStream | [references/swift-concurrency.md](references/swift-concurrency.md) |
| NavigationStack, MVVM, TCA, modular architecture | [references/navigation-architecture.md](references/navigation-architecture.md) |
| SwiftData, Core Data, Keychain, FileManager | [references/data-persistence.md](references/data-persistence.md) |
| URLSession, Codable, Alamofire, cert pinning | [references/networking-async.md](references/networking-async.md) |
| Animations, Canvas, Metal, Instruments | [references/ui-animation-performance.md](references/ui-animation-performance.md) |
| APNs, push notifications, WidgetKit | [references/push-notifications-widgets.md](references/push-notifications-widgets.md) |
| XCTest, ViewInspector, UI tests, LLDB | [references/testing-debugging.md](references/testing-debugging.md) |
| App Store Connect, code signing, Fastlane | [references/app-store-submission.md](references/app-store-submission.md) |
| VoiceOver, Dynamic Type, localization | [references/accessibility-localization.md](references/accessibility-localization.md) |

### Android Native (Kotlin / Jetpack Compose)

| Task | Reference |
|------|-----------|
| Compose UI, recomposition, state, layouts | [references/jetpack-compose-fundamentals.md](references/jetpack-compose-fundamentals.md) |
| Coroutines, Flow, StateFlow, SharedFlow | [references/kotlin-coroutines-flow.md](references/kotlin-coroutines-flow.md) |
| Clean Architecture, ViewModel, Hilt, Navigation | [references/architecture-patterns.md](references/architecture-patterns.md) |
| Room database, entities, DAO, migrations | [references/room-database.md](references/room-database.md) |
| Retrofit, OkHttp, Kotlinx Serialization, Coil | [references/networking-serialization.md](references/networking-serialization.md) |
| Material 3, theming, dark mode, adaptive UI | [references/ui-material3.md](references/ui-material3.md) |
| WorkManager, Services, FCM, Doze | [references/background-work.md](references/background-work.md) |
| MockK, Turbine, Compose tests, Espresso | [references/testing.md](references/testing.md) |
| Play Store CI/CD, AAB, signing, ProGuard | [references/play-store-cicd.md](references/play-store-cicd.md) |
| Profilers, Baseline Profiles, LeakCanary | [references/performance-debugging.md](references/performance-debugging.md) |

## Platform Decision Tree

```
Building a mobile app?
  Cross-platform (iOS + Android)?
    YES -> Expo / React Native (default choice)
    NO -> Which platform?
      iOS only -> Swift + SwiftUI (iOS 17+: SwiftData + @Observable)
      Android only -> Kotlin + Jetpack Compose + Hilt
```

## Layer 3 Skills

- **deploy-vercel** — Vercel/EAS deployment configuration
- **testing-quality** — Mobile testing, XCTest, Espresso, Detox
- **analytics-posthog** — Mobile analytics and event tracking
