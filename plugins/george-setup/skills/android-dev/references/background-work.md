# Background Work

## WorkManager

WorkManager is the recommended API for deferrable, guaranteed background work that must run even if the app exits.

```kotlin
// Dependency: implementation("androidx.work:work-runtime-ktx:2.9.1")

// Worker implementation
class SyncArticlesWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val category = inputData.getString(KEY_CATEGORY) ?: return Result.failure()

        return try {
            val articles = articleRepository.fetchRemote(category)
            articleRepository.saveLocal(articles)
            Result.success(workDataOf(KEY_COUNT to articles.size))
        } catch (e: IOException) {
            if (runAttemptCount < 3) Result.retry()
            else Result.failure(workDataOf(KEY_ERROR to e.message))
        }
    }

    companion object {
        const val KEY_CATEGORY = "category"
        const val KEY_COUNT = "count"
        const val KEY_ERROR = "error"
    }
}

// OneTimeWorkRequest
val syncRequest = OneTimeWorkRequestBuilder<SyncArticlesWorker>()
    .setInputData(workDataOf(SyncArticlesWorker.KEY_CATEGORY to "tech"))
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .setRequiresStorageNotLow(false)
            .build()
    )
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .addTag("sync")
    .build()

// PeriodicWorkRequest (minimum 15 minutes)
val periodicSync = PeriodicWorkRequestBuilder<SyncArticlesWorker>(
    repeatInterval = 1,
    repeatIntervalTimeUnit = TimeUnit.HOURS,
    flexTimeInterval = 15,
    flexTimeIntervalUnit = TimeUnit.MINUTES
)
    .setConstraints(constraints)
    .build()

// Enqueue
val workManager = WorkManager.getInstance(context)

// Unique work — prevent duplicates
workManager.enqueueUniqueWork(
    "article_sync",
    ExistingWorkPolicy.KEEP,  // KEEP, REPLACE, or APPEND_OR_REPLACE
    syncRequest
)

workManager.enqueueUniquePeriodicWork(
    "periodic_sync",
    ExistingPeriodicWorkPolicy.KEEP,
    periodicSync
)

// Chaining
workManager
    .beginUniqueWork("data_pipeline", ExistingWorkPolicy.REPLACE, fetchRequest)
    .then(processRequest)
    .then(uploadRequest)
    .enqueue()

// Parallel work
val parallel = WorkContinuation.combine(
    listOf(
        workManager.beginWith(workA),
        workManager.beginWith(workB)
    )
)
parallel.then(mergeWork).enqueue()
```

---

## Expedited Work and Foreground Info

```kotlin
// Expedited work — for time-sensitive tasks, runs immediately
// Required: setExpedited() + getForegroundInfo() override
class SendMessageWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {

    override suspend fun getForegroundInfo(): ForegroundInfo {
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_send)
            .setContentTitle("Sending message...")
            .setProgress(0, 0, true)
            .setOngoing(true)
            .build()
        return ForegroundInfo(NOTIFICATION_ID, notification)
    }

    override suspend fun doWork(): Result {
        setForeground(getForegroundInfo())  // promote to foreground
        // ... do work ...
        return Result.success()
    }
}

val expeditedRequest = OneTimeWorkRequestBuilder<SendMessageWorker>()
    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
    .build()

// Observe work status
workManager.getWorkInfoByIdLiveData(syncRequest.id)
    .observe(lifecycleOwner) { workInfo ->
        when (workInfo?.state) {
            WorkInfo.State.RUNNING -> showProgress()
            WorkInfo.State.SUCCEEDED -> showSuccess()
            WorkInfo.State.FAILED -> showError()
            else -> {}
        }
    }

// Or as Flow
workManager.getWorkInfosByTagFlow("sync")
    .collect { workInfoList -> /* handle */ }
```

---

## Hilt Worker Integration

```kotlin
// HiltWorker for dependency injection in workers
@HiltWorker
class SyncArticlesWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val articleRepository: ArticleRepository,  // injected!
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result = withContext(ioDispatcher) {
        // use injected articleRepository
        Result.success()
    }
}

// Module (only needed once)
@Module
@InstallIn(SingletonComponent::class)
object WorkManagerModule {
    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager =
        WorkManager.getInstance(context)
}
```

---

## Foreground Services

```kotlin
// Types (Android 14 requires declaring type):
// dataSync, mediaPlayback, mediaProjection, phoneCall, location, connectedDevice, health, remoteMessaging, shortService, specialUse, systemExempted

// Manifest declaration
// <service android:name=".DownloadService"
//     android:foregroundServiceType="dataSync" />

class DownloadService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val url = intent?.getStringExtra("url") ?: return START_NOT_STICKY

        val notification = buildProgressNotification(0)
        startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)

        scope.launch {
            downloadFile(url) { progress ->
                updateNotification(progress)
            }
            stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}

// Start from Activity
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    startForegroundService(Intent(this, DownloadService::class.java).apply {
        putExtra("url", downloadUrl)
    })
} else {
    startService(...)
}
```

