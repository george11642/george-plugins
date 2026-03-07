# Jetpack Compose Fundamentals

## Composable Functions

```kotlin
// Stateless composable — preferred, easy to test/preview
@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(text = "Hello, $name!", modifier = modifier)
}

// Stateful composable — owns state, delegates to stateless
@Composable
fun GreetingScreen() {
    var name by remember { mutableStateOf("") }
    Greeting(name = name)
}

// @Stable annotation — tell compiler this class won't change unexpectedly
@Stable
data class UserUiState(val name: String, val avatarUrl: String)
```

**Key rules:**
- Composables must be idempotent: same input → same output
- No side effects in the composable body — use side-effect APIs
- Function names: PascalCase for UI composables, camelCase for helpers
- Keep composables small (30-50 lines max) and single-purpose
- All composables should accept `modifier: Modifier = Modifier` as last named param

---

## Recomposition: Stability & Skipping

Compose skips recomposition of a composable only when all its inputs are **stable and unchanged**.

**Stability rules:**
- Primitive types (Int, String, Boolean) → always stable
- Data classes with only stable fields → stable
- Mutable fields / List/Map/Set from stdlib → **unstable** (use `ImmutableList` from kotlinx-collections-immutable)
- `@Stable` / `@Immutable` → annotate to force stable inference

```kotlin
// BAD: List is unstable → triggers recomposition on every parent recompose
@Composable
fun ItemList(items: List<Item>) { ... }

// GOOD: ImmutableList is stable
@Composable
fun ItemList(items: ImmutableList<Item>) { ... }

// GOOD: Or annotate wrapper
@Immutable
data class ItemListWrapper(val items: List<Item>)
```

**Compose Compiler Reports:** Enable in build.gradle.kts:
```kotlin
kotlinOptions {
    freeCompilerArgs += listOf(
        "-P", "plugin:androidx.compose.compiler.plugins.kotlin:reportsDestination=${project.buildDir}/compose_metrics",
        "-P", "plugin:androidx.compose.compiler.plugins.kotlin:metricsDestination=${project.buildDir}/compose_metrics"
    )
}
```
Check `*-composables.csv` for `skippable` column. Non-skippable composables = recomposition hotspots.

---

## remember and derivedStateOf

```kotlin
// remember — survive recomposition, reset on leave composition
val count = remember { mutableStateOf(0) }
// Shorthand with delegate
var count by remember { mutableStateOf(0) }

// remember with key — resets when key changes
val connection = remember(userId) { createConnection(userId) }

// rememberSaveable — survive config change (uses Bundle under the hood)
var text by rememberSaveable { mutableStateOf("") }
// Custom saver for non-parcelable types
val state = rememberSaveable(stateSaver = MyStateSaver) { mutableStateOf(MyState()) }

// derivedStateOf — compute only when upstream state changes, not every recompose
// USE WHEN: derived value is computed from state that changes more frequently than the derived result
val isScrolled by remember {
    derivedStateOf { listState.firstVisibleItemIndex > 0 }
}
// WRONG: val isScrolled = listState.firstVisibleItemIndex > 0  // recomposes on every scroll pixel

// snapshotFlow — observe Compose state from coroutines
LaunchedEffect(listState) {
    snapshotFlow { listState.firstVisibleItemIndex }
        .distinctUntilChanged()
        .collect { index -> analyticsLogger.log("Scrolled to $index") }
}
```

---

## State Hoisting Pattern

Move state up to the lowest common ancestor that needs it. Enables reuse, testability, and single source of truth.

```kotlin
// Stateless (hoisted) — all state passed in
@Composable
fun EmailInput(
    email: String,
    onEmailChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(value = email, onValueChange = onEmailChange, modifier = modifier)
}

// State holder (ViewModel or remember class)
@Composable
fun LoginScreen(viewModel: LoginViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    EmailInput(
        email = uiState.email,
        onEmailChange = viewModel::onEmailChange
    )
}

// Plain class state holder for complex local state
class SearchBarState(initialQuery: String = "") {
    var query by mutableStateOf(initialQuery)
    val isSearching = query.isNotEmpty()
    fun clearQuery() { query = "" }
}

@Composable
fun rememberSearchBarState(initialQuery: String = "") =
    remember { SearchBarState(initialQuery) }
```

---

## CompositionLocal

Implicitly pass data down the tree without threading params through every composable.

