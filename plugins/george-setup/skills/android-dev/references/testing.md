# Testing Android Apps

## Unit Testing with MockK

```kotlin
// Dependencies
// testImplementation("io.mockk:mockk:1.13.12")
// testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
// testImplementation("app.cash.turbine:turbine:1.2.0")
// testImplementation("junit:junit:4.13.2")

@OptIn(ExperimentalCoroutinesApi::class)
class NewsViewModelTest {
    // Replace Main dispatcher with test dispatcher
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    // MockK mocks
    private val newsRepository: NewsRepository = mockk()
    private lateinit var viewModel: NewsViewModel

    @Before
    fun setUp() {
        viewModel = NewsViewModel(newsRepository)
    }

    @Test
    fun `when repository returns articles, uiState is Success`() = runTest {
        // Given
        val articles = listOf(Article(id = "1", title = "Test"))
        every { newsRepository.getArticles("tech") } returns flowOf(articles)

        // When
        viewModel.loadArticles("tech")

        // Then
        viewModel.uiState.test {
            assertEquals(NewsUiState.Loading, awaitItem())
            assertEquals(NewsUiState.Success(articles), awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `when repository throws, uiState is Error`() = runTest {
        every { newsRepository.getArticles(any()) } returns flow {
            throw IOException("Network error")
        }

        viewModel.loadArticles("tech")

        viewModel.uiState.test {
            skipItems(1) // Loading
            val error = awaitItem()
            assertTrue(error is NewsUiState.Error)
            cancelAndIgnoreRemainingEvents()
        }
    }
}

// MainDispatcherRule — replace Main dispatcher in tests
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher()
) : TestWatcher() {
    override fun starting(description: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(description: Description) = Dispatchers.resetMain()
}

// MockK essentials
val mock: UserRepository = mockk()
every { mock.getUser("id1") } returns flowOf(testUser)
every { mock.updateUser(any()) } returns Unit
coEvery { mock.fetchUser("id1") } returns testUser  // suspend function
coEvery { mock.fetchUser(any()) } throws IOException()

verify { mock.getUser("id1") }
coVerify(exactly = 1) { mock.fetchUser("id1") }
verify { mock.updateUser(match { it.name == "Alice" }) }
confirmVerified(mock)  // ensure no unexpected calls

// Spies — real object with some mocked methods
val spy = spyk(RealUserRepository())
every { spy.getUser("id1") } returns flowOf(testUser)
```

---

## Turbine: Flow Testing

```kotlin
// Turbine provides structured Flow assertion API
@Test
fun `flow emits loading then success`() = runTest {
    val viewModel = NewsViewModel(fakeRepository)

    viewModel.uiState.test {
        // Assert items in order
        assertTrue(awaitItem() is NewsUiState.Loading)
        val success = awaitItem()
        assertTrue(success is NewsUiState.Success)
        assertEquals(3, (success as NewsUiState.Success).articles.size)

        // No more emissions expected
        expectNoEvents()
        cancel()
    }
}

// Multiple flows simultaneously
@Test
fun `state and events update together`() = runTest {
    viewModel.uiState.test {
        viewModel.events.test {
            viewModel.onBookmarkClick("article_1")

            val stateItem = awaitItem()
            assertTrue((stateItem as NewsUiState.Success).articles.first().isBookmarked)

            val event = awaitItem()
            assertEquals(UiEvent.ShowSnackbar("Bookmarked"), event)

            cancelAndIgnoreRemainingEvents()
        }
        cancelAndIgnoreRemainingEvents()
    }
}

// skipItems helper
viewModel.uiState.test {
    skipItems(1)  // skip Loading
    assertEquals(NewsUiState.Success(expected), awaitItem())
    cancelAndIgnoreRemainingEvents()
}
```

---

## Fake Repositories (Preferred over Mocks for Integration Tests)

