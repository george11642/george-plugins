# Kotlin Coroutines & Flow

## CoroutineScope and Dispatchers

```kotlin
// Dispatcher selection guide:
// Dispatchers.Main      — UI updates, Compose state writes, ViewModel work
// Dispatchers.IO        — File I/O, network, database (thread pool ~64 threads)
// Dispatchers.Default   — CPU-intensive: sorting, parsing JSON, image processing
// Dispatchers.Unconfined — Avoid in production; resumes on caller thread

// ViewModelScope — cancelled when ViewModel cleared
class MyViewModel : ViewModel() {
    fun loadData() {
        viewModelScope.launch {
            val result = withContext(Dispatchers.IO) { repository.fetchData() }
            _uiState.value = result.toUiState()
        }
    }
}

// LifecycleScope — cancelled when lifecycle destroyed
class MyFragment : Fragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { updateUi(it) }
            }
        }
    }
}

// Custom scope with Job
class Repository(private val externalScope: CoroutineScope) {
    // Operations that must outlive ViewModel
    fun syncData() = externalScope.launch(Dispatchers.IO) { doSync() }
}

// SupervisorScope — child failures don't cancel siblings
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
```

---

## Structured Concurrency

```kotlin
// coroutineScope — all children must complete; one failure cancels all
suspend fun loadDashboard(): DashboardData = coroutineScope {
    val user = async { userRepo.getUser() }
    val feed = async { feedRepo.getFeed() }
    DashboardData(user.await(), feed.await())  // parallel fetch, fail together
}

// supervisorScope — child failure doesn't cancel siblings
suspend fun loadOptionalData(): Pair<Data?, Data?> = supervisorScope {
    val required = async { requiredRepo.getData() }
    val optional = async {
        try { optionalRepo.getData() }
        catch (e: Exception) { null }  // failure isolated
    }
    Pair(required.await(), optional.await())
}

// Parallel decomposition
suspend fun fetchBoth(): Pair<A, B> = coroutineScope {
    val a = async(Dispatchers.IO) { fetchA() }
    val b = async(Dispatchers.IO) { fetchB() }
    Pair(a.await(), b.await())
}

// Sequential — no coroutineScope needed
suspend fun sequential(): Result {
    val a = fetchA()  // waits
    val b = fetchB(a) // uses a
    return combine(a, b)
}
```

---

## async / await

```kotlin
// async returns Deferred<T> — lazy computation handle
val deferred: Deferred<String> = scope.async { compute() }
val value: String = deferred.await()  // suspends until ready

// await() vs join(): await returns value, join only waits for completion

// Lazy async — start only when awaited
val lazyResult = async(start = CoroutineStart.LAZY) { expensiveCompute() }
// later:
lazyResult.await()

// Handling exceptions with async:
val deferred = async { riskyOperation() }
try {
    val result = deferred.await()
} catch (e: Exception) {
    // Handle here — exception rethrown on await()
}

// With supervisorScope — exceptions not propagated automatically
val result = supervisorScope {
    val d = async { riskyOperation() }
    try { d.await() } catch (e: Exception) { defaultValue }
}
```

---

## Flow: Cold vs Hot

| | Cold Flow | Hot Flow (StateFlow/SharedFlow) |
|---|---|---|
| Starts | When collected | Immediately (independent of collectors) |
| Instances | New execution per collector | Single shared execution |
| Value | No current value | StateFlow has current value |
| Use case | DB queries, network calls | UI state, events |

```kotlin
// Cold Flow — function body runs fresh for each collector
fun coldFlow(): Flow<Int> = flow {
    println("Starting")  // prints each time someone collects
    for (i in 1..3) emit(i)
}

// Hot StateFlow — always has value, replays last to new collectors
class ViewModel : ViewModel() {
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
}

// Hot SharedFlow — no initial value, configurable replay
private val _events = MutableSharedFlow<UiEvent>(
    replay = 0,             // 0 = no replay for new subscribers
    extraBufferCapacity = 1, // buffer 1 event to prevent drops
    onBufferOverflow = BufferOverflow.DROP_OLDEST
)
val events: SharedFlow<UiEvent> = _events.asSharedFlow()
```

