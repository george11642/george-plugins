# Android Architecture Patterns

## Clean Architecture Layers

```
UI Layer          ← UiState, ViewModels, Composables
      ↓ (only knows about Domain)
Domain Layer      ← Use Cases, Domain Models, Repository interfaces
      ↓ (only knows about Data interfaces)
Data Layer        ← Repository impls, Remote/Local data sources, DTOs
```

**Rule:** Dependencies point inward only. Data layer knows nothing about UI.

```kotlin
// Domain model (pure Kotlin, no Android deps)
data class User(val id: String, val name: String, val email: String)

// Repository interface (in domain layer)
interface UserRepository {
    fun getUser(id: String): Flow<User>
    suspend fun updateUser(user: User): Result<Unit>
}

// Use Case (domain layer, single responsibility)
class GetUserProfileUseCase(private val userRepository: UserRepository) {
    operator fun invoke(userId: String): Flow<UserProfileUiModel> =
        userRepository.getUser(userId).map { it.toProfileUiModel() }
}

// Repository implementation (data layer)
class UserRepositoryImpl(
    private val remoteDataSource: UserRemoteDataSource,
    private val localDataSource: UserLocalDataSource
) : UserRepository {
    override fun getUser(id: String): Flow<User> =
        localDataSource.getUser(id)
            .onEach { if (it == null) remoteDataSource.fetchAndStore(id) }
            .filterNotNull()
}
```

---

## ViewModel: UiState Pattern

```kotlin
// Sealed class for exhaustive UI states
sealed interface NewsUiState {
    data object Loading : NewsUiState
    data class Success(val articles: List<Article>) : NewsUiState
    data class Error(val message: String) : NewsUiState
}

// ViewModel with stateIn
class NewsViewModel(
    private val getNewsUseCase: GetNewsUseCase,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val category: String = savedStateHandle["category"] ?: "general"

    // Expose immutable StateFlow to UI
    val uiState: StateFlow<NewsUiState> = getNewsUseCase(category)
        .map<List<Article>, NewsUiState> { NewsUiState.Success(it) }
        .onStart { emit(NewsUiState.Loading) }
        .catch { e -> emit(NewsUiState.Error(e.localizedMessage ?: "Unknown error")) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = NewsUiState.Loading
        )

    // For mutable state with multiple fields
    private val _state = MutableStateFlow(NewsScreenState())
    val state = _state.asStateFlow()

    fun onRefresh() {
        _state.update { it.copy(isRefreshing = true) }
        viewModelScope.launch {
            // ...
            _state.update { it.copy(isRefreshing = false) }
        }
    }
}
```

---

## UiEvent: One-Shot Events

```kotlin
// One-shot events (navigation, snackbar, dialogs) — don't use StateFlow for these
// StateFlow will replay last value on rotation → duplicate navigation

// Option A: SharedFlow (no replay)
private val _events = MutableSharedFlow<NewsUiEvent>()
val events: SharedFlow<NewsUiEvent> = _events.asSharedFlow()

sealed interface NewsUiEvent {
    data class NavigateToDetail(val articleId: String) : NewsUiEvent
    data class ShowSnackbar(val message: String) : NewsUiEvent
    data object NavigateBack : NewsUiEvent
}

// In ViewModel
fun onArticleClick(articleId: String) = viewModelScope.launch {
    _events.emit(NewsUiEvent.NavigateToDetail(articleId))
}

// In Composable
LaunchedEffect(Unit) {
    viewModel.events.collect { event ->
        when (event) {
            is NewsUiEvent.NavigateToDetail -> navController.navigate("detail/${event.articleId}")
            is NewsUiEvent.ShowSnackbar -> snackbarHostState.showSnackbar(event.message)
            NewsUiEvent.NavigateBack -> navController.popBackStack()
        }
    }
}
```

---

## SavedStateHandle

```kotlin
// Survives process death — use for critical navigation args
class DetailViewModel(savedStateHandle: SavedStateHandle) : ViewModel() {
    // Read nav arg
    private val itemId: String = checkNotNull(savedStateHandle["itemId"])

    // Observe as StateFlow (survives back stack)
    val query: StateFlow<String> = savedStateHandle.getStateFlow("query", "")

    fun onQueryChange(q: String) { savedStateHandle["query"] = q }
}
```

---

## Hilt Dependency Injection

```kotlin
// Application class
@HiltAndroidApp
class MyApp : Application()

// Activity / Fragment — annotate to enable injection
@AndroidEntryPoint
class MainActivity : ComponentActivity()

// Module — bindings for interfaces
@Module
@InstallIn(SingletonComponent::class)  // scope to app lifetime
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder().build()

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl(BuildConfig.BASE_URL)
            .client(client)
            .addConverterFactory(kotlinx.serialization.json.Json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService =
        retrofit.create(ApiService::class.java)
}

// Binds — bind interface to implementation (no object creation)
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}

// Qualifiers — multiple bindings of same type
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IoDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class MainDispatcher

@Module
@InstallIn(SingletonComponent::class)
object CoroutinesModule {
    @Provides @IoDispatcher
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

    @Provides @MainDispatcher
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main
}

// Usage
class MyRepository @Inject constructor(
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) { ... }

// ViewModelComponent — scoped to ViewModel lifetime
@Module
@InstallIn(ViewModelComponent::class)
object ViewModelModule {
    @Provides
    @ViewModelScoped
    fun provideAnalytics(viewModelLifecycle: ViewModelLifecycle): Analytics =
        Analytics(viewModelLifecycle)
}

// Assisted injection for ViewModel with runtime params
@HiltViewModel(assistedFactory = DetailViewModelFactory::class)
class DetailViewModel @AssistedInject constructor(
    @Assisted val itemId: String,
    private val repo: ItemRepository
) : ViewModel()

@AssistedFactory
interface DetailViewModelFactory {
    fun create(itemId: String): DetailViewModel
}
```