```kotlin
// Fake — real behavior with controlled state
class FakeNewsRepository : NewsRepository {
    private val _articles = MutableStateFlow<List<Article>>(emptyList())
    var shouldThrow = false
    var fetchCount = 0

    override fun getArticles(category: String): Flow<List<Article>> {
        if (shouldThrow) return flow { throw IOException("Fake error") }
        return _articles.map { articles -> articles.filter { it.category == category } }
    }

    override suspend fun refreshArticles(category: String) {
        fetchCount++
        if (shouldThrow) throw IOException("Fake error")
    }

    // Test helpers
    fun emit(articles: List<Article>) { _articles.value = articles }
    fun emitEmpty() { _articles.value = emptyList() }
}
```

---

## Compose UI Testing

```kotlin
// Dependencies:
// androidTestImplementation("androidx.compose.ui:ui-test-junit4")
// debugImplementation("androidx.compose.ui:ui-test-manifest")

@RunWith(AndroidJUnit4::class)
class ArticleListScreenTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun articleList_displaysArticles() {
        val articles = listOf(
            Article(id = "1", title = "Kotlin 2.0 Released"),
            Article(id = "2", title = "Compose 1.7 Features")
        )

        composeTestRule.setContent {
            AppTheme {
                ArticleListScreen(
                    uiState = NewsUiState.Success(articles),
                    onArticleClick = {}
                )
            }
        }

        // Assertions
        composeTestRule.onNodeWithText("Kotlin 2.0 Released").assertIsDisplayed()
        composeTestRule.onNodeWithText("Compose 1.7 Features").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Loading").assertDoesNotExist()
    }

    @Test
    fun loadingState_showsProgressIndicator() {
        composeTestRule.setContent {
            ArticleListScreen(uiState = NewsUiState.Loading, onArticleClick = {})
        }

        composeTestRule.onNodeWithContentDescription("Loading").assertIsDisplayed()
        composeTestRule.onNodeWithTag("article_list").assertDoesNotExist()
    }

    @Test
    fun articleClick_invokesCallback() {
        var clickedId: String? = null
        val articles = listOf(Article(id = "1", title = "Test Article"))

        composeTestRule.setContent {
            ArticleListScreen(
                uiState = NewsUiState.Success(articles),
                onArticleClick = { clickedId = it }
            )
        }

        composeTestRule.onNodeWithText("Test Article").performClick()
        assertEquals("1", clickedId)
    }

    @Test
    fun scrollToBottom_loadMoreVisible() {
        val manyArticles = List(50) { Article(id = "$it", title = "Article $it") }
        composeTestRule.setContent {
            ArticleListScreen(uiState = NewsUiState.Success(manyArticles), onArticleClick = {})
        }

        composeTestRule.onNodeWithTag("article_list")
            .performScrollToIndex(49)

        composeTestRule.onNodeWithText("Article 49").assertIsDisplayed()
    }
}

// Semantic test tags — add in production code
Modifier.testTag("article_list")
Modifier.semantics { contentDescription = "Loading" }

// Wait for async operations
composeTestRule.waitUntil(timeoutMillis = 5_000) {
    composeTestRule.onAllNodesWithTag("article_item").fetchSemanticsNodes().isNotEmpty()
}
```

---

## Espresso (View-based UI Testing)

```kotlin
@RunWith(AndroidJUnit4::class)
class LoginActivityTest {
    @get:Rule
    val activityRule = ActivityScenarioRule(LoginActivity::class.java)

    @Test
    fun login_withValidCredentials_navigatesToHome() {
        onView(withId(R.id.email_input))
            .perform(typeText("test@example.com"), closeSoftKeyboard())
        onView(withId(R.id.password_input))
            .perform(typeText("password123"), closeSoftKeyboard())
        onView(withId(R.id.login_button))
            .perform(click())

        onView(withId(R.id.home_screen))
            .check(matches(isDisplayed()))
    }

    @Test
    fun login_withEmptyEmail_showsError() {
        onView(withId(R.id.login_button)).perform(click())
        onView(withText("Email is required"))
            .check(matches(isDisplayed()))
    }

    // RecyclerView interaction
    @Test
    fun articleList_clickFirstItem() {
        onView(withId(R.id.article_recycler))
            .perform(RecyclerViewActions.actionOnItemAtPosition<ArticleViewHolder>(0, click()))
        onView(withId(R.id.article_detail)).check(matches(isDisplayed()))
    }
}

// IdlingResource — wait for async work in Espresso
class CoroutineIdlingResource : IdlingResource {
    private var isIdle = true
    private var callback: IdlingResource.ResourceCallback? = null

    override fun getName() = "CoroutineIdlingResource"
    override fun isIdleNow() = isIdle
    override fun registerIdleTransitionCallback(callback: IdlingResource.ResourceCallback?) {
        this.callback = callback
    }

    fun setIdle(idle: Boolean) {
        isIdle = idle
        if (idle) callback?.onTransitionToIdle()
    }
}
```

