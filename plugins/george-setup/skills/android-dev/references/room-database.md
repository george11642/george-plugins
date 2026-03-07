# Room Database

## Entities

```kotlin
@Entity(
    tableName = "articles",
    indices = [
        Index(value = ["category"], unique = false),
        Index(value = ["remote_id"], unique = true)
    ],
    foreignKeys = [
        ForeignKey(
            entity = AuthorEntity::class,
            parentColumns = ["id"],
            childColumns = ["author_id"],
            onDelete = ForeignKey.CASCADE,
            onUpdate = ForeignKey.CASCADE
        )
    ]
)
data class ArticleEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "remote_id")
    val remoteId: String,

    @ColumnInfo(name = "title")
    val title: String,

    @ColumnInfo(name = "author_id")
    val authorId: Long,

    @ColumnInfo(name = "category")
    val category: String,

    @ColumnInfo(name = "published_at")
    val publishedAt: Long,  // epoch millis — store dates as Long

    @ColumnInfo(name = "is_bookmarked", defaultValue = "0")
    val isBookmarked: Boolean = false
)

// Embedded — flatten nested objects into same table
data class Address(val street: String, val city: String, val country: String)

@Entity
data class User(
    @PrimaryKey val id: Long,
    val name: String,
    @Embedded val address: Address
)

// @Embedded with prefix for disambiguation
@Entity
data class Order(
    @PrimaryKey val id: Long,
    @Embedded(prefix = "billing_") val billingAddress: Address,
    @Embedded(prefix = "shipping_") val shippingAddress: Address
)
```

---

## TypeConverters

```kotlin
// Convert non-primitive types to Room-supported types
class Converters {
    private val json = Json { ignoreUnknownKeys = true }

    @TypeConverter
    fun fromTimestamp(value: Long?): Date? = value?.let { Date(it) }

    @TypeConverter
    fun toTimestamp(date: Date?): Long? = date?.time

    @TypeConverter
    fun fromStringList(value: String?): List<String>? =
        value?.let { json.decodeFromString(it) }

    @TypeConverter
    fun toStringList(list: List<String>?): String? =
        list?.let { json.encodeToString(it) }

    @TypeConverter
    fun fromEnum(value: ArticleStatus?): String? = value?.name

    @TypeConverter
    fun toEnum(value: String?): ArticleStatus? =
        value?.let { enumValueOf<ArticleStatus>(it) }
}

// Register at database level
@Database(entities = [...], version = 1)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase()
```

---

## DAO

```kotlin
@Dao
interface ArticleDao {
    // Basic CRUD
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertArticle(article: ArticleEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertArticles(articles: List<ArticleEntity>)

    @Update
    suspend fun updateArticle(article: ArticleEntity)

    @Delete
    suspend fun deleteArticle(article: ArticleEntity)

    // Queries returning Flow — auto-updates when data changes
    @Query("SELECT * FROM articles ORDER BY published_at DESC")
    fun getAllArticles(): Flow<List<ArticleEntity>>

    @Query("SELECT * FROM articles WHERE category = :category ORDER BY published_at DESC")
    fun getArticlesByCategory(category: String): Flow<List<ArticleEntity>>

    @Query("SELECT * FROM articles WHERE id = :id")
    fun getArticleById(id: Long): Flow<ArticleEntity?>

    // One-shot suspend queries
    @Query("SELECT * FROM articles WHERE remote_id = :remoteId LIMIT 1")
    suspend fun getByRemoteId(remoteId: String): ArticleEntity?

    @Query("SELECT COUNT(*) FROM articles WHERE category = :category")
    suspend fun countByCategory(category: String): Int

    // Partial update
    @Query("UPDATE articles SET is_bookmarked = :bookmarked WHERE id = :id")
    suspend fun updateBookmark(id: Long, bookmarked: Boolean)

    // Delete with condition
    @Query("DELETE FROM articles WHERE category = :category AND published_at < :before")
    suspend fun deleteOldArticles(category: String, before: Long)

    // Transaction — multiple ops atomically
    @Transaction
    suspend fun replaceArticles(category: String, articles: List<ArticleEntity>) {
        deleteByCategory(category)
        insertArticles(articles)
    }

    @Query("DELETE FROM articles WHERE category = :category")
    suspend fun deleteByCategory(category: String)

    // @RawQuery for dynamic queries
    @RawQuery(observedEntities = [ArticleEntity::class])
    fun getArticlesRaw(query: SupportSQLiteQuery): Flow<List<ArticleEntity>>
}

fun ArticleDao.searchArticles(term: String, category: String?): Flow<List<ArticleEntity>> {
    val query = buildString {
        append("SELECT * FROM articles WHERE title LIKE '%' || ? || '%'")
        category?.let { append(" AND category = ?") }
        append(" ORDER BY published_at DESC")
    }
    val args = if (category != null) arrayOf(term, category) else arrayOf(term)
    return getArticlesRaw(SimpleSQLiteQuery(query, args))
}
```

---

## Relation Queries