---

## AlarmManager (Exact Alarms)

```kotlin
// Android 12+: must request SCHEDULE_EXACT_ALARM permission
// Android 13+: user must grant permission — check canScheduleExactAlarms()

class AlarmScheduler @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    fun scheduleReminder(reminderTime: Long, reminderId: Int) {
        if (!alarmManager.canScheduleExactAlarms()) {
            // Direct user to settings
            context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
            return
        }

        val intent = PendingIntent.getBroadcast(
            context,
            reminderId,
            Intent(context, ReminderReceiver::class.java).apply {
                putExtra("reminder_id", reminderId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            reminderTime,
            intent
        )
    }

    fun cancelReminder(reminderId: Int) {
        val intent = PendingIntent.getBroadcast(
            context, reminderId,
            Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        intent?.let { alarmManager.cancel(it) }
    }
}
```

---

## BroadcastReceiver

```kotlin
// Manifest-registered — survives app close (for system broadcasts)
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Reschedule alarms after boot
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(...)
        }
    }
}
// In manifest:
// <receiver android:name=".BootReceiver" android:exported="true">
//     <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter>
// </receiver>
// <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

// Runtime-registered — app must be running (for dynamic broadcasts)
class NetworkReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val isConnected = cm.activeNetworkInfo?.isConnectedOrConnecting == true
        onNetworkChanged(isConnected)
    }
}

// Register/unregister with lifecycle
class MyFragment : Fragment() {
    private val networkReceiver = NetworkReceiver()

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION)
        requireContext().registerReceiver(networkReceiver, filter)
    }

    override fun onStop() {
        requireContext().unregisterReceiver(networkReceiver)
        super.onStop()
    }
}

// Ordered broadcast (results passed between receivers)
sendOrderedBroadcast(Intent("com.example.MY_ACTION"), null)
```

---

## Firebase Cloud Messaging (FCM)

```kotlin
// 1. Add google-services.json to app/
// 2. Dependencies: firebase-messaging-ktx

class MyFirebaseMessagingService : FirebaseMessagingService() {

    // Token refresh — send to your server
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Store token server-side to send targeted notifications
        CoroutineScope(SupervisorJob()).launch {
            userRepository.updateFcmToken(token)
        }
    }

    // Foreground message handling
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Data message — always delivered
        message.data.let { data ->
            val type = data["type"]
            when (type) {
                "article" -> handleArticleNotification(data)
                "message" -> handleMessageNotification(data)
            }
        }

        // Notification message — only delivered when app in foreground
        message.notification?.let { notification ->
            showLocalNotification(notification.title, notification.body)
        }
    }

    private fun showLocalNotification(title: String?, body: String?) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(mainPendingIntent())
            .build()

        NotificationManagerCompat.from(this)
            .notify(System.currentTimeMillis().toInt(), notification)
    }
}

// Get current token
FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
    if (task.isSuccessful) {
        val token = task.result
        Log.d("FCM", "Token: $token")
    }
}

// Subscribe to topic (server-side broadcast)
FirebaseMessaging.getInstance().subscribeToTopic("news_tech")
    .addOnCompleteListener { task -> Log.d("FCM", "Subscribed: ${task.isSuccessful}") }
```

---

## Doze Mode Impact

**Doze mode restrictions (when device is stationary + screen off):**
- Deferred network access
- Wake locks ignored
- JobScheduler / WorkManager deferred
- AlarmManager.set() and setInexactRepeating() deferred

**What still works in Doze:**
- FCM high-priority messages
- AlarmManager.setExactAndAllowWhileIdle()
- Foreground services

**Testing Doze:**
```bash
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle force-idle deep
adb shell dumpsys deviceidle step deep  # advance through states
adb shell dumpsys battery reset         # exit
```

---

## Decision Tree: Background Work

```
Need guaranteed execution even if app killed?
  YES → WorkManager
    Immediate, time-sensitive? → setExpedited()
    Periodic? → PeriodicWorkRequest (min 15 min)
    Chained pipeline? → WorkContinuation
  NO → Coroutine in LifecycleScope/viewModelScope

Need exact time trigger?
  YES → AlarmManager.setExactAndAllowWhileIdle()
  NO → WorkManager with flex window

Ongoing operation (music, location, download)?
  YES → Foreground Service (declare type in manifest)

System event response (boot, connectivity)?
  YES → BroadcastReceiver (manifest-registered for system events)
```