```kotlin
// Define
val LocalUserPrefs = compositionLocalOf<UserPrefs> { error("No UserPrefs provided") }
// staticCompositionLocalOf — better perf when value rarely changes (full subtree recompose on change)
val LocalTheme = staticCompositionLocalOf<AppTheme> { LightTheme }

// Provide at root
@Composable
fun App(prefs: UserPrefs) {
    CompositionLocalProvider(LocalUserPrefs provides prefs) {
        MainContent()
    }
}

// Consume anywhere in tree
@Composable
fun SomeDeepChild() {
    val prefs = LocalUserPrefs.current
    Text(prefs.displayName)
}
```

**Built-in CompositionLocals:** `LocalContext`, `LocalDensity`, `LocalFocusManager`, `LocalSoftwareKeyboardController`, `LocalLifecycleOwner`, `LocalConfiguration`

---

## Modifier Chain Ordering

Order matters — each modifier wraps the content to its right.

```kotlin
// padding → clickable: click area excludes padding
Modifier.padding(16.dp).clickable { }

// clickable → padding: click area includes padding (usually desired)
Modifier.clickable { }.padding(16.dp)

// size → padding → clip: clips after padding (outer boundary)
Modifier.size(100.dp).padding(8.dp).clip(CircleShape)

// Prefer specific Modifier APIs over generic ones:
Modifier.fillMaxWidth()  // NOT Modifier.fillMaxSize() when only width needed
Modifier.wrapContentHeight()
Modifier.weight(1f)  // inside Row/Column only

// Semantic modifiers for accessibility
Modifier.semantics {
    contentDescription = "Profile photo of $userName"
    role = Role.Image
}
```

---

## LazyColumn / LazyRow

```kotlin
@Composable
fun MessageList(messages: List<Message>) {
    val listState = rememberLazyListState()

    LazyColumn(
        state = listState,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        // KEY: stable, unique key per item — preserves state across reorder/insert
        items(messages, key = { it.id }) { message ->
            MessageItem(message, modifier = Modifier.animateItem()) // Compose 1.7+
        }

        // contentType: tells Compose items of same type can reuse composition
        items(messages, key = { it.id }, contentType = { it.type }) { message ->
            when (message.type) {
                MessageType.TEXT -> TextMessageItem(message)
                MessageType.IMAGE -> ImageMessageItem(message)
            }
        }

        // Sticky headers
        stickyHeader { DateHeader(date = "Today") }

        // Paging integration (Paging 3)
        items(lazyPagingItems.itemCount) { index ->
            lazyPagingItems[index]?.let { item -> ItemCard(item) }
        }
        // Or use extension
        // items(lazyPagingItems, key = { it.id }) { item -> ... }
    }

    // Scroll to position
    val scope = rememberCoroutineScope()
    Button(onClick = { scope.launch { listState.animateScrollToItem(0) } }) {
        Text("Scroll to top")
    }
}

// LazyGrid
LazyVerticalGrid(
    columns = GridCells.Adaptive(minSize = 128.dp),
    // Or: GridCells.Fixed(3)
) {
    items(photos, key = { it.id }) { PhotoCard(it) }
}
```

---

## Custom Layouts

```kotlin
// Layout — measure and position children manually
@Composable
fun CustomLayout(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        val placeables = measurables.map { it.measure(constraints) }
        val maxWidth = placeables.maxOf { it.width }
        val totalHeight = placeables.sumOf { it.height }

        layout(maxWidth, totalHeight) {
            var yOffset = 0
            placeables.forEach { placeable ->
                placeable.placeRelative(x = 0, y = yOffset)
                yOffset += placeable.height
            }
        }
    }
}

// SubcomposeLayout — compose content based on measured size
@Composable
fun WithSizeAwareContent(modifier: Modifier = Modifier) {
    SubcomposeLayout(modifier) { constraints ->
        val mainPlaceable = subcompose("main") {
            MainContent()
        }.first().measure(constraints)

        val overlayPlaceable = subcompose("overlay") {
            // Can now use mainPlaceable.width/height
            OverlayContent(parentSize = IntSize(mainPlaceable.width, mainPlaceable.height))
        }.first().measure(constraints)

        layout(mainPlaceable.width, mainPlaceable.height) {
            mainPlaceable.placeRelative(0, 0)
            overlayPlaceable.placeRelative(0, 0)
        }
    }
}
```

---

## Compose Phases