```kotlin
// One-to-many: Author has many Articles
data class AuthorWithArticles(
    @Embedded val author: AuthorEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "author_id"
    )
    val articles: List<ArticleEntity>
)

@Dao
interface AuthorDao {
    @Transaction
    @Query("SELECT * FROM authors")
    fun getAuthorsWithArticles(): Flow<List<AuthorWithArticles>>
}

// Many-to-many: Article <-> Tag via junction table
@Entity(
    tableName = "article_tag_cross_ref",
    primaryKeys = ["article_id", "tag_id"]
)
data class ArticleTagCrossRef(
    @ColumnInfo(name = "article_id") val articleId: Long,
    @ColumnInfo(name = "tag_id") val tagId: Long
)

data class ArticleWithTags(
    @Embedded val article: ArticleEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "id",
        associateBy = Junction(
            value = ArticleTagCrossRef::class,
            parentColumn = "article_id",
            entityColumn = "tag_id"
        )
    )
    val tags: List<TagEntity>
)

// Nested relations (author → articles → tags)
data class AuthorWithArticlesAndTags(
    @Embedded val author: AuthorEntity,
    @Relation(
        entity = ArticleEntity::class,
        parentColumn = "id",
        entityColumn = "author_id"
    )
    val articlesWithTags: List<ArticleWithTags>
)
```

---

## Database Setup and Migrations

```kotlin
@Database(
    entities = [
        ArticleEntity::class,
        AuthorEntity::class,
        TagEntity::class,
        ArticleTagCrossRef::class
    ],
    version = 3,
    autoMigrations = [
        AutoMigration(from = 1, to = 2),
        AutoMigration(from = 2, to = 3, spec = AppDatabase.Migration2to3::class)
    ],
    exportSchema = true  // IMPORTANT: commit schema/ dir to version control
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun articleDao(): ArticleDao
    abstract fun authorDao(): AuthorDao

    // AutoMigration spec — needed for renames/deletes
    @RenameColumn(tableName = "articles", fromColumnName = "pub_date", toColumnName = "published_at")
    class Migration2to3 : AutoMigrationSpec

    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "app_database.db"
                )
                    .addMigrations(MIGRATION_3_4)  // manual migration
                    .enableMultiInstanceInvalidation()  // multi-process support
                    .build().also { INSTANCE = it }
            }
    }
}

// Manual migration
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE articles ADD COLUMN view_count INTEGER NOT NULL DEFAULT 0")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_articles_view_count ON articles(view_count)")
    }
}

// Hilt module
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        AppDatabase.getInstance(context)

    @Provides
    fun provideArticleDao(db: AppDatabase): ArticleDao = db.articleDao()
}
```

---

## WAL Mode and Performance

```kotlin
// WAL (Write-Ahead Log) enabled by default in Room — allows concurrent reads + write
// Disable only if targeting API < 16 or multiple processes need strict consistency

Room.databaseBuilder(context, AppDatabase::class.java, "db")
    .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)  // default, explicit
    .build()

// Query performance tips:
// 1. Add @Index on columns used in WHERE, JOIN, ORDER BY clauses
// 2. Use SELECT * sparingly — project only needed columns
// 3. Paginate large results with Paging 3 integration
// 4. Bulk insert with single transaction (not N individual inserts)

// Paging 3 integration
@Dao
interface ArticlePagingDao {
    @Query("SELECT * FROM articles ORDER BY published_at DESC")
    fun getArticlesPaged(): PagingSource<Int, ArticleEntity>
}

// In Repository
fun getPagedArticles(): Flow<PagingData<Article>> = Pager(
    config = PagingConfig(pageSize = 20, enablePlaceholders = false),
    pagingSourceFactory = { articleDao.getArticlesPaged() }
).flow.map { pagingData -> pagingData.map { it.toDomain() } }
```

---

## Room Testing

```kotlin
@RunWith(AndroidJUnit4::class)
class ArticleDaoTest {
    private lateinit var database: AppDatabase
    private lateinit var articleDao: ArticleDao

    @Before
    fun setUp() {
        // In-memory database — no persistence, isolated per test
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java
        )
            .allowMainThreadQueries()  // OK for tests
            .build()
        articleDao = database.articleDao()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun insertAndRetrieve() = runTest {
        val article = ArticleEntity(
            remoteId = "abc123",
            title = "Test Article",
            authorId = 1L,
            category = "tech",
            publishedAt = System.currentTimeMillis()
        )
        articleDao.insertArticle(article)

        val articles = articleDao.getAllArticles().first()
        assertEquals(1, articles.size)
        assertEquals("Test Article", articles[0].title)
    }

    @Test
    fun flowEmitsOnUpdate() = runTest {
        articleDao.getAllArticles().test {
            assertEquals(0, awaitItem().size)  // initial empty

            articleDao.insertArticle(testArticle)
            assertEquals(1, awaitItem().size)  // flow updated

            articleDao.deleteArticle(testArticle.copy(id = 1))
            assertEquals(0, awaitItem().size)  // flow updated again

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun migration_1_2() {
        val db = MigrationTestHelper(
            InstrumentationRegistry.getInstrumentation(),
            AppDatabase::class.java
        )
        db.createDatabase("test_db", 1).apply { close() }
        db.runMigrationsAndValidate("test_db", 2, true, MIGRATION_1_2)
    }
}
```

---

## Database Inspector (Android Studio)

- Open: **View → Tool Windows → App Inspection → Database Inspector**
- Live query execution on running emulator/device
- View table contents in real time
- Export database as .db file for offline analysis
- Force-updates on schema changes without restarting app
- Use **Keep database open** toggle to persist during debugging sessions