---

## Navigation (Compose Navigation 2.8+ Type-Safe Routes)

```kotlin
// Define type-safe routes using @Serializable
@Serializable
object HomeRoute

@Serializable
data class DetailRoute(val itemId: String, val fromDeepLink: Boolean = false)

@Serializable
object SettingsRoute

// NavHost setup
@Composable
fun AppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = HomeRoute) {
        composable<HomeRoute> {
            HomeScreen(
                onItemClick = { id -> navController.navigate(DetailRoute(id)) }
            )
        }
        composable<DetailRoute> { backStackEntry ->
            val route: DetailRoute = backStackEntry.toRoute()
            DetailScreen(
                itemId = route.itemId,
                onBack = { navController.popBackStack() }
            )
        }
        composable<SettingsRoute> { SettingsScreen() }
    }
}

// Nested navigation graphs
fun NavGraphBuilder.authGraph(navController: NavController) {
    navigation<AuthGraph>(startDestination = LoginRoute) {
        composable<LoginRoute> { LoginScreen(onSuccess = { navController.navigate(HomeRoute) }) }
        composable<RegisterRoute> { RegisterScreen() }
    }
}

// BottomNavigation with NavController
@Composable
fun MainScreen() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    Scaffold(
        bottomBar = {
            NavigationBar {
                bottomNavItems.forEach { item ->
                    NavigationBarItem(
                        selected = currentDestination?.hierarchy?.any { it.hasRoute(item.route::class) } == true,
                        onClick = {
                            navController.navigate(item.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { paddingValues ->
        AppNavHost(navController, modifier = Modifier.padding(paddingValues))
    }
}
```

---

## Multi-Module Architecture

```
:app                    — application module, DI wiring
:feature:home           — feature module
:feature:detail         — feature module
:core:ui                — shared UI components, theme
:core:data              — repositories, data sources
:core:domain            — use cases, domain models
:core:network           — Retrofit, OkHttp setup
:core:database          — Room setup
:core:common            — utilities, extensions
```

**Module rules:**
- Feature modules depend on `:core:*` only, never on other features
- `:core:domain` has no Android deps (pure Kotlin)
- `:core:ui` depends on Compose but not on business logic
- Navigation between features: use shared nav graph in `:app` or nav contracts

```kotlin
// build.gradle.kts for feature module
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.example.feature.home"
}

dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:domain"))
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
}
```

---

## Repository Pattern Best Practices

```kotlin
// Repository = single source of truth, manages data sources
class ArticleRepositoryImpl @Inject constructor(
    private val remoteDataSource: ArticleRemoteDataSource,
    private val localDataSource: ArticleLocalDataSource,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : ArticleRepository {

    // Offline-first: emit local data immediately, refresh in background
    override fun getArticles(category: String): Flow<List<Article>> = flow {
        emitAll(localDataSource.getArticles(category))
        withContext(ioDispatcher) {
            try {
                val remote = remoteDataSource.fetchArticles(category)
                localDataSource.insertArticles(remote.map { it.toEntity() })
            } catch (e: IOException) {
                // Local data already emitted — silently handle network failure
            }
        }
    }.flowOn(ioDispatcher)

    // Or use Room's flow which auto-updates on DB changes (recommended)
    override fun getArticlesStream(category: String): Flow<List<Article>> =
        localDataSource.getArticlesFlow(category)
            .map { entities -> entities.map { it.toDomain() } }
            .flowOn(ioDispatcher)
}

// Result wrapper for operations with error states
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val exception: Throwable) : Result<Nothing>()
    data object Loading : Result<Nothing>()
}

suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> = try {
    Result.Success(call())
} catch (e: HttpException) {
    Result.Error(e)
} catch (e: IOException) {
    Result.Error(e)
}
```

---

## Use Cases

```kotlin
// Simple use case — often just delegation
class GetArticlesUseCase @Inject constructor(
    private val articleRepository: ArticleRepository
) {
    operator fun invoke(category: String): Flow<List<Article>> =
        articleRepository.getArticlesStream(category)
            .map { articles -> articles.filter { it.isPublished }.sortedByDescending { it.publishedAt } }
}

// Use case with multiple repos
class PostArticleCommentUseCase @Inject constructor(
    private val commentRepository: CommentRepository,
    private val userRepository: UserRepository,
    private val analyticsRepository: AnalyticsRepository
) {
    suspend operator fun invoke(articleId: String, commentText: String): Result<Comment> {
        val currentUser = userRepository.getCurrentUser()
            ?: return Result.Error(IllegalStateException("Not logged in"))

        return safeApiCall {
            commentRepository.postComment(articleId, commentText, currentUser.id)
                .also { analyticsRepository.track("comment_posted") }
        }
    }
}

// Skip use cases for simple delegation — not every operation needs one
// Use cases add value when: combining repos, transforming data, enforcing business rules
```
