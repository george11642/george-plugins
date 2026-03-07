---
name: android-dev
description: Master skill for Android Native Development with Kotlin and Jetpack Compose. Use when building Android apps, writing Kotlin code, implementing Jetpack Compose UI, managing Android architecture (MVVM, Clean Architecture), working with Coroutines and Flow, StateFlow, SharedFlow, ViewModel, Room database, Retrofit networking, OkHttp, Hilt dependency injection, Navigation component, Material 3, dynamic color, dark theme, WorkManager background tasks, FCM push notifications, foreground services, LazyColumn performance, recomposition optimization, state hoisting, CompositionLocal, Modifier chain ordering, App Bundle (AAB), ProGuard, R8, Play Store submission, staged rollout, Google Play Console, Firebase App Distribution, Fastlane, GitHub Actions CI/CD, unit testing with MockK and Turbine, Compose UI testing, Espresso, Paparazzi screenshot testing, Robolectric, Hilt testing, baseline profiles, LeakCanary memory leaks, StrictMode, Macrobenchmark, ANR debugging, CPU profiler, Memory profiler, foldable device support, large screen adaptive UI, WindowSizeClass, edge-to-edge display, WindowInsets, predictive back gesture, shared element transitions, Coil image loading, Kotlinx Serialization, multipart file upload, Android 15 features, API level targeting, kotlin coroutines patterns, CoroutineScope, Dispatchers, structured concurrency, callbackFlow, channelFlow, Flow operators, cancel coroutines.
---

# Android Native Development

## Task Router

| Task | Jump to |
|---|---|
| Jetpack Compose UI (composables, recomposition, state, layouts) | `references/jetpack-compose-fundamentals.md` |
| Kotlin Coroutines & Flow (StateFlow, SharedFlow, operators, testing) | `references/kotlin-coroutines-flow.md` |
| App Architecture (Clean Architecture, ViewModel, Hilt, Navigation, Use Cases) | `references/architecture-patterns.md` |
| Room database (entities, DAO, migrations, relations, testing) | `references/room-database.md` |
| Networking (Retrofit, OkHttp, Kotlinx Serialization, Coil, Ktor) | `references/networking-serialization.md` |
| Material 3 UI (components, theming, dark mode, adaptive UI, foldables) | `references/ui-material3.md` |
| Background work (WorkManager, AlarmManager, Services, FCM, Doze) | `references/background-work.md` |
| Testing (MockK, Turbine, Compose tests, Espresso, Paparazzi, Hilt) | `references/testing.md` |
| Play Store & CI/CD (AAB, signing, flavors, ProGuard, Fastlane, GitHub Actions) | `references/play-store-cicd.md` |
| Performance & debugging (Profilers, Baseline Profiles, LeakCanary, ANR, Macrobenchmark) | `references/performance-debugging.md` |

---

## Before Starting

Ask or verify before diving in:

1. **Min API level?** API 26 (Android 8) = safe default (95%+ device coverage). API 21 if you need maximum reach. API 31+ if you can drop legacy workarounds.
2. **Compose vs Views?** Default to Compose for all new screens. Only use Views if integrating into an existing View-based codebase or for custom SurfaceView-heavy work.
3. **Architecture?** Default: Clean Architecture + MVVM (ViewModel + StateFlow + Hilt). For small apps: skip domain layer Use Cases, keep flat repository pattern.
4. **Target API 35** (Android 15) required for all new Play Store submissions from August 2025.
5. **Enable edge-to-edge?** Yes for all new apps. `enableEdgeToEdge()` in Activity + use WindowInsets in Compose.
6. **KMP (Kotlin Multiplatform)?** If targeting iOS too, structure domain layer as pure Kotlin, use KMP-compatible libraries (Kotlinx Serialization, Ktor, SQLDelight instead of Room).

---

## Quick Reference

### Kotlin vs Java Interop

| Kotlin | Java Equivalent | Notes |
|---|---|---|
| `data class` | POJO + equals/hashCode/toString | Add `@JvmRecord` for record compat |
| `object` | Singleton class | `INSTANCE` field exposed to Java |
| `companion object` | `static` methods/fields | Use `@JvmStatic`, `@JvmField` for clean Java access |
| `val`/`var` | `final`/mutable field | Generates getter/setter by default |
| `fun` | method | `@JvmOverloads` for default args |
| `suspend fun` | Not directly callable | Wrap with `CoroutinesKt.future()` or RxJava bridge |
| `sealed class` | Abstract class | Each subclass must be in same package/file |
| `extension fun` | Utility static method | Not inheritable, resolved at compile time |
| `inline fun` | Can't inline in Java | Java sees it as regular function |

### API Level Feature Table (Recent)

| API | Android | Key Features for Developers |
|---|---|---|
| 26 | 8.0 Oreo | Notification channels (required), Background limits, Autofill |
| 28 | 9 Pie | Display cutout APIs, Privacy improvements, TLS 1.3 |
| 29 | 10 | Scoped storage, Dark theme, Bubble notifications |
| 30 | 11 | One-time permissions, Scoped storage enforced, Package visibility |
| 31 | 12 | Exact alarm permission, Splash Screen API, dynamic color (Material You) |
| 32 | 12L | Large screen APIs, WindowSizeClass |
| 33 | 13 | Photo picker, Notification permission, Predictive back (developer opt-in) |
| 34 | 14 | Photo picker improvements, Health Connect, Credential Manager |
| 35 | 15 | Edge-to-edge enforced, predictive back enforced, SQLite improvements, new foreground service types |