---

## StateFlow in ViewModels (stateIn)

```kotlin
class NewsViewModel(newsRepo: NewsRepository) : ViewModel() {
    // stateIn converts cold Flow → hot StateFlow
    val uiState: StateFlow<NewsUiState> = newsRepo.getNews()
        .map { news -> NewsUiState.Success(news) }
        .catch { e -> emit(NewsUiState.Error(e.message)) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000), // 5s grace period for rotation
            initialValue = NewsUiState.Loading
        )
    // SharingStarted options:
    // .Eagerly    — start immediately, never stop
    // .Lazily     — start on first subscriber, never stop
    // .WhileSubscribed(5000) — stop 5s after last subscriber (best for UI)
}

// Collecting in Compose with lifecycle awareness
@Composable
fun NewsScreen(viewModel: NewsViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    // collectAsStateWithLifecycle: pauses when app is in background (saves battery)
    // collectAsState: always collecting even in background
}
```

---

## callbackFlow and channelFlow

```kotlin
// callbackFlow — bridge callback APIs to Flow
fun locationUpdates(): Flow<Location> = callbackFlow {
    val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { trySend(it) }  // non-blocking send
        }
    }
    fusedLocationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
    awaitClose { fusedLocationClient.removeLocationUpdates(callback) }
}

// channelFlow — flow that can emit from different coroutines
fun multiSourceFlow(): Flow<Data> = channelFlow {
    launch { source1.data.collect { send(it) } }
    launch { source2.data.collect { send(it) } }
}
```

---

## Essential Flow Operators

```kotlin
val userFlow: Flow<User> = ...

// Transform
userFlow.map { it.toUiModel() }
userFlow.filter { it.isActive }
userFlow.transform { user -> if (user.isAdmin) emit(user) }

// Flattening (choose carefully)
userFlow.flatMapLatest { user ->
    // Cancels previous inner flow when upstream emits — best for search
    repository.getPostsForUser(user.id)
}
userFlow.flatMapMerge { user ->
    // Concurrent — no cancellation (use for independent ops)
    repository.getPostsForUser(user.id)
}
userFlow.flatMapConcat { user ->
    // Sequential — wait for each inner flow to complete
    repository.getPostsForUser(user.id)
}

// Combining
combine(userFlow, settingsFlow) { user, settings ->
    UserWithSettings(user, settings)  // emits when EITHER updates
}
userFlow.zip(settingsFlow) { user, settings ->
    Pair(user, settings)  // emits when BOTH have emitted (paired)
}

// Timing
userFlow.debounce(300)             // wait 300ms of silence (search queries)
userFlow.throttleFirst(1_000)      // emit first, suppress for 1s
userFlow.distinctUntilChanged()    // suppress duplicates
userFlow.distinctUntilChangedBy { it.id }

// Buffering
userFlow.buffer(capacity = 10)     // buffer upstream, prevents backpressure
userFlow.conflate()                // skip intermediate values, always latest

// Side effects
userFlow.onEach { log(it) }
userFlow.onStart { emit(Loading) }
userFlow.onCompletion { emit(Done) }
userFlow.catch { e -> emit(Error(e)) }

// Terminal operators
userFlow.first()                   // get first value, cancel flow
userFlow.single()                  // exactly one value expected
userFlow.toList()                  // collect all (only for finite flows)
userFlow.reduce { acc, value -> acc + value }
userFlow.fold(initial) { acc, value -> combine(acc, value) }
```

---

## Error Handling

