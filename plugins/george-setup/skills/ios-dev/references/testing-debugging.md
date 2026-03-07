# Testing and Debugging

## XCTest — Unit Tests

```swift
import XCTest
@testable import MyApp

final class ItemViewModelTests: XCTestCase {
    var sut: ItemViewModel!
    var mockService: MockItemService!

    override func setUp() {
        super.setUp()
        mockService = MockItemService()
        sut = ItemViewModel(service: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    func test_loadItems_success_populatesItems() async throws {
        // Given
        let expected = [Item(id: 1, name: "Test")]
        mockService.itemsToReturn = expected

        // When
        await sut.loadItems()

        // Then
        XCTAssertEqual(sut.items, expected)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func test_loadItems_failure_setsError() async {
        // Given
        mockService.errorToThrow = NetworkError.serverError

        // When
        await sut.loadItems()

        // Then
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertNotNil(sut.error)
    }
}
```

## XCTestExpectation — Async Tests

```swift
// Prefer async/await tests (no expectation needed for modern code)
func test_fetchUser_returnsUser() async throws {
    let user = try await sut.fetchUser(id: 1)
    XCTAssertEqual(user.id, 1)
}

// XCTestExpectation for callback-based code
func test_legacyCallback() {
    let expectation = expectation(description: "callback called")
    sut.legacyFetch { result in
        XCTAssertNotNil(try? result.get())
        expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
}

// Multiple expectations
func test_multipleCallbacks() {
    let exp1 = expectation(description: "first")
    let exp2 = expectation(description: "second")
    // ... fulfill both
    wait(for: [exp1, exp2], timeout: 5, enforceOrder: true)
}
```

## Mocking with Protocols

```swift
// Define protocol
protocol ItemServiceProtocol {
    func fetchItems() async throws -> [Item]
    func createItem(_ item: ItemCreate) async throws -> Item
    func deleteItem(id: Int) async throws
}

// Mock implementation
final class MockItemService: ItemServiceProtocol {
    var itemsToReturn: [Item] = []
    var errorToThrow: Error?
    var createCalled = false
    var deletedIDs: [Int] = []

    func fetchItems() async throws -> [Item] {
        if let error = errorToThrow { throw error }
        return itemsToReturn
    }

    func createItem(_ item: ItemCreate) async throws -> Item {
        createCalled = true
        if let error = errorToThrow { throw error }
        return Item(id: 99, name: item.name)
    }

    func deleteItem(id: Int) async throws {
        deletedIDs.append(id)
        if let error = errorToThrow { throw error }
    }
}
```

## ViewInspector — SwiftUI Unit Tests

```swift
// Package: github.com/nalexn/ViewInspector
import ViewInspector

struct ContentView: View, Inspectable {
    @State var text = "Hello"
    var body: some View {
        VStack {
            Text(text)
            Button("Tap") { text = "Tapped" }
        }
    }
}

final class ContentViewTests: XCTestCase {
    func test_initialText() throws {
        let view = ContentView()
        let text = try view.inspect().vStack().text(0).string()
        XCTAssertEqual(text, "Hello")
    }

    func test_buttonTapChangesText() throws {
        let view = ContentView()
        try view.inspect().vStack().button(1).tap()
        let text = try view.inspect().vStack().text(0).string()
        XCTAssertEqual(text, "Tapped")
    }
}
```

## UI Testing with Accessibility Identifiers

```swift
// In production code — add accessibility identifiers
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .accessibilityIdentifier("loginEmailField")
            SecureField("Password", text: $password)
                .accessibilityIdentifier("loginPasswordField")
            Button("Sign In") { signIn() }
                .accessibilityIdentifier("loginButton")
        }
    }
}

// XCUITest
final class LoginUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]  // Flag to use mock data
        app.launch()
    }

    func test_login_withValidCredentials_showsHome() {
        let emailField = app.textFields["loginEmailField"]
        let passwordField = app.secureTextFields["loginPasswordField"]

        emailField.tap()
        emailField.typeText("test@example.com")
        passwordField.tap()
        passwordField.typeText("password123")
        app.buttons["loginButton"].tap()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
}
```

