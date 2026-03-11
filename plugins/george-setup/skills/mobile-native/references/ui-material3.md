# UI & Material 3

## Material 3 Theme Setup

```kotlin
// Custom color scheme with Material Theme Builder export
private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF6750A4),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFEADDFF),
    onPrimaryContainer = Color(0xFF21005D),
    secondary = Color(0xFF625B71),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFE8DEF8),
    onSecondaryContainer = Color(0xFF1D192B),
    tertiary = Color(0xFF7D5260),
    error = Color(0xFFBA1A1A),
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE),
    surfaceVariant = Color(0xFFE7E0EC),
    outline = Color(0xFF79747E)
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFD0BCFF),
    onPrimary = Color(0xFF381E72),
    // ...
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,  // Android 12+ dynamic color
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
```

---

## Typography Scale

```kotlin
val AppTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp
    ),
    displayMedium = TextStyle(fontSize = 45.sp, lineHeight = 52.sp),
    displaySmall = TextStyle(fontSize = 36.sp, lineHeight = 44.sp),
    headlineLarge = TextStyle(fontSize = 32.sp, lineHeight = 40.sp),
    headlineMedium = TextStyle(fontSize = 28.sp, lineHeight = 36.sp),
    headlineSmall = TextStyle(fontSize = 24.sp, lineHeight = 32.sp),
    titleLarge = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Normal),
    titleMedium = TextStyle(fontSize = 16.sp, lineHeight = 24.sp, fontWeight = FontWeight.Medium),
    titleSmall = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 12.sp, lineHeight = 16.sp),
    labelLarge = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
    labelMedium = TextStyle(fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium),
    labelSmall = TextStyle(fontSize = 11.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium)
)

// Custom fonts
val RobotoFamily = FontFamily(
    Font(R.font.roboto_regular, FontWeight.Normal),
    Font(R.font.roboto_medium, FontWeight.Medium),
    Font(R.font.roboto_bold, FontWeight.Bold)
)

// Google Fonts (downloadable)
val MontserratFamily = FontFamily(
    GoogleFont.Family(
        name = "Montserrat",
        provider = googleFontsProvider
    )
)
```

---

## Key M3 Components

```kotlin
// Scaffold with all navigation patterns
@Composable
fun MainScaffold(navController: NavController) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("News") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { }) {
                        Icon(Icons.Default.Search, "Search")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ),
                scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior()
            )
        },
        bottomBar = { AppBottomBar(navController) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                text = { Text("New Article") },
                icon = { Icon(Icons.Default.Add, null) },
                onClick = { navController.navigate(CreateArticleRoute) }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        // Content gets insets from Scaffold
        ArticleList(modifier = Modifier.padding(paddingValues))
    }
}

// LargeTopAppBar for collapsible title
val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
Scaffold(
    topBar = {
        LargeTopAppBar(
            title = { Text("Discover") },
            scrollBehavior = scrollBehavior
        )
    },
    modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection)
) { ... }

// Cards
Card(
    onClick = { onArticleClick(article.id) },
    modifier = Modifier.fillMaxWidth(),
    colors = CardDefaults.cardColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ),
    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
) {
    Column(modifier = Modifier.padding(16.dp)) { ... }
}

ElevatedCard { ... }
OutlinedCard { ... }

// Chips
FilterChip(
    selected = isSelected,
    onClick = { onCategoryToggle(category) },
    label = { Text(category.name) },
    leadingIcon = if (isSelected) {
        { Icon(Icons.Default.Check, null, modifier = Modifier.size(FilterChipDefaults.IconSize)) }
    } else null
)

AssistChip(onClick = {}, label = { Text("Tag") })
SuggestionChip(onClick = {}, label = { Text("Suggestion") })
InputChip(selected = true, onClick = {}, label = { Text("Input") }, onDismiss = {})

// Dialogs
AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text("Delete article?") },
    text = { Text("This cannot be undone.") },
    confirmButton = {
        TextButton(onClick = { onConfirm(); onDismiss() }) { Text("Delete") }
    },
    dismissButton = {
        TextButton(onClick = onDismiss) { Text("Cancel") }
    },
    icon = { Icon(Icons.Default.Delete, null) }
)

// DatePicker
val datePickerState = rememberDatePickerState(
    initialSelectedDateMillis = System.currentTimeMillis()
)
DatePickerDialog(
    onDismissRequest = onDismiss,
    confirmButton = {
        TextButton(onClick = { onDateSelected(datePickerState.selectedDateMillis) }) {
            Text("OK")
        }
    }
) {
    DatePicker(state = datePickerState)
}
```

---

## Navigation Components (M3)

```kotlin
// NavigationBar (bottom) — <= 5 destinations
NavigationBar {
    navItems.forEach { item ->
        NavigationBarItem(
            icon = { Icon(item.icon, item.label) },
            label = { Text(item.label) },
            selected = currentRoute == item.route,
            onClick = { navigateTo(item.route) },
            colors = NavigationBarItemDefaults.colors(
                selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                indicatorColor = MaterialTheme.colorScheme.secondaryContainer
            )
        )
    }
}

// NavigationRail — tablets/medium widths
NavigationRail(
    header = { FloatingActionButton(onClick = {}) { Icon(Icons.Default.Add, null) } }
) {
    navItems.forEach { item ->
        NavigationRailItem(
            icon = { Icon(item.icon, item.label) },
            label = { Text(item.label) },
            selected = currentRoute == item.route,
            onClick = { navigateTo(item.route) }
        )
    }
}

// NavigationDrawer — large screens
ModalNavigationDrawer(
    drawerContent = {
        ModalDrawerSheet {
            Text("My App", modifier = Modifier.padding(16.dp), style = MaterialTheme.typography.titleLarge)
            HorizontalDivider()
            navItems.forEach { item ->
                NavigationDrawerItem(
                    icon = { Icon(item.icon, item.label) },
                    label = { Text(item.label) },
                    selected = currentRoute == item.route,
                    onClick = { navigateTo(item.route) },
                    modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                )
            }
        }
    }
) { /* main content */ }
```