```kotlin
// catch operator — handles upstream exceptions
flow {
    emit(loadData())
}.catch { e ->
    when (e) {
        is HttpException -> emit(UiState.Error("Network error"))
        is IOException -> emit(UiState.Error("IO error"))
        else -> throw e  // rethrow unhandled
    }
}.collect { ... }

// CoroutineExceptionHandler — last resort for uncaught exceptions in launch {}
val handler = CoroutineExceptionHandler { _, exception ->
    Timber.e(exception, "Unhandled coroutine exception")
}
scope.launch(handler) { ... }
// NOTE: Does NOT work with async {} — exceptions propagated to await()

// Retrying
flow { emit(api.fetch()) }
    .retry(retries = 3) { e -> e is IOException }
    .catch { e -> emit(fallbackData) }

// retryWhen for exponential backoff
flow { emit(api.fetch()) }
    .retryWhen { cause, attempt ->
        if (cause is IOException && attempt < 3) {
            delay(2.0.pow(attempt.toDouble()).toLong() * 1000)
            true
        } else false
    }
```

---

## Cancellation

```kotlin
// Coroutines are cancelled cooperatively — must check isActive or use suspend fns
suspend fun longTask() {
    for (i in 1..1000) {
        ensureActive()  // throws CancellationException if cancelled
        processItem(i)
    }
}

// Cancellation is structured — cancel parent → all children cancelled
val job = scope.launch {
    val child1 = launch { task1() }
    val child2 = launch { task2() }
    // cancel(job) → cancels child1 and child2 too
}
job.cancel()

// withTimeout / withTimeoutOrNull
val result = withTimeoutOrNull(5_000) {
    api.slowRequest()  // returns null if timeout
}

// Flow cancellation — collect is a suspend function, cancels when scope cancelled
// Manual cancellation:
val job = scope.launch { flow.collect { ... } }
job.cancel()

// Non-cancellable block (cleanup only — use sparingly)
withContext(NonCancellable) {
    database.saveState()  // must complete even if cancelled
}

// CancellationException should never be caught silently
try { suspendFun() }
catch (e: CancellationException) { throw e }  // always rethrow!
catch (e: Exception) { /* handle */ }
```

---

## Testing Coroutines and Flows

```kotlin
// TestCoroutineDispatcher / UnconfinedTestDispatcher
@Test
fun testViewModel() = runTest {
    val dispatcher = UnconfinedTestDispatcher(testScheduler)
    val viewModel = MyViewModel(dispatcher)

    viewModel.loadData()
    advanceUntilIdle()

    assertEquals(UiState.Success, viewModel.uiState.value)
}

// Turbine — Flow test library (recommended)
@Test
fun testFlow() = runTest {
    val flow = MutableStateFlow(0)
    flow.test {
        assertEquals(0, awaitItem())
        flow.emit(1)
        assertEquals(1, awaitItem())
        cancelAndIgnoreRemainingEvents()
    }
}

// Testing with fake repository
class FakeUserRepository : UserRepository {
    private val _users = MutableStateFlow<List<User>>(emptyList())
    override fun getUsers(): Flow<List<User>> = _users
    fun setUsers(users: List<User>) { _users.value = users }
}
```

---

## Common Patterns & Gotchas

```kotlin
// GOTCHA: Don't use GlobalScope — no structured concurrency
// BAD:
GlobalScope.launch { ... }
// GOOD: inject scope or use viewModelScope

// GOTCHA: launch vs async in viewModelScope
viewModelScope.launch {
    try {
        val result = async { riskyOp() }.await()
    } catch (e: Exception) { /* caught */ }
}
// With plain launch, exceptions go to CoroutineExceptionHandler, not try/catch

// Pattern: combine multiple StateFlows
val combinedState: StateFlow<CombinedUiState> = combine(
    userFlow,
    settingsFlow,
    notificationsFlow
) { user, settings, notifications ->
    CombinedUiState(user, settings, notifications)
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CombinedUiState.Loading)

// Pattern: one-shot events via SharedFlow
private val _events = MutableSharedFlow<UiEvent>()
val events = _events.asSharedFlow()

fun onButtonClick() = viewModelScope.launch {
    _events.emit(UiEvent.NavigateToDetail(id = 42))
}
```
