# Accessibility and Localization

## VoiceOver — Core APIs

VoiceOver is Apple's screen reader. Users navigate by swiping through elements; the system announces each element using accessibility properties.

```swift
// accessibilityLabel: what is this element?
Image("star_icon")
    .accessibilityLabel("Favorite")  // VoiceOver says "Favorite"

// accessibilityValue: current value of a control
Slider(value: $volume)
    .accessibilityValue("\(Int(volume * 100)) percent")

// accessibilityHint: what does activating it do? (optional, read after pause)
Button("Delete") { delete() }
    .accessibilityHint("Removes the item from your list")

// Hide decorative elements
Image("background_pattern")
    .accessibilityHidden(true)

// Group elements (swipe through as one)
VStack {
    Text(user.name)
    Text(user.role)
}
.accessibilityElement(children: .combine)
// VoiceOver says "John Smith, Engineer" as one unit
```

### accessibilityAction — Custom Actions

```swift
// Add swipe actions accessible to VoiceOver
ItemRow(item: item)
    .accessibilityAction(named: "Mark as favorite") {
        favorite(item)
    }
    .accessibilityAction(named: "Delete") {
        delete(item)
    }
    .accessibilityAction(.magicTap) {  // two-finger double tap
        playPause()
    }
```

### Custom Rotors

VoiceOver rotors (twist two fingers) for navigating specific element types:

```swift
struct ArticleView: View {
    var article: Article
    @State private var headings: [Heading] = []

    var body: some View {
        ScrollView {
            /* article content */
        }
        .accessibilityRotor("Headings") {
            ForEach(headings) { heading in
                AccessibilityRotorEntry(heading.text, id: heading.id)
            }
        }
    }
}
```

## Dynamic Type

Support all text size categories including accessibility sizes (up to ~310% of default).

```swift
// Always use .font() with system styles — never fixed font sizes
Text("Title")
    .font(.title)              // scales automatically
    .font(.system(.body))      // also scales

// Custom font that scales
Text("Custom")
    .font(.custom("MyFont", size: 17, relativeTo: .body))

// Scalable images
Image(systemName: "heart.fill")
    .imageScale(.large)   // respects Dynamic Type size
    .font(.title)         // SF Symbols scale with text style

// Check current size in layout decisions
@Environment(\.dynamicTypeSize) var typeSize

var body: some View {
    if typeSize >= .accessibility1 {
        VStack { labelAndValue }  // vertical layout for large sizes
    } else {
        HStack { labelAndValue }  // horizontal for normal sizes
    }
}

// Limit scaling where necessary (e.g., navigation bar)
Text("Tab Label")
    .dynamicTypeSize(.small ... .accessibility2)  // cap at accessibility2
```

## High Contrast and Reduce Motion

```swift
// High contrast
@Environment(\.colorSchemeContrast) var contrast
// Use .increased for custom colors

Color.blue
    // Semantic colors auto-adjust for high contrast
    .overlay(contrast == .increased ? Color.black.opacity(0.1) : Color.clear)

// Reduce Motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

Button("Animate") {
    withAnimation(reduceMotion ? nil : .spring()) {
        isExpanded.toggle()
    }
}

// Reduce Transparency
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

.background(reduceTransparency ? Color(.systemBackground) : Color(.systemBackground).opacity(0.8))
```

## UIAccessibility Notifications (UIKit / bridged)

```swift
// Announce after async operation completes
UIAccessibility.post(notification: .announcement, argument: "Download complete")

// Move VoiceOver focus to a specific element
UIAccessibility.post(notification: .screenChanged, argument: newFocusView)

// Layout changed (announce without moving focus)
UIAccessibility.post(notification: .layoutChanged, argument: nil)
```

In SwiftUI:
```swift
AccessibilityNotification.Announcement("Item deleted").post()
```

## Localization Setup

### String Catalog (iOS 17+ — Xcode 15+)

Modern replacement for `.strings` files. Xcode 15 automatically builds `Localizable.xcstrings` from source code.

```swift
// Source code — Xcode extracts these automatically
Text("Welcome back, \(userName)")
Text("items_count \(count)", tableName: "Plurals")
Button("Submit") { }
```

