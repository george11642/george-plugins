# Performance & Debugging

## Android Studio Profilers

### CPU Profiler
```
Android Studio → View → Tool Windows → Profiler → CPU tab

Two capture modes:
1. Method Trace (Java/Kotlin): per-method timing, call stack, shows own vs total time
   Best for: finding slow methods, N+1 problems

2. System Trace (Perfetto): lightweight, production-safe, shows threads + system calls
   Best for: jank (frames >16ms), thread contention, coroutine scheduling

Start recording: click "Record" button, exercise the slow code path, stop
```

```kotlin
// Inline markers in system trace
import androidx.tracing.trace

fun expensiveOperation() {
    trace("myapp:expensiveOperation") {
        // code here appears as labeled slice in system trace
        processData()
    }
}

// Or with TraceCompat
TraceCompat.beginSection("MySection")
doWork()
TraceCompat.endSection()
```

### Memory Profiler
```
Android Studio → Profiler → Memory tab

Actions:
- "Capture heap dump" → snapshot of all live objects
- "Record native allocations" → C/C++ allocations
- "Record allocations" → track object creation over time

Analyze heap dump:
1. Filter by package to find your objects
2. Look for retained size >> shallow size (indicates holding references)
3. "Dominators" tab shows largest memory consumers
4. Compare two heap dumps to find leaks (objects that grew between snapshots)
```

---

## StrictMode

```kotlin
// Enable in Application.onCreate() for debug builds only
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            StrictMode.setThreadPolicy(
                StrictMode.ThreadPolicy.Builder()
                    .detectAll()                    // disk reads, network, custom slow calls
                    .penaltyLog()                   // LogCat output
                    // .penaltyDeath()              // crash on violation (aggressive but effective)
                    .penaltyFlashScreen()
                    .build()
            )
            StrictMode.setVmPolicy(
                StrictMode.VmPolicy.Builder()
                    .detectAll()                    // leaks, closeable not closed, etc.
                    .detectLeakedSqlLiteObjects()
                    .detectLeakedClosableObjects()
                    .detectActivityLeaks()
                    .penaltyLog()
                    .build()
            )
        }
    }
}

// Example violation to catch: disk read on main thread
// Solution: move to Dispatchers.IO
```

---

## LeakCanary

```kotlin
// Add to debug dependencies ONLY:
// debugImplementation("com.squareup.leakcanary:leakcanary-android:2.14")
// No code change needed — automatically hooked into Activity/Fragment/ViewModel lifecycle

// Common leak patterns to fix:
// 1. Static reference to Context/View → use WeakReference or ApplicationContext
// 2. Inner class holding outer Activity reference → use static inner class
// 3. Handler/Runnable not cancelled on destroy → cancel in onDestroy()
// 4. BroadcastReceiver not unregistered → unregister in onStop()/onDestroy()
// 5. Singleton holding Activity context → use Application context

// Manual leak detection
AppWatcher.objectWatcher.expectWeaklyReachable(
    myObject,
    "MyObject should be GC'd after use"
)
```

---

## Baseline Profiles

Baseline Profiles pre-compile hot code paths, improving startup by 20-40% and scrolling smoothness.

```kotlin
// Dependencies:
// androidTestImplementation("androidx.benchmark:benchmark-macro-junit4:1.3.3")
// implementation("androidx.profileinstaller:profileinstaller:1.3.1")

// Create baseline profile generator
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {
    @get:Rule
    val baselineProfileRule = BaselineProfileRule()

    @Test
    fun generateBaselineProfile() = baselineProfileRule.collect(
        packageName = "com.example.myapp"
    ) {
        // Define critical user journeys
        pressHome()
        startActivityAndWait()  // Cold start

        // Navigate through main flow
        device.findObject(By.text("Articles")).click()
        device.waitForIdle()

        // Scroll to trigger composition/layout
        val list = device.findObject(By.res("article_list"))
        list.fling(Direction.DOWN)
        device.waitForIdle()
    }
}

// In build.gradle.kts — enable baseline profile generation
plugins {
    id("androidx.baselineprofile")
}

baselineProfile {
    automaticGenerationDuringBuild = false  // generate manually
    enableEmulatorDisplay = false
}

// Generate: ./gradlew generateBaselineProfile
// Output: src/main/baseline-prof.txt (commit to VCS)

// Startup profiles (DEX layout optimization)
// baselineProfile.baselineProfileOutputDir = "."
// Creates baseline-prof.txt with startup-critical classes
```

---

## App Startup Optimization

```kotlin
// App Startup library — control initialization order, lazy init
// implementation("androidx.startup:startup-runtime:1.1.1")

// Define initializer
class TimberInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        if (BuildConfig.DEBUG) Timber.plant(Timber.DebugTree())
    }
    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}

class FirebaseInitializer : Initializer<FirebaseApp> {
    override fun create(context: Context): FirebaseApp =
        FirebaseApp.initializeApp(context)!!
    override fun dependencies() = emptyList<Class<out Initializer<*>>>()
}

// AndroidManifest.xml — declare in provider (replaces individual ContentProviders)
// <provider android:name="androidx.startup.InitializationProvider"
//     android:authorities="${applicationId}.androidx-startup"
//     android:exported="false">
//     <meta-data android:name="com.example.TimberInitializer"
//         android:value="androidx.startup" />
// </provider>

// Lazy initialization — defer until first use
class LazyDependency : Initializer<LazyDependency> {
    override fun create(context: Context): LazyDependency {
        return this
    }
    override fun dependencies() = emptyList<Class<out Initializer<*>>>()
}

// In code, lazy init manually:
val heavyObject by lazy {
    HeavyObject()  // only created when first accessed
}

// Application.onCreate() — measure startup time
class MyApp : Application() {
    override fun onCreate() {
        val start = SystemClock.uptimeMillis()
        super.onCreate()
        Timber.d("App.onCreate took ${SystemClock.uptimeMillis() - start}ms")
    }
}
```

