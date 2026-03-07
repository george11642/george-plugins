# Push Notifications and Widgets

## APNs Setup

### Authentication Key (Recommended over Certificates)
1. Apple Developer Portal → Certificates, IDs & Profiles → Keys → "+"
2. Enable "Apple Push Notifications service (APNs)"
3. Download `.p8` key — **download once, store securely**
4. Note: Key ID and Team ID for server use

### Request Permission

```swift
import UserNotifications

// Request authorization (iOS 10+)
func requestNotificationPermission() async throws -> Bool {
    let center = UNUserNotificationCenter.current()
    return try await center.requestAuthorization(options: [.alert, .sound, .badge])
}

// Register for remote notifications (on main thread)
@MainActor
func registerForRemoteNotifications() async -> Bool {
    let granted = try? await requestNotificationPermission()
    guard granted == true else { return false }
    UIApplication.shared.registerForRemoteNotifications()
    return true
}

// AppDelegate receives token
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // Send token to your server
    Task { try await APIService.shared.registerPushToken(token) }
}
```

### Local Notifications

```swift
func scheduleLocalNotification(title: String, body: String, delay: TimeInterval) async throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.badge = 1

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
}

// Calendar trigger
let components = DateComponents(hour: 9, minute: 0)
let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
```

### Rich Notifications — Attachments

```swift
// Server payload:
// { "aps": { "alert": "New photo", "mutable-content": 1 }, "image-url": "https://..." }

// Notification Service Extension — runs before display
class NotificationService: UNNotificationServiceExtension {
    var handler: ((UNNotificationContent) -> Void)?
    var bestContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
        self.handler = handler
        let content = request.content.mutableCopy() as! UNMutableNotificationContent
        self.bestContent = content

        guard let urlString = request.content.userInfo["image-url"] as? String,
              let url = URL(string: urlString) else { handler(content); return }

        Task {
            if let attachment = try? await downloadAttachment(from: url) {
                content.attachments = [attachment]
            }
            handler(content)
        }
    }

    private func downloadAttachment(from url: URL) async throws -> UNNotificationAttachment {
        let (localURL, _) = try await URLSession.shared.download(from: url)
        return try UNNotificationAttachment(identifier: UUID().uuidString, url: localURL)
    }
}
```

### Notification Categories and Actions

```swift
// Register categories at app launch
func registerNotificationCategories() {
    let acceptAction = UNNotificationAction(
        identifier: "ACCEPT",
        title: "Accept",
        options: [.foreground]
    )
    let declineAction = UNNotificationAction(
        identifier: "DECLINE",
        title: "Decline",
        options: [.destructive]
    )
    let requestCategory = UNNotificationCategory(
        identifier: "FRIEND_REQUEST",
        actions: [acceptAction, declineAction],
        intentIdentifiers: [],
        options: .customDismissAction
    )
    UNUserNotificationCenter.current().setNotificationCategories([requestCategory])
}

// Handle action in AppDelegate / delegate
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    switch response.actionIdentifier {
    case "ACCEPT": handleAccept(response.notification.request.content.userInfo)
    case "DECLINE": handleDecline(response.notification.request.content.userInfo)
    default: break
    }
    completionHandler()
}
```

### Background Push (Silent)

```swift
// Server payload: { "aps": { "content-available": 1 }, "data": {...} }
// Capabilities: Background Modes → Remote notifications

func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    Task {
        do {
            try await syncData(from: userInfo)
            completionHandler(.newData)
        } catch {
            completionHandler(.failed)
        }
    }
}
```

## Firebase Cloud Messaging (FCM)

```swift
// Podfile: pod 'FirebaseMessaging'
import FirebaseMessaging

// AppDelegate
FirebaseApp.configure()
Messaging.messaging().delegate = self

// Receive FCM token
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Send fcmToken to your server
        guard let token = fcmToken else { return }
        Task { try await APIService.shared.registerFCMToken(token) }
    }
}
```

## WidgetKit

