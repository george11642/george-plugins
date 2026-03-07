# Data Persistence

## SwiftData (iOS 17+) — Modern Persistence

SwiftData is the Swift-native replacement for Core Data. Zero boilerplate for simple use cases.

### Defining Models

```swift
import SwiftData

@Model
final class Trip {
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date

    // Relationships
    @Relationship(deleteRule: .cascade) var activities: [Activity] = []
    var user: User?

    // Unique constraint
    @Attribute(.unique) var id: UUID = UUID()

    // Transformable (non-Codable types)
    @Attribute(.externalStorage) var largeData: Data?

    init(name: String, destination: String, startDate: Date, endDate: Date) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
    }
}
```

### ModelContainer Setup

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, Activity.self])
        // Custom config:
        // .modelContainer(try! ModelContainer(
        //     for: Trip.self,
        //     configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        // ))
    }
}
```

### @Query — Declarative Fetching

```swift
struct TripListView: View {
    @Query(sort: \.startDate, order: .forward)
    private var trips: [Trip]

    @Query(filter: #Predicate<Trip> { trip in
        trip.destination == "Paris"
    })
    private var parisTrips: [Trip]

    var body: some View {
        List(trips) { trip in TripRow(trip: trip) }
    }
}
```

### ModelContext — CRUD

```swift
struct TripListView: View {
    @Environment(\.modelContext) private var context

    func addTrip() {
        let trip = Trip(name: "Summer", destination: "Rome",
                        startDate: .now, endDate: .now.addingTimeInterval(604800))
        context.insert(trip)
        // Auto-save by default, or manually:
        try? context.save()
    }

    func deleteTrip(_ trip: Trip) {
        context.delete(trip)
    }
}
```

### Migrations

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self] }

    @Model final class Trip { var name: String; ... }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self] }

    @Model final class Trip { var name: String; var notes: String = ""; ... }
}

enum TripMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
```

## Core Data — Production-Hardened Persistence

Use Core Data for apps targeting iOS 15 and earlier, or when you need NSPersistentCloudKitContainer.

### NSPersistentContainer Setup

```swift
final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyApp")  // .xcdatamodeld file name
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
```

### Fetch Requests and Predicates

```swift
// SwiftUI
@FetchRequest(
    sortDescriptors: [SortDescriptor(\.name)],
    predicate: NSPredicate(format: "isActive == YES")
) private var items: FetchedResults<Item>

// Programmatic fetch
let request = NSFetchRequest<Item>(entityName: "Item")
request.predicate = NSPredicate(format: "createdAt > %@ AND category == %@", date as CVarArg, category)
request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.name, ascending: true)]
request.fetchBatchSize = 20  // paginate large datasets
let results = try viewContext.fetch(request)
```

### Background Contexts

```swift
// Heavy import on background context
func importData(_ records: [Record]) async throws {
    let context = container.newBackgroundContext()
    try await context.perform {
        for record in records {
            let item = Item(context: context)
            item.configure(from: record)
        }
        try context.save()
    }
}
```

### iCloud Sync with NSPersistentCloudKitContainer

```swift
container = NSPersistentCloudKitContainer(name: "MyApp")
// Enable CloudKit in Capabilities: iCloud + CloudKit
// Add NSPersistentStoreDescription with CloudKit config
let storeDescription = container.persistentStoreDescriptions.first!
storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
storeDescription.setOption(true as NSNumber,
    forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

// Listen for remote changes
NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
    .sink { _ in context.refreshAllObjects() }
    .store(in: &cancellables)
```

## UserDefaults — Small Key-Value Data

```swift
// Property wrapper approach
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// Usage
struct AppSettings {
    @UserDefault(key: "hasSeenOnboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool

    @UserDefault(key: "preferredTheme", defaultValue: "system")
    static var preferredTheme: String
}

// App Groups (share between app and extension/widget)
let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")!
```

## Keychain — Sensitive Data

Never store passwords, tokens, or API keys in UserDefaults or SwiftData.

```swift
// Direct SecItem API
final class KeychainService {
    enum KeychainError: Error { case notFound, unexpectedData, unhandled(OSStatus) }

    func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError.notFound }
        guard let data = item as? Data else { throw KeychainError.unexpectedData }
        return data
    }
}

// KeychainAccess library (simpler API)
import KeychainAccess
let keychain = Keychain(service: "com.myapp.auth")
keychain["authToken"] = token
let token = keychain["authToken"]
```

## FileManager — Document Storage

```swift
// App's Documents directory (backed up by iCloud)
let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

// Caches directory (not backed up, can be purged by OS)
let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!

// Temporary directory
let tempURL = FileManager.default.temporaryDirectory

// Write / read
let fileURL = documentsURL.appendingPathComponent("data.json")
try data.write(to: fileURL, options: .atomic)
let loaded = try Data(contentsOf: fileURL)

// Enumerate directory contents
let contents = try FileManager.default.contentsOfDirectory(
    at: documentsURL,
    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
    options: .skipsHiddenFiles
)
```

## SwiftData vs Core Data Decision

| Concern | SwiftData | Core Data |
|---------|-----------|-----------|
| Min iOS target | iOS 17+ | iOS 13+ |
| Code syntax | Swift macros, modern | Objective-C legacy |
| CloudKit sync | Manual | NSPersistentCloudKitContainer |
| Migration | Lightweight auto, manual | NSMigrationManager full control |
| Instruments support | Good (iOS 17+) | Mature |
| NSFetchedResultsController | No equivalent | Full support |
| Recommendation | New apps (iOS 17+) | Existing apps, iOS 15- |