## Snapshot Testing

```swift
// Package: github.com/pointfreeco/swift-snapshot-testing
import SnapshotTesting

final class ItemRowSnapshotTests: XCTestCase {
    func test_itemRow_default() {
        let view = ItemRow(item: .fixture())
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 375)))
    }

    func test_itemRow_darkMode() {
        let view = ItemRow(item: .fixture())
            .environment(\.colorScheme, .dark)
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 375)),
                      named: "dark")
    }

    // Record mode: add record: true to generate reference images first
    func test_itemRow_record() {
        let view = ItemRow(item: .fixture())
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 375)),
                      record: false)  // change to true to update snapshots
    }
}
```

## Xcode Debugger

### Key LLDB Commands

```lldb
# Print expression
p someVariable
po someObject           # print description (calls debugDescription)
p/x someInt            # hex format
p/b someInt            # binary

# Evaluate Swift expression
expr let x = myArray.count; print(x)

# Backtrace
bt                     # show call stack
bt all                 # all threads
thread select 3        # switch to thread 3

# Breakpoints
br set -f MyFile.swift -l 42       # file:line breakpoint
br set -n viewDidLoad              # method breakpoint
br set -c "count > 10"            # conditional
br list                           # show all
br del 2                          # delete breakpoint #2

# Memory
memory read 0x1234                 # read raw memory
frame variable                    # all local variables
```

### Useful Xcode Breakpoints

- **Exception breakpoint**: Debug → Breakpoints → Create Exception Breakpoint. Catches exceptions before they bubble up.
- **Symbolic breakpoint**: Break on any call to a method by name (e.g., `[UIView layoutSubviews]`).
- **Watchpoint**: Right-click variable in debug area → Watch — breaks when value changes.

## Address Sanitizer and Thread Sanitizer

```
# Enable in Xcode: Product → Scheme → Edit → Diagnostics tab
# Address Sanitizer: detects buffer overflows, use-after-free, heap corruption
# Thread Sanitizer: detects data races (concurrent read/write)
```

**When to run TSan**: After adding new concurrent code, before shipping features that touch shared state. Note: ~5x slowdown, incompatible with ASan simultaneously.

## OSLog — Structured Logging

```swift
import OSLog

// Define loggers per subsystem
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}

// Usage
Logger.networking.info("Request started: \(url)")
Logger.networking.error("Request failed: \(error.localizedDescription)")
Logger.networking.debug("Response: \(response, privacy: .private)")  // redacted in logs

// View in Console.app: filter by subsystem/category
// Or in Xcode: Window → Devices and Simulators → View Device Logs
```

**Why OSLog over print**: Zero cost when not collected, structured filtering in Console.app, privacy levels for sensitive data, persisted to system log.

## Testing Checklist

```
Unit tests:
  [ ] ViewModel: all state transitions
  [ ] Service layer: success + error cases
  [ ] Pure functions (formatters, validators)
  [ ] Async functions with mock services

Integration tests:
  [ ] Network client with URLProtocol mock
  [ ] SwiftData/Core Data with in-memory store

UI tests:
  [ ] Critical paths: login, checkout, onboarding
  [ ] Accessibility identifiers on interactive elements

Snapshot tests:
  [ ] Component library views
  [ ] Dark mode variants
  [ ] Dynamic Type (accessibility size)
```

## Test Performance

```swift
// Measure code performance
func test_sortingLargeArray_performance() {
    let items = (0..<10000).map { Item(id: $0, name: "Item \($0)") }
    measure {
        _ = items.sorted { $0.name < $1.name }
    }
}

// In-memory SwiftData for fast tests
let container = try ModelContainer(
    for: Trip.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```