---

## Macrobenchmark

```kotlin
// Measure real-world performance with Macrobenchmark
// androidTestImplementation("androidx.benchmark:benchmark-macro-junit4:1.3.3")

@RunWith(AndroidJUnit4::class)
class StartupBenchmark {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun coldStartup() = benchmarkRule.measureRepeated(
        packageName = "com.example.myapp",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD
    ) {
        pressHome()
        startActivityAndWait()
    }

    @Test
    fun scrollingJank() = benchmarkRule.measureRepeated(
        packageName = "com.example.myapp",
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
        setupBlock = {
            startActivityAndWait()
        }
    ) {
        val list = device.findObject(By.res("article_list"))
        list.fling(Direction.DOWN)
        device.waitForIdle()
    }
}

// Run: ./gradlew :benchmarks:connectedBenchmarkAndroidTest
// Results appear in Android Studio Benchmark tab
```

---

## Compose Recomposition Debugging

```kotlin
// Layout Inspector — see recomposition counts in real time
// Android Studio → View → Tool Windows → Layout Inspector
// Enable "Show Recomposition Counts" toggle

// Compose recomposition counter (manual)
var recompositionCount by remember { mutableIntStateOf(0) }
SideEffect { recompositionCount++ }

// Stability debugging — detect unstable types causing recompositions
// Add to build.gradle.kts:
kotlinOptions {
    freeCompilerArgs += listOf(
        "-P", "plugin:androidx.compose.compiler.plugins.kotlin:reportsDestination=" +
                project.buildDir.absolutePath + "/compose_metrics"
    )
}
// Check build/compose_metrics/*-composables.csv for "skippable" column

// Runtime recomposition check (production-safe)
@Composable
fun DebugRecompositions(tag: String) {
    val count = remember { mutableIntStateOf(0) }
    SideEffect {
        count.value++
        Log.d("Recompose", "$tag recomposed ${count.value} times")
    }
}
```

---

## Systrace / Perfetto

```bash
# Capture system trace via adb
adb shell perfetto \
  -c - --txt \
  -o /data/misc/perfetto-traces/trace.perfetto-trace \
<<EOF
buffers: { size_kb: 63488 fill_policy: RING_BUFFER }
data_sources: { config { name: "linux.ftrace" ftrace_config { ftrace_events: "sched/sched_switch" atrace_categories: "am" atrace_categories: "view" atrace_categories: "gfx" atrace_categories: "res" } } }
data_sources: { config { name: "android.gpu.memory" } }
duration_ms: 10000
EOF

adb pull /data/misc/perfetto-traces/trace.perfetto-trace
# Open at https://ui.perfetto.dev/
```

Key things to look for in Perfetto:
- **Frame timeline**: frames >16ms (60fps) or >8.3ms (120fps) = jank
- **Main thread**: long synchronous operations = ANR risk
- **RenderThread**: heavy draws
- **Binder transactions**: cross-process calls on main thread

---

## ANR Analysis

ANR (Application Not Responding) = main thread blocked >5s or broadcast receiver >10s.

```kotlin
// Common ANR causes:
// 1. Disk I/O on main thread (StrictMode will catch this)
// 2. Network call on main thread
// 3. Long synchronous database query on main thread
// 4. Deadlock (two coroutines waiting for each other)
// 5. Slow View.onDraw() or measure/layout

// Pull ANR traces from device
// adb pull /data/anr/
// Open traces.txt — look for "main" thread with "waiting" state

// Prevent ANR:
// - Never block main thread (use withContext(Dispatchers.IO))
// - Keep onReceive() fast (<10s), use goAsync() for longer work

class MyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val result = goAsync()  // extends to ~10s
        CoroutineScope(Dispatchers.IO).launch {
            try {
                doLongWork()
            } finally {
                result.finish()
            }
        }
    }
}
```

---

## Memory Optimization

```kotlin
// Large bitmaps — decode at required size, not full resolution
val options = BitmapFactory.Options().apply {
    inJustDecodeBounds = true
    BitmapFactory.decodeFile(path, this)
    inSampleSize = calculateInSampleSize(this, reqWidth, reqHeight)
    inJustDecodeBounds = false
}
val bitmap = BitmapFactory.decodeFile(path, options)

// Prefer WebP for images (25-34% smaller than PNG, 25-34% smaller than JPEG)
// Vector drawables for icons (infinitely scalable, no pixel data)

// Avoid object allocation in hot paths (animations, RecyclerView bind)
// BAD: creates new String on every bind
override fun onBindViewHolder(holder: ViewHolder, position: Int) {
    holder.date.text = "${item.day}/${item.month}/${item.year}"  // creates String
}
// GOOD: pre-format or use SpannableStringBuilder recycled

// Reuse Compose State objects
var listState = rememberLazyListState()  // NOT LazyListState() in composable body
```

---

## Performance Checklist

- [ ] Baseline Profile generated and committed to source
- [ ] StrictMode enabled in debug builds, zero violations
- [ ] LeakCanary shows no leaks
- [ ] Main thread never blocked (Dispatchers.IO for all I/O)
- [ ] LazyColumn with stable keys — Layout Inspector shows no spurious recompositions
- [ ] Cold start < 2 seconds (Macrobenchmark verified)
- [ ] Compose compiler metrics: all hot composables marked skippable
- [ ] WebP images, vector drawables for icons
- [ ] R8 full mode enabled for release
- [ ] Network responses cached (OkHttp Cache)
- [ ] App Startup library — no unnecessary ContentProviders at startup
- [ ] 60fps scroll (FrameTimingMetric < 16ms p95)