---

## Decision Trees

### WorkManager vs AlarmManager vs Foreground Service

```
Do you need the work to run even if the app is killed?
├─ YES → WorkManager
│        ├─ Time-sensitive (start immediately)? → .setExpedited()
│        ├─ Periodic? → PeriodicWorkRequest (min 15 min)
│        └─ Chained pipeline? → WorkContinuation
└─ NO → viewModelScope / LifecycleScope coroutine

Do you need an exact time trigger (calendar reminder, alarm clock)?
├─ YES → AlarmManager.setExactAndAllowWhileIdle()
│        └─ Android 12+: check canScheduleExactAlarms() first
└─ NO → WorkManager with flex window

Is it an ongoing operation visible to the user (music, GPS, download)?
└─ YES → Foreground Service (declare type in manifest)
         └─ Android 14: must declare foregroundServiceType

System event reaction (boot, connectivity change, SMS)?
└─ YES → BroadcastReceiver
         ├─ App must be running → runtime register + unregister
         └─ App may be stopped → manifest register (system broadcasts only)
```

### Flow vs LiveData

```
Are you in a 100% Compose project?
├─ YES → Use Flow / StateFlow everywhere
│        └─ Collect with collectAsStateWithLifecycle() in Compose
└─ NO (Views + Compose hybrid) →
     ├─ ViewModel → UI state → StateFlow.asLiveData() for View binding
     └─ Compose screens → StateFlow + collectAsStateWithLifecycle()

Flow wins over LiveData when:
- Need operators (map, filter, combine, debounce)
- Need coroutine integration (callbackFlow, channelFlow)
- Targeting KMP
- Writing unit tests (Turbine > LiveData testing)

LiveData still useful when:
- Existing View-based codebase
- Need automatic lifecycle awareness without coroutines
```

### Room vs DataStore

```
What are you storing?
├─ Structured relational data (users, articles, relationships) → Room
│   └─ Need full-text search? → Add FTS table with @Fts4/@Fts5
├─ Simple key-value preferences (settings, flags, user prefs) → DataStore Preferences
│   └─ Typed proto data with schema? → DataStore Proto
└─ Large binary blobs (images, documents) → File system + Room for metadata

Never use SharedPreferences in new code — DataStore is its replacement.
Room and DataStore can coexist in the same app.
```

### Coroutine Dispatcher Selection

```
What kind of work?
├─ UI update / Compose state write → Dispatchers.Main
├─ Network / File I/O / Database → Dispatchers.IO
├─ CPU-intensive (JSON parsing, image processing, crypto) → Dispatchers.Default
└─ Testing → UnconfinedTestDispatcher / StandardTestDispatcher
```

---

## Architecture Quick-Start Template

```kotlin
// Standard layer stack for a new feature:

// 1. Domain model (pure Kotlin)
data class Article(val id: String, val title: String, val isBookmarked: Boolean)

// 2. Repository interface (domain layer)
interface ArticleRepository {
    fun getArticles(category: String): Flow<List<Article>>
    suspend fun toggleBookmark(id: String)
}

// 3. Use Case (optional for simple delegation, useful for business rules)
class GetArticlesUseCase @Inject constructor(val repo: ArticleRepository) {
    operator fun invoke(category: String) = repo.getArticles(category)
}

// 4. UiState
sealed interface ArticleUiState {
    data object Loading : ArticleUiState
    data class Success(val articles: List<Article>) : ArticleUiState
    data class Error(val msg: String) : ArticleUiState
}

// 5. ViewModel
@HiltViewModel
class ArticleViewModel @Inject constructor(getArticles: GetArticlesUseCase) : ViewModel() {
    val uiState: StateFlow<ArticleUiState> = getArticles("tech")
        .map<List<Article>, ArticleUiState> { ArticleUiState.Success(it) }
        .onStart { emit(ArticleUiState.Loading) }
        .catch { e -> emit(ArticleUiState.Error(e.message ?: "")) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ArticleUiState.Loading)
}

// 6. Composable
@Composable
fun ArticleScreen(vm: ArticleViewModel = hiltViewModel()) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    when (state) {
        is ArticleUiState.Loading -> CircularProgressIndicator()
        is ArticleUiState.Success -> ArticleList((state as ArticleUiState.Success).articles)
        is ArticleUiState.Error -> ErrorMessage((state as ArticleUiState.Error).msg)
    }
}
```

---

## Common Gotchas

- **CancellationException must always be rethrown** — catching it silently breaks structured concurrency
- **Never use GlobalScope** — no structured concurrency, leaks survive app process
- **StateFlow replays last value on rotation** — use SharedFlow for one-shot navigation/snackbar events
- **Room @Query returning Flow** — auto-updates on any table change; use `@Query` with `LIMIT` for performance
- **Compose List stability** — use `ImmutableList` from kotlinx-collections-immutable, not stdlib `List`, for stable composable params
- **`stateIn` with `WhileSubscribed(5_000)`** — 5s grace period handles screen rotation without re-fetching
- **Hilt `@ViewModelScoped`** — requires `@InstallIn(ViewModelComponent::class)`, not `SingletonComponent`
- **Play Store AAB mandatory** — target API 35 required for new/updated apps from August 2025
- **Edge-to-edge enforced on Android 15** — `enableEdgeToEdge()` + `WindowInsets` handling required
- **`collectAsState` vs `collectAsStateWithLifecycle`** — always prefer the latter; saves battery by pausing when backgrounded
