# Play Store & CI/CD

## App Bundle vs APK

**Always publish AAB (.aab) — never APK to Play Store.**

| | APK | AAB |
|---|---|---|
| What ships | Full APK to every device | Only resources/code needed for that device |
| Size savings | None | 15-65% smaller download |
| Dynamic delivery | No | Yes (features on demand) |
| Required for Play | No (but deprecated path) | Yes (required since Aug 2021) |

```bash
# Build release AAB
./gradlew bundleRelease

# Build release APK (for sideloading only)
./gradlew assembleRelease
```

---

## Signing Configuration

```kotlin
// build.gradle.kts
android {
    signingConfigs {
        create("release") {
            // Load from local.properties or CI environment
            storeFile = file(properties["KEYSTORE_PATH"] as String)
            storePassword = properties["KEYSTORE_PASSWORD"] as String
            keyAlias = properties["KEY_ALIAS"] as String
            keyPassword = properties["KEY_PASSWORD"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

// local.properties (never commit this file)
// KEYSTORE_PATH=../keystore/release.jks
// KEYSTORE_PASSWORD=mypassword
// KEY_ALIAS=mykey
// KEY_PASSWORD=mykeypassword
```

**Play App Signing:**
- Upload key: signs your AAB before upload to Play
- App signing key: Play re-signs with this before delivery to devices
- Enroll: Play Console → Setup → App integrity → App signing
- Advantage: if upload key is lost, Google can reset it

---

## Build Flavors

```kotlin
android {
    flavorDimensions += listOf("env", "store")

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            buildConfigField("String", "BASE_URL", "\"https://dev.api.example.com/\"")
        }
        create("staging") {
            dimension = "env"
            buildConfigField("String", "BASE_URL", "\"https://staging.api.example.com/\"")
        }
        create("prod") {
            dimension = "env"
            buildConfigField("String", "BASE_URL", "\"https://api.example.com/\"")
        }
        create("google") {
            dimension = "store"
        }
        create("amazon") {
            dimension = "store"
            applicationIdSuffix = ".amazon"
        }
    }
}

// Source sets — flavor-specific resources/code
// src/dev/java/...          — dev-only code
// src/prod/res/values/...   — prod-only strings
// src/google/AndroidManifest.xml — Google Play store manifest additions

// Access BuildConfig in code
val url = BuildConfig.BASE_URL  // auto-generated per flavor
```

---

## ProGuard / R8

```proguard
# proguard-rules.pro

# Retrofit / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepattributes Signature
-keepattributes *Annotation*

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class **$$serializer {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.example.**$$serializer { *; }
@kotlinx.serialization.Serializable class com.example.** { *; }

# Hilt
-dontwarn dagger.hilt.**

# Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Enums (if accessed by name)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Crashlytics / Firebase
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }

# Room
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.**

# Keep custom views (for XML inflation)
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
}
```

**R8 full mode** (more aggressive shrinking):
```kotlin
// gradle.properties
android.enableR8.fullMode=true
```

**Check mapping file** after release build: `build/outputs/mapping/release/mapping.txt`
Decode stack traces: `retrace mapping.txt crash.txt` or upload to Play Console.

---

## Version Code Strategy

```kotlin
// Version code must increase monotonically — never reuse
// Strategy: auto-increment from CI build number
android {
    defaultConfig {
        versionCode = System.getenv("BUILD_NUMBER")?.toInt() ?: 1
        versionName = "2.4.1"
    }
}

// Or date-based (YYMMDDHH format = sortable, high ceiling)
// 2024050914 = 2024-05-09 14:00
val versionCode = SimpleDateFormat("yyMMddHH").format(Date()).toInt()
```

---

## GitHub Actions CI/CD

```yaml
# .github/workflows/release.yml
name: Build & Deploy

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
            .gradle
          key: gradle-${{ hashFiles('**/*.gradle.kts', '**/gradle-wrapper.properties') }}

      - name: Run tests
        run: ./gradlew testProdReleaseUnitTest

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > keystore/release.jks

      - name: Build release AAB
        run: ./gradlew bundleProdRelease
        env:
          KEYSTORE_PATH: keystore/release.jks
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Upload to Play Store (Internal Track)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.example.myapp
          releaseFiles: app/build/outputs/bundle/prodRelease/*.aab
          track: internal
          mappingFile: app/build/outputs/mapping/prodRelease/mapping.txt
          changesNotSentForReview: true
```

---

## Fastlane

```ruby
# fastlane/Fastfile
platform :android do
  lane :test do
    gradle(task: "test", build_type: "Debug")
  end

  lane :beta do
    gradle(
      task: "bundle",
      flavor: "prod",
      build_type: "Release",
      print_command: false,
      properties: {
        "android.injected.signing.store.file" => ENV["KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["KEY_PASSWORD"],
      }
    )
    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/prodRelease/app-prod-release.aab",
      mapping: "app/build/outputs/mapping/prodRelease/mapping.txt",
      skip_upload_screenshots: true
    )
  end

  lane :promote_to_production do |options|
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      rollout: "0.10"  # 10% staged rollout
    )
  end
end
```

---

## Firebase App Distribution

```yaml
# In GitHub Actions — distribute to testers before Play Store
- name: Upload to Firebase App Distribution
  uses: wzieba/Firebase-Distribution-Github-Action@v1
  with:
    appId: ${{ secrets.FIREBASE_APP_ID }}
    serviceCredentialsFileContent: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    groups: "internal-testers, qa-team"
    file: app/build/outputs/bundle/devRelease/app-dev-release.aab
    releaseNotesFile: CHANGELOG.md
```

---

## Play Store Tracks

```
Internal Testing → Closed Testing (Alpha) → Open Testing (Beta) → Production
     ↑                    ↑                        ↑                   ↑
 Instant publish      Up to 100 users         Unlimited users     Staged rollout
 No review needed     Opt-in link             Opt-in / opt-out    0%-100% rollout
```

**Staged rollout best practice:**
1. Publish to Internal (instant, test core flows)
2. Promote to Closed Beta (targeted group)
3. Production at 10% rollout → monitor crash rate for 24h
4. Increase to 25% → 50% → 100%
5. Halt rollout if crash rate > baseline

**aab metadata checklist:**
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Screenshots: phone (2-8), tablet 7" (optional), tablet 10" (optional)
- [ ] Feature graphic (1024x500 PNG)
- [ ] App icon (512x512 PNG, ≤1MB)
- [ ] Content rating questionnaire
- [ ] Privacy policy URL
- [ ] Data safety section completed
- [ ] Target API level = 35 (required Aug 2025+)
