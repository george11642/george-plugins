# Networking & Serialization

## Retrofit Setup

```kotlin
// API interface
interface NewsApiService {
    @GET("v2/top-headlines")
    suspend fun getTopHeadlines(
        @Query("category") category: String,
        @Query("country") country: String = "us",
        @Query("pageSize") pageSize: Int = 20,
        @Query("page") page: Int = 1
    ): NewsResponse

    @POST("articles/{id}/comments")
    suspend fun postComment(
        @Path("id") articleId: String,
        @Body comment: CreateCommentRequest
    ): CommentResponse

    @Multipart
    @POST("users/avatar")
    suspend fun uploadAvatar(
        @Part avatar: MultipartBody.Part,
        @Part("user_id") userId: RequestBody
    ): AvatarResponse

    @PATCH("articles/{id}")
    suspend fun patchArticle(
        @Path("id") articleId: String,
        @Body updates: Map<String, @JvmSuppressWildcards Any>
    ): ArticleResponse

    @Streaming
    @GET("files/{filename}")
    suspend fun downloadFile(@Path("filename") filename: String): ResponseBody
}

// Retrofit builder (with Kotlinx Serialization)
val retrofit = Retrofit.Builder()
    .baseUrl("https://newsapi.org/")
    .client(okHttpClient)
    .addConverterFactory(
        Json { ignoreUnknownKeys = true }.asConverterFactory("application/json".toMediaType())
    )
    .build()

val apiService: NewsApiService = retrofit.create(NewsApiService::class.java)
```

---

## OkHttp Configuration

```kotlin
val okHttpClient = OkHttpClient.Builder()
    .connectTimeout(15, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .writeTimeout(30, TimeUnit.SECONDS)
    .addInterceptor(AuthInterceptor())             // auth headers
    .addInterceptor(HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG)
            HttpLoggingInterceptor.Level.BODY
        else
            HttpLoggingInterceptor.Level.NONE
    })
    .addNetworkInterceptor(CacheInterceptor())      // network-level cache headers
    .cache(Cache(
        directory = context.cacheDir.resolve("http_cache"),
        maxSize = 10L * 1024 * 1024  // 10 MB
    ))
    .certificatePinner(                             // Certificate pinning
        CertificatePinner.Builder()
            .add("newsapi.org", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
            .build()
    )
    .build()

// Auth interceptor — add API key to every request
class AuthInterceptor @Inject constructor(
    private val tokenProvider: TokenProvider
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val request = original.newBuilder()
            .header("Authorization", "Bearer ${tokenProvider.getToken()}")
            .header("X-Api-Version", "2")
            .build()
        return chain.proceed(request)
    }
}

// Token refresh interceptor (handles 401)
class TokenRefreshInterceptor @Inject constructor(
    private val authRepository: AuthRepository
) : Authenticator {
    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.code != 401) return null
        // Synchronize token refresh (multiple concurrent requests)
        val newToken = synchronized(this) {
            runBlocking { authRepository.refreshToken() }
        } ?: return null  // null = stop retrying, propagate 401

        return response.request.newBuilder()
            .header("Authorization", "Bearer $newToken")
            .build()
    }
}

// Cache interceptor
class CacheInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val response = chain.proceed(chain.request())
        val cacheControl = CacheControl.Builder()
            .maxAge(5, TimeUnit.MINUTES)
            .build()
        return response.newBuilder()
            .header("Cache-Control", cacheControl.toString())
            .build()
    }
}
```

---

## Error Handling

```kotlin
// Sealed result wrapper
sealed interface NetworkResult<out T> {
    data class Success<T>(val data: T) : NetworkResult<T>
    data class Error(val code: Int, val message: String) : NetworkResult<Nothing>
    data class Exception(val e: Throwable) : NetworkResult<Nothing>
}

// Safe API call wrapper
suspend fun <T> safeApiCall(apiCall: suspend () -> T): NetworkResult<T> =
    try {
        NetworkResult.Success(apiCall())
    } catch (e: HttpException) {
        NetworkResult.Error(e.code(), e.message ?: "HTTP error")
    } catch (e: IOException) {
        NetworkResult.Exception(e)
    }

// Usage
suspend fun getHeadlines(): NetworkResult<List<Article>> =
    safeApiCall { apiService.getTopHeadlines("technology") }
        .map { response -> response.articles.map { it.toDomain() } }

// Extension
fun <T, R> NetworkResult<T>.map(transform: (T) -> R): NetworkResult<R> = when (this) {
    is NetworkResult.Success -> NetworkResult.Success(transform(data))
    is NetworkResult.Error -> this
    is NetworkResult.Exception -> this
}

// Parse error body with Kotlinx Serialization
fun HttpException.toApiError(): ApiError? = try {
    response()?.errorBody()?.string()?.let {
        Json.decodeFromString<ApiError>(it)
    }
} catch (e: Exception) { null }
```

---

## Kotlinx Serialization

```kotlin
// Setup: build.gradle.kts
plugins {
    kotlin("plugin.serialization") version "2.0.0"
}
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}

// Basic usage
@Serializable
data class Article(
    val id: String,
    val title: String,
    @SerialName("author_name") val authorName: String,  // rename
    @Transient val isLocal: Boolean = false,              // exclude from serialization
    val publishedAt: String? = null                       // optional
)

// JSON configuration
val json = Json {
    ignoreUnknownKeys = true    // don't fail on extra fields
    isLenient = true            // allow non-standard JSON
    prettyPrint = false         // compact for network
    encodeDefaults = false      // omit default values
    explicitNulls = false       // omit null values
    coerceInputValues = true    // use defaults for invalid values
}

// Polymorphism
@Serializable
sealed class Notification {
    @Serializable @SerialName("news") data class NewsNotification(val articleId: String) : Notification()
    @Serializable @SerialName("message") data class MessageNotification(val from: String) : Notification()
}

// Custom serializer
object DateSerializer : KSerializer<Date> {
    override val descriptor = PrimitiveSerialDescriptor("Date", PrimitiveKind.LONG)
    override fun serialize(encoder: Encoder, value: Date) = encoder.encodeLong(value.time)
    override fun deserialize(decoder: Decoder) = Date(decoder.decodeLong())
}

@Serializable
data class Event(
    @Serializable(with = DateSerializer::class) val date: Date
)
```