---

## Robolectric (JVM Android Tests)

```kotlin
// Faster than instrumented tests — runs on JVM with Android simulation
// testImplementation("org.robolectric:robolectric:4.13")

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class NotificationHelperTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @Test
    fun createNotification_hasCorrectTitle() {
        val notification = NotificationHelper.build(context, "Test Title", "Body")
        val manager = context.getSystemService(NotificationManager::class.java)

        assertEquals("Test Title", notification.extras.getString(Notification.EXTRA_TITLE))
    }
}
```

---

## Screenshot Testing with Paparazzi

```kotlin
// testImplementation("app.cash.paparazzi:paparazzi:1.3.4")
// JVM-based — fast, no emulator needed

@RunWith(JUnit4::class)
class ArticleCardScreenshotTest {
    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_5,
        theme = "android:Theme.Material3.Light.NoActionBar"
    )

    @Test
    fun articleCard_lightTheme() {
        paparazzi.snapshot {
            AppTheme(darkTheme = false) {
                ArticleCard(
                    article = Article(
                        id = "1",
                        title = "Kotlin 2.0 is Here",
                        authorName = "Jane Doe"
                    ),
                    onClick = {}
                )
            }
        }
    }

    @Test
    fun articleCard_darkTheme() {
        paparazzi.snapshot("dark") {
            AppTheme(darkTheme = true) {
                ArticleCard(article = sampleArticle, onClick = {})
            }
        }
    }
}
// Run: ./gradlew recordPaparazziDebug (record baseline)
//      ./gradlew verifyPaparazziDebug (compare)
```

---

## Hilt Testing

```kotlin
// Replace real modules with test doubles
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class NewsScreenTest {
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Inject
    lateinit var fakeRepository: FakeNewsRepository

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @Test
    fun newsScreen_displaysInjectedArticles() {
        fakeRepository.emit(listOf(Article(id = "1", title = "Injected Article")))
        composeTestRule.onNodeWithText("Injected Article").assertIsDisplayed()
    }
}

// Test module — replaces production module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [RepositoryModule::class]
)
@Module
object FakeRepositoryModule {
    @Provides
    @Singleton
    fun provideNewsRepository(): NewsRepository = FakeNewsRepository()
}
```

---

## Coverage with JaCoCo

```kotlin
// build.gradle.kts
plugins { id("jacoco") }

tasks.withType<Test> {
    configure<JacocoTaskExtension> {
        isIncludeNoLocationClasses = true
        excludes = listOf("jdk.internal.*")
    }
}

tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn(tasks.named("testDebugUnitTest"))
    reports {
        xml.required = true
        html.required = true
    }
    sourceDirectories.setFrom(files("src/main/java"))
    classDirectories.setFrom(
        fileTree("build/intermediates/javac/debug") {
            exclude("**/R.class", "**/R$*.class", "**/BuildConfig.*")
        }
    )
    executionData.setFrom(fileTree(buildDir) { include("**/*.exec", "**/*.ec") })
}

// Run: ./gradlew jacocoTestReport
// Report: build/reports/jacoco/jacocoTestReport/html/index.html
```

---

## Testing Pyramid Summary

| Layer | Tools | Speed | Coverage |
|---|---|---|---|
| Unit | JUnit4/5, MockK, Turbine | Fast (ms) | Business logic, ViewModels |
| Integration | Robolectric, Room in-memory | Medium (s) | Data layer, DB queries |
| UI | Compose test, Espresso | Slow (device) | Critical user flows |
| Screenshot | Paparazzi | Fast (JVM) | Visual regressions |
| E2E | UIAutomator, Maestro | Slowest | Full journeys |

**Target:** 70% unit + 20% integration + 10% UI tests.