---

## WindowSizeClass: Adaptive UI

```kotlin
// Dependency: implementation("androidx.compose.material3.adaptive:adaptive:1.0.0")

@Composable
fun AdaptiveApp() {
    val windowSizeClass = calculateWindowSizeClass(LocalActivity.current)

    when (windowSizeClass.widthSizeClass) {
        WindowWidthSizeClass.Compact -> {
            // Phone — bottom nav + single pane
            CompactLayout()
        }
        WindowWidthSizeClass.Medium -> {
            // Unfolded foldable / small tablet — nav rail + single pane
            MediumLayout()
        }
        WindowWidthSizeClass.Expanded -> {
            // Large tablet / desktop — nav drawer + two-pane
            ExpandedLayout()
        }
    }
}

// ListDetailPaneScaffold (adaptive 2-pane)
@Composable
fun AdaptiveListDetail() {
    val navigator = rememberListDetailPaneScaffoldNavigator<String>()
    BackHandler(navigator.canNavigateBack()) { navigator.navigateBack() }

    ListDetailPaneScaffold(
        directive = navigator.scaffoldDirective,
        value = navigator.scaffoldValue,
        listPane = {
            AnimatedPane {
                ArticleListPane(
                    onArticleSelected = { id ->
                        navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, id)
                    }
                )
            }
        },
        detailPane = {
            AnimatedPane {
                navigator.currentDestination?.content?.let { id ->
                    ArticleDetailPane(articleId = id)
                }
            }
        }
    )
}
```

---

## Edge-to-Edge (Android 15 Mandatory)

```kotlin
// In Activity.onCreate — Android 15 enforces this automatically
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()  // Sets STATUS_BAR_COLOR transparent, draws behind system bars

    setContent {
        AppTheme {
            AppNavHost()
        }
    }
}

// Handle WindowInsets in Compose
@Composable
fun FullScreenContent() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.systemBars)  // add system bar padding
    ) {
        Content()
    }
}

// Scaffold handles insets automatically
Scaffold(
    // Scaffold uses WindowInsets.safeDrawing by default
    contentWindowInsets = WindowInsets.safeDrawing
) { paddingValues ->
    LazyColumn(contentPadding = paddingValues) { ... }
}

// IME insets — animate with keyboard
Box(modifier = Modifier
    .fillMaxSize()
    .imePadding()  // animate content above keyboard
) {
    TextField(...)
}

// Status bar color control
SideEffect {
    val windowInsetsController = WindowCompat.getInsetsController(window, view)
    windowInsetsController.isAppearanceLightStatusBars = !darkTheme
}
```

---

## Foldable & Large Screen Support

```kotlin
// Detect fold state
@Composable
fun FoldAwareContent() {
    val foldingFeature = WindowInfoTracker
        .getOrCreate(LocalContext.current as Activity)
        .windowLayoutInfo(LocalContext.current as Activity)
        .collectAsStateWithLifecycle(initialValue = null)
        .value
        ?.displayFeatures
        ?.filterIsInstance<FoldingFeature>()
        ?.firstOrNull()

    when {
        foldingFeature?.isSeparating == true &&
        foldingFeature.orientation == FoldingFeature.Orientation.HORIZONTAL -> {
            // Table-top mode — upper half content, lower half controls
            TableTopLayout(foldingFeature)
        }
        foldingFeature?.isSeparating == true &&
        foldingFeature.orientation == FoldingFeature.Orientation.VERTICAL -> {
            // Book mode — side-by-side
            BookLayout()
        }
        else -> NormalLayout()
    }
}

// Avoid fixed sizes — use responsive layouts
// BAD:
Box(modifier = Modifier.width(400.dp))
// GOOD:
Box(modifier = Modifier
    .fillMaxWidth()
    .widthIn(max = 600.dp)
    .wrapContentWidth(Alignment.CenterHorizontally)
)
```

---

## Custom Shapes

```kotlin
val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(28.dp)
)

// Morphing shapes (M3 Expressive — Compose 1.8+)
val roundedCorner = RoundedPolygon(numVertices = 4, rounding = CornerRounding(radius = 0.5f))
val star = RoundedPolygon.star(numVerticesPerRadius = 6, innerRadius = 0.7f)
val morph = Morph(roundedCorner, star)

// Animate between shapes
var progress by remember { mutableFloatStateOf(0f) }
val animatedProgress by animateFloatAsState(targetValue = progress)
Box(modifier = Modifier
    .size(100.dp)
    .clip(MorphShape(morph, animatedProgress))
    .background(MaterialTheme.colorScheme.primary)
    .clickable { progress = if (progress == 0f) 1f else 0f }
)
```
