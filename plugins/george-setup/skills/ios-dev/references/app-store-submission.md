# App Store Submission

## App Store Connect Setup

### Before You Build

1. **Bundle ID**: Register in Developer Portal → Certificates, IDs & Profiles → Identifiers
   - Format: `com.company.appname` — lowercase, reverse-domain
   - Must match `PRODUCT_BUNDLE_IDENTIFIER` in Xcode

2. **App Record**: Create in App Store Connect → My Apps → "+"
   - Platform: iOS
   - Bundle ID: must match registered identifier
   - SKU: internal identifier (not shown to users)

3. **Capabilities**: Enable in Developer Portal and Xcode (must match)
   - Push Notifications, iCloud, Sign in with Apple, etc.

## Code Signing

### Automatic Signing (Recommended for Development)

```
Xcode → Target → Signing & Capabilities → "Automatically manage signing"
Team: [Your Team]
```

### Manual Signing (CI/CD)

Certificates needed:
- **Development** (`iPhone Developer`): debug/test builds
- **Distribution** (`iPhone Distribution`): App Store / AdHoc builds

Provisioning profiles needed:
- **Development**: device UDID-based
- **App Store Distribution**: no device UDIDs, linked to distribution cert

```bash
# Export certificate from Keychain as .p12
# Install manually or via Fastlane match
```

### Fastlane match (Recommended for Teams)

```ruby
# Matchfile
git_url("https://github.com/yourorg/certificates")
storage_mode("git")
type("appstore")  # or "development", "adhoc"
app_identifier(["com.company.app"])
username("apple@company.com")
```

```bash
fastlane match appstore     # downloads/creates distribution cert + profile
fastlane match development  # downloads/creates development cert + profile
fastlane match nuke appstore  # DANGER: revokes and regenerates certs
```

## Building for Release

### Xcode Archive

```
Product → Archive → Distribute App → App Store Connect
→ Upload (direct) or Export (.ipa for manual upload)
```

### Fastlane gym (Automated Build)

```ruby
# Fastfile
lane :build do
  match(type: "appstore")
  increment_build_number(
    build_number: latest_testflight_build_number + 1
  )
  gym(
    scheme: "MyApp",
    configuration: "Release",
    export_method: "app-store",
    output_directory: "./build"
  )
end
```

```bash
fastlane gym --scheme MyApp --export-method app-store
```

## TestFlight

### Internal Testing
- Up to 100 internal testers (must be App Store Connect users)
- Builds available immediately after upload processing (~10-30 min)
- No review required
- Builds expire after 90 days

### External Testing
- Up to 10,000 external testers via email invite or public link
- Requires **beta app review** (first build per feature set, usually 1-2 days)
- Subsequent builds with same features: auto-approved

```bash
# Upload to TestFlight via Fastlane
fastlane pilot upload --ipa ./build/MyApp.ipa
fastlane pilot distribute --groups "Internal Beta"
```

## App Store Metadata Requirements

### Screenshots (Required Sizes)
- **6.5" (iPhone 14 Pro Max)**: 1290 × 2796 px — REQUIRED
- **5.5" (iPhone 8 Plus)**: 1242 × 2208 px — REQUIRED
- **12.9" iPad Pro**: 2048 × 2732 px — if universal app
- Maximum 10 screenshots per size
- At least 1 screenshot per required size

```bash
# Fastlane snapshot — automates screenshot capture
fastlane snapshot  # runs UI tests with screenshotting
fastlane frameit   # adds device frames
fastlane deliver   # uploads metadata + screenshots
```

### App Privacy Labels (Required)
Fill accurately in App Store Connect → App Privacy:
- Data types collected: name, email, identifiers, usage data, etc.
- Linked to user vs not linked
- Used for tracking vs not

**Inaccurate privacy labels = rejection.** When in doubt, declare more.

### App Review Guidelines Compliance
Key rejection reasons:
- **4.2 Minimum Functionality**: app must do something useful
- **5.1.1 Privacy**: must have privacy policy URL if collecting any data
- **2.1 App Completeness**: no placeholder content, test accounts required if login needed
- **2.3.3 Accurate Metadata**: screenshots must match actual app
- **3.1.1 In-App Purchase**: digital goods must use IAP (no external payment links)

## Fastlane CI/CD Pipeline

### Fastfile

```ruby
default_platform(:ios)

platform :ios do
  before_all do
    setup_circle_ci  # or setup_github_actions
  end

  desc "Run tests"
  lane :test do
    run_tests(scheme: "MyAppTests", devices: ["iPhone 15"])
  end

  desc "Deploy to TestFlight"
  lane :beta do
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: latest_testflight_build_number + 1)
    gym(scheme: "MyApp", export_method: "app-store")
    pilot(skip_waiting_for_build_processing: true)
    slack(message: "Beta deployed to TestFlight!")
  end

  desc "Deploy to App Store"
  lane :release do
    match(type: "appstore", readonly: true)
    deliver(
      submit_for_review: true,
      automatic_release: false,
      force: true,  # skip HTML report
      skip_screenshots: false,
      metadata_path: "./fastlane/metadata"
    )
  end
end
```

### GitHub Actions Workflow

```yaml
name: Deploy to TestFlight
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Install certificates
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC }}
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_CONTENT: ${{ secrets.ASC_KEY_CONTENT }}
        run: bundle exec fastlane beta
```

### Xcode Cloud (Native CI)

```yaml
# ci_scripts/ci_post_xcodebuild.sh
#!/bin/sh
if [ "$CI_WORKFLOW" = "Deploy to TestFlight" ]; then
  # Post-build scripts
  echo "Build complete"
fi
```

Configure in Xcode → Product → Xcode Cloud → Create Workflow:
- Start condition: branch push
- Build action: archive
- Post-action: TestFlight distribution

## StoreKit 2 — In-App Purchases

```swift
import StoreKit

// Fetch products
func fetchProducts(ids: Set<String>) async throws -> [Product] {
    try await Product.products(for: ids)
}

// Display and purchase
struct PurchaseView: View {
    @State private var products: [Product] = []
    @State private var purchasedIDs: Set<String> = []

    var body: some View {
        ForEach(products) { product in
            HStack {
                Text(product.displayName)
                Spacer()
                Button(product.displayPrice) {
                    Task { try await purchase(product) }
                }
            }
        }
        .task { products = try! await fetchProducts(ids: ["com.app.premium"]) }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                purchasedIDs.insert(transaction.productID)
                await transaction.finish()
            case .unverified: break
            }
        case .userCancelled, .pending: break
        @unknown default: break
        }
    }
}

// Restore purchases (required by App Store guidelines)
func restorePurchases() async {
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result {
            purchasedIDs.insert(transaction.productID)
        }
    }
}

// Listen for transaction updates
func listenForTransactions() -> Task<Void, Error> {
    Task.detached {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                purchasedIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }
}
```

## App Store Optimization (ASO)

- **Title** (30 chars): primary keyword in name
- **Subtitle** (30 chars): secondary keyword, value proposition
- **Keywords field** (100 chars): comma-separated, no spaces, no repeats from title
- **Description** (4000 chars): first 3 lines visible before "more" — front-load value
- **Screenshots**: A/B test with different first screenshot (most impactful)
- **Ratings**: Prompt with `SKStoreReviewRequest.requestReview()` after positive moments

## Version Numbers

- **CFBundleShortVersionString** (Version): semantic, e.g. "2.1.0" — user-visible
- **CFBundleVersion** (Build): must increment for each upload, e.g. "42" — not user-visible

```bash
# Fastlane increment
increment_version_number(version_number: "2.1.0")
increment_build_number  # auto-increments
```