Three sequential phases per frame:

1. **Composition** — run composable functions, build Slot Table (UI tree)
2. **Layout** — measure then place each node
3. **Draw** — render to canvas

**Optimization:** Defer state reads to the latest possible phase:

```kotlin
// BAD: Read in composition — triggers recomposition
val scrollValue = scrollState.value
Box(modifier = Modifier.offset(y = scrollValue.dp))

// GOOD: Read in layout phase via lambda — skips composition on scroll
Box(modifier = Modifier.offset { IntOffset(x = 0, y = scrollState.value) })

// GOOD: graphicsLayer — read in draw phase
Box(modifier = Modifier.graphicsLayer { alpha = alphaState.value })
```

---

## Side Effects

```kotlin
// LaunchedEffect — coroutine tied to composition, runs when key changes
LaunchedEffect(userId) {
    viewModel.loadUser(userId)
}
// key = Unit: runs once on composition entry

// SideEffect — runs after every successful recomposition
// Use to sync Compose state to non-Compose code
SideEffect {
    analyticsTracker.setScreen(screenName)
}

// DisposableEffect — run setup/cleanup on enter/leave composition
DisposableEffect(lifecycleOwner) {
    val observer = LifecycleEventObserver { _, event -> handleEvent(event) }
    lifecycleOwner.lifecycle.addObserver(observer)
    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
}

// produceState — bridge non-Compose state to Compose State
val image: State<Bitmap?> = produceState<Bitmap?>(initialValue = null, url) {
    value = loadImage(url)
    awaitDispose { cancelImageLoad(url) }
}

// rememberCoroutineScope — coroutine scope for event handlers (not composition)
val scope = rememberCoroutineScope()
Button(onClick = { scope.launch { doAsyncWork() } }) { Text("Go") }
```

---

## Compose 1.7+ Features

### Shared Element Transitions
```kotlin
// Mark elements with sharedElement modifier, wrap navigation with SharedTransitionLayout
SharedTransitionLayout {
    AnimatedContent(targetState = showDetails) { showDetails ->
        if (showDetails) {
            DetailScreen(
                modifier = Modifier.sharedElement(
                    rememberSharedContentState(key = "hero-image"),
                    animatedVisibilityScope = this@AnimatedContent
                )
            )
        } else {
            ListItem(
                modifier = Modifier.sharedElement(
                    rememberSharedContentState(key = "hero-image"),
                    animatedVisibilityScope = this@AnimatedContent
                )
            )
        }
    }
}
```

### Predictive Back
```kotlin
// Enable in manifest: android:enableOnBackInvokedCallback="true"
// BackHandler with predictive animation
BackHandler(enabled = showBottomSheet) {
    scope.launch { sheetState.hide() }.invokeOnCompletion {
        if (!sheetState.isVisible) showBottomSheet = false
    }
}

// PredictiveBackHandler for custom animations
PredictiveBackHandler(enabled = showSidebar) { progress ->
    try {
        progress.collect { event ->
            // event.progress in [0.0, 1.0]
            sidebarOffset = lerp(0f, -300f, event.progress)
        }
        showSidebar = false // gesture completed
    } catch (e: CancellationException) {
        sidebarOffset = 0f  // gesture cancelled
    }
}
```

### Lazy List Item Animation (1.7+)
```kotlin
LazyColumn {
    items(items, key = { it.id }) { item ->
        ItemCard(
            item = item,
            modifier = Modifier.animateItem(
                fadeInSpec = tween(200),
                fadeOutSpec = tween(200),
                placementSpec = spring(stiffness = Spring.StiffnessMediumLow)
            )
        )
    }
}
```

---

## Performance Checklist

- [ ] Enable Compose compiler metrics, fix all non-skippable hot composables
- [ ] Replace stdlib `List` with `ImmutableList` in composable params
- [ ] Use `key` in every `items()` call
- [ ] Use `contentType` when list has multiple item types
- [ ] Defer state reads with lambda modifiers (offset, graphicsLayer)
- [ ] Use `derivedStateOf` for computed values from rapidly-changing state
- [ ] Avoid `Box(Modifier.fillMaxSize())` wrappers — they force full-size measurement
- [ ] Use Layout Inspector → Recomposition counts to find hotspots
- [ ] No heavy work in composable body — use `LaunchedEffect`/ViewModel
- [ ] `Modifier.animateItem()` for list add/remove/reorder animations