### Basic Widget

```swift
import WidgetKit
import SwiftUI

// Entry — the data snapshot
struct StockEntry: TimelineEntry {
    let date: Date
    let symbol: String
    let price: Double
    let change: Double
}

// Provider — fetches data and creates timeline
struct StockProvider: TimelineProvider {
    func placeholder(in context: Context) -> StockEntry {
        StockEntry(date: .now, symbol: "AAPL", price: 189.50, change: 1.2)
    }

    func getSnapshot(in context: Context, completion: @escaping (StockEntry) -> Void) {
        Task {
            let entry = try? await fetchCurrentEntry() ?? placeholder(in: context)
            completion(entry!)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StockEntry>) -> Void) {
        Task {
            var entries: [StockEntry] = []
            let current = try? await fetchCurrentEntry() ?? placeholder(in: context)
            entries.append(current!)

            // Refresh after 15 minutes
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

// Widget View
struct StockWidgetView: View {
    var entry: StockProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.symbol).font(.headline)
            Text("$\(entry.price, specifier: "%.2f")").font(.title2).bold()
            HStack {
                Image(systemName: entry.change >= 0 ? "arrow.up" : "arrow.down")
                Text("\(abs(entry.change), specifier: "%.2f")%")
            }
            .foregroundStyle(entry.change >= 0 ? .green : .red)
        }
        .containerBackground(.fill.tertiary, for: .widget)  // iOS 17+
    }
}

// Widget definition
@main
struct StockWidget: Widget {
    let kind = "StockWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StockProvider()) { entry in
            StockWidgetView(entry: entry)
        }
        .configurationDisplayName("Stock Price")
        .description("Track your favorite stocks.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
```

### Deep Links from Widget

```swift
// In widget view:
Link(destination: URL(string: "myapp://stock/AAPL")!) {
    StockRow(symbol: "AAPL")
}

// For system small (single tap only), use widgetURL:
StockWidgetView(entry: entry)
    .widgetURL(URL(string: "myapp://stock/\(entry.symbol)"))

// Handle in app:
.onOpenURL { url in
    router.handle(url)
}
```

### iOS 17 Interactive Widgets

```swift
// Widgets can now have Button and Toggle
struct InteractiveWidgetView: View {
    var entry: Entry

    var body: some View {
        VStack {
            Text(entry.taskName)
            // AppIntent-powered button
            Button(intent: ToggleTaskIntent(taskID: entry.taskID)) {
                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
        }
    }
}

// AppIntent
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    @Parameter(title: "Task ID") var taskID: String

    func perform() async throws -> some IntentResult {
        await TaskStore.shared.toggle(id: taskID)
        return .result()
    }
}
```

### App Intents (iOS 16+)

```swift
// Expose app actions to Siri, Shortcuts, Spotlight
struct OpenItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Item"
    static var description = IntentDescription("Opens a specific item in MyApp")

    @Parameter(title: "Item Name")
    var itemName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = await ItemStore.shared.find(named: itemName) else {
            throw IntentError.notFound
        }
        await MainActor.run {
            NavigationModel.shared.open(item)
        }
        return .result(dialog: "Opening \(item.name)")
    }
}

// Register with AppShortcutsProvider for automatic Siri phrases
struct MyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenItemIntent(),
            phrases: ["Open \(\.$itemName) in MyApp"],
            shortTitle: "Open Item",
            systemImageName: "square.grid.2x2"
        )
    }
}
```

## Notification Troubleshooting

| Issue | Fix |
|-------|-----|
| Token not received | Check Capabilities: Push Notifications enabled |
| Notification not shown in foreground | Implement `UNUserNotificationCenterDelegate.willPresent` returning `.banner` |
| Silent push not waking app | Enable Background Modes → Remote notifications |
| Widget not refreshing | Call `WidgetCenter.shared.reloadAllTimelines()` after data update |
| App Extension can't access app data | Use App Groups + shared `UserDefaults(suiteName:)` |