In Xcode: Editor → Export Localizations → send `.xcloc` to translator → import back.

### NSLocalizedString (Legacy / Manual)

```swift
// Basic
let title = NSLocalizedString("welcome_title", comment: "Title on the welcome screen")

// With format string
let message = String(format: NSLocalizedString("items_count", comment: ""), count)

// String(localized:) — modern Swift API
let text = String(localized: "welcome_title", comment: "Title on welcome screen")

// With table
let text2 = String(localized: "button_title", table: "Buttons")
```

### Localizable.strings Format

```
/* Onboarding welcome title */
"welcome_title" = "Welcome to MyApp";

/* Number of items, %d is the count */
"items_count" = "%d items";
```

### Pluralization

```swift
// Localizable.stringsdict (legacy)
// Key: "items_count"
// NSStringPluralRuleType: one → "%d item", other → "%d items"

// String Catalog (modern — handles plural rules per language automatically)
// Xcode generates the plural forms based on CLDR rules
String(localized: "\(count) items", comment: "Item count")
```

### RTL Layout Support

SwiftUI handles RTL automatically when you use trailing/leading instead of right/left:

```swift
// RTL-safe
HStack {
    Image(systemName: "person")      // leading (left in LTR, right in RTL)
    Text("Username")
    Spacer()
    Text("Details")                  // trailing
}

// Avoid explicit .leading/.trailing alignments on HStack — use semantic ones
// Don't use: .frame(maxWidth: .infinity, alignment: .left)  // breaks RTL
// Do use:    .frame(maxWidth: .infinity, alignment: .leading)  // RTL-aware
```

Explicit RTL flip for custom icons/arrows:
```swift
Image(systemName: "arrow.right")
    .flipsForRightToLeftLayoutDirection(true)
```

### Locale-Aware Formatting

```swift
// Numbers
let formatted = count.formatted(.number)  // locale-aware separators
let currency = price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
let percent = ratio.formatted(.percent.precision(.fractionLength(1)))

// Dates
let date = Date.now.formatted(date: .abbreviated, time: .shortened)
let relative = Date.now.addingTimeInterval(-3600).formatted(.relative(presentation: .named))
// "1 hour ago" (localized)

// Measurement
let distance = Measurement(value: 42.195, unit: UnitLength.kilometers)
let text = distance.formatted()  // "42.195 km" or "26.2 mi" based on locale
```

### Testing Localization

```swift
// Launch with specific locale in UI tests
app.launchArguments = ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]

// Test double-length pseudolanguage (finds layout issues)
app.launchArguments = ["-NSDoubleLocalizedStrings", "YES"]

// Accented pseudolanguage
app.launchArguments = ["-AppleLanguages", "(en)", "-NSAccentuateUiControls", "YES"]
```

## Accessibility Audit

In Xcode 15+: Debug → Accessibility Inspector → Run Audit. Flags:
- Missing labels on interactive elements
- Insufficient contrast
- Touch targets below 44×44 pt

```swift
// Minimum touch target (44×44 pt)
Button("X") { dismiss() }
    .frame(minWidth: 44, minHeight: 44)  // invisible hit area

// Or use contentShape for tap area expansion
Image(systemName: "xmark")
    .contentShape(Rectangle().size(width: 44, height: 44))
    .onTapGesture { dismiss() }
```

## Accessibility Checklist

```
VoiceOver:
  [ ] All interactive elements have accessibilityLabel
  [ ] Images have labels (or are hidden if decorative)
  [ ] Custom controls have accessibilityValue and accessibilityHint
  [ ] Logical reading order (use accessibilitySortPriority if needed)

Dynamic Type:
  [ ] No hardcoded font sizes
  [ ] Layouts tested at accessibility5 size
  [ ] Images scale with content size (don't clip text)

Motor:
  [ ] Touch targets >= 44x44pt
  [ ] No time-limited interactions
  [ ] Full keyboard navigation (iPadOS)

Color:
  [ ] Information not conveyed by color alone
  [ ] Contrast ratio >= 4.5:1 for normal text, 3:1 for large text
  [ ] High contrast mode tested

Motion:
  [ ] Reduce Motion respected for all animations
  [ ] No essential content in animations only
```