---

## Multipart File Upload

```kotlin
// Upload image from Uri
suspend fun uploadPhoto(context: Context, uri: Uri): AvatarResponse {
    val inputStream = context.contentResolver.openInputStream(uri)!!
    val bytes = inputStream.use { it.readBytes() }
    val mimeType = context.contentResolver.getType(uri) ?: "image/jpeg"

    val requestBody = bytes.toRequestBody(mimeType.toMediaType())
    val part = MultipartBody.Part.createFormData(
        name = "photo",
        filename = "photo.jpg",
        body = requestBody
    )

    return apiService.uploadAvatar(
        avatar = part,
        userId = userId.toRequestBody("text/plain".toMediaType())
    )
}

// Upload with progress (OkHttp CountingRequestBody)
class ProgressRequestBody(
    private val delegate: RequestBody,
    private val onProgress: (Int) -> Unit
) : RequestBody() {
    override fun contentType() = delegate.contentType()
    override fun contentLength() = delegate.contentLength()

    override fun writeTo(sink: BufferedSink) {
        val countingSink = object : ForwardingSink(sink) {
            var bytesWritten = 0L
            override fun write(source: Buffer, byteCount: Long) {
                super.write(source, byteCount)
                bytesWritten += byteCount
                val progress = (bytesWritten * 100 / contentLength()).toInt()
                onProgress(progress)
            }
        }
        delegate.writeTo(countingSink.buffer())
    }
}
```

---

## Coil Image Loading

```kotlin
// Setup: add AsyncImage composable
// implementation("io.coil-kt.coil3:coil-compose:3.0.4")
// implementation("io.coil-kt.coil3:coil-network-okhttp:3.0.4")

// Basic usage
AsyncImage(
    model = "https://example.com/image.jpg",
    contentDescription = "Article thumbnail",
    contentScale = ContentScale.Crop,
    modifier = Modifier
        .size(80.dp)
        .clip(RoundedCornerShape(8.dp))
)

// With crossfade and placeholder
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data("https://example.com/image.jpg")
        .crossfade(true)
        .crossfade(300)
        .placeholder(R.drawable.placeholder)
        .error(R.drawable.error_image)
        .fallback(R.drawable.fallback)
        .size(Size.ORIGINAL)           // or .size(width, height) for target size
        .transformations(
            CircleCropTransformation(),
            BlurTransformation(radius = 8f)
        )
        .diskCachePolicy(CachePolicy.ENABLED)
        .memoryCachePolicy(CachePolicy.ENABLED)
        .build(),
    contentDescription = "Profile photo",
    modifier = Modifier.size(48.dp)
)

// Custom Coil singleton with OkHttp sharing
val imageLoader = ImageLoader.Builder(context)
    .okHttpClient(okHttpClient)  // share with Retrofit
    .memoryCache {
        MemoryCache.Builder()
            .maxSizePercent(context, 0.20)  // 20% of available memory
            .build()
    }
    .diskCache {
        DiskCache.Builder()
            .directory(context.cacheDir.resolve("image_cache"))
            .maxSizeBytes(50L * 1024 * 1024)  // 50 MB
            .build()
    }
    .logger(DebugLogger())
    .build()

// Preloading
val preloadRequest = ImageRequest.Builder(context)
    .data(imageUrl)
    .memoryCacheKey(imageUrl)
    .build()
imageLoader.enqueue(preloadRequest)
```

---

## Ktor Client (Alternative to Retrofit)

```kotlin
// Dependency: implementation("io.ktor:ktor-client-android:2.3.12")
// Also: ktor-client-content-negotiation, ktor-serialization-kotlinx-json, ktor-client-logging

val client = HttpClient(Android) {
    install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true })
    }
    install(HttpTimeout) {
        requestTimeoutMillis = 30_000
        connectTimeoutMillis = 15_000
    }
    install(Logging) {
        logger = Logger.ANDROID
        level = LogLevel.BODY
    }
    install(Auth) {
        bearer {
            loadTokens { BearerTokens(tokenProvider.getToken(), "") }
            refreshTokens { /* refresh logic */ BearerTokens(newToken, "") }
        }
    }
    defaultRequest {
        header("X-Api-Version", "2")
        url("https://api.example.com/")
    }
}

// Usage — no interface needed
suspend fun getNews(): List<Article> =
    client.get("news") {
        parameter("category", "tech")
    }.body()

suspend fun postComment(comment: CreateCommentRequest): Comment =
    client.post("comments") {
        contentType(ContentType.Application.Json)
        setBody(comment)
    }.body()
```

---

## Moshi vs Kotlinx Serialization vs Gson

| | Kotlinx Serialization | Moshi | Gson |
|---|---|---|---|
| Kotlin support | Native | Good (codegen) | Via reflection |
| Null safety | Strict | Strict | Lenient |
| Performance | Fast (codegen) | Fast (codegen) | Slow (reflection) |
| Multiplatform | Yes | No | No |
| Sealed classes | Built-in | Adapter needed | Adapter needed |
| Recommendation | **Preferred** | Good alternative | Avoid in new projects |

**Recommendation:** Use **Kotlinx Serialization** for all new projects. It's the only option for Kotlin Multiplatform.
