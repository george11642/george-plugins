# EAS Version Management

Managing app versions in Expo with EAS Build. Covers remote vs local version sources, auto-increment, build profiles, and CI/CD integration.

## App Version Types

| Field | Platform | Purpose | Example |
|-------|----------|---------|---------|
| `version` | Both | User-facing JS bundle version | `1.2.3` |
| `ios.buildNumber` | iOS | Store build identifier (integer string) | `"42"` |
| `android.versionCode` | Android | Store build identifier (integer) | `42` |

- **`version`**: What users see in the App Store / Play Store listing. Semantic versioning.
- **`buildNumber` / `versionCode`**: Must increment with every store submission. Internal counter.
- You can submit version `1.0.0` with buildNumber `42` — they are independent.

---

## Remote Version Management (Recommended)

EAS servers store and manage `buildNumber` / `versionCode` remotely. This is the default since EAS CLI 12.0.0 and is set automatically by `eas init`.

### eas.json Configuration
```json
{
  "cli": {
    "appVersionSource": "remote"
  },
  "build": {
    "production": {
      "autoIncrement": true
    },
    "preview": {
      "autoIncrement": true
    },
    "development": {}
  }
}
```

### How Remote Versioning Works
1. First build: reads current value from app.json as starting point
2. Each subsequent build with `autoIncrement: true`: EAS increments by 1 server-side
3. Local app.json values are **ignored** when remote source is active — do not manually edit them
4. Remote is the source of truth; values are written to native project at build time

### Remote Version Commands
```bash
# Check current remote version
npx eas-cli@latest build:version:get

# Manually set a specific value (e.g. after platform reset)
npx eas-cli@latest build:version:set --platform ios
npx eas-cli@latest build:version:set --platform android

# Set specific values non-interactively (CI)
npx eas-cli@latest build:version:set --platform ios --version 100
```

### iOS vs Android Parity
With remote versioning, `buildNumber` (iOS) and `versionCode` (Android) are kept in sync automatically — both increment from the same counter. This eliminates the common mistake of them drifting apart.

---

## Local Version Management

Use when you need full control over versioning in your own CI or release tooling.

### eas.json Configuration
```json
{
  "cli": {
    "appVersionSource": "local"
  },
  "build": {
    "production": {
      "autoIncrement": true
    }
  }
}
```

With `appVersionSource: local` + `autoIncrement: true`, EAS reads the current values from your app config and increments them locally before building, then writes them back to the native project.

### Dynamic Version from app.config.js
```js
// app.config.js
const pkg = require('./package.json');

module.exports = {
  name: 'MyApp',
  version: pkg.version,             // sync with package.json version
  ios: {
    buildNumber: String(process.env.BUILD_NUMBER || '1'),
  },
  android: {
    versionCode: parseInt(process.env.BUILD_NUMBER || '1', 10),
  },
};
```

### Script-Based Bump
```bash
# bump-version.sh
CURRENT=$(node -e "console.log(require('./package.json').version)")
npm version patch --no-git-tag-version
NEW=$(node -e "console.log(require('./package.json').version)")
echo "Bumped $CURRENT -> $NEW"
```

---

## Build Profile Version Strategy

### Recommended Multi-Profile Setup
```json
{
  "cli": {
    "appVersionSource": "remote"
  },
  "build": {
    "production": {
      "autoIncrement": true,
      "channel": "production"
    },
    "preview": {
      "autoIncrement": true,
      "channel": "preview",
      "distribution": "internal"
    },
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    }
  }
}
```

### autoIncrement Values
- `true` — increments both `buildNumber` and `versionCode`
- `"buildNumber"` — increments iOS `buildNumber` only
- `"version"` — increments the user-facing `version` (semver patch bump)

---

## Semantic Versioning for Mobile

### Version Bump Decision
| Change Type | version bump | Store submission needed? |
|-------------|-------------|--------------------------|
| Bug fix (JS only) | patch (1.0.1) | No — use OTA update |
| New feature (JS only) | minor (1.1.0) | No — use OTA update |
| New native module | minor or major | Yes — new build required |
| SDK upgrade | major or minor | Yes — new build required |
| Breaking UX change | major | Yes (recommended) |

### Coordinating version with OTA
The `version` in app.json must match across the JS bundle (OTA) and the native binary. OTA updates inherit the `version` of the build they were published against. Do not change `version` for pure OTA updates.

---

## Version in CI/CD

### EAS Workflows (YAML)
```yaml
jobs:
  build-and-submit:
    steps:
      - uses: checkout
      - name: Increment version
        run: npx eas-cli@latest build:version:set --auto-increment --platform all --non-interactive
      - uses: eas/build
        with:
          profile: production
          platform: all
```

### GitHub Actions
```yaml
- name: Build iOS
  run: |
    npx eas-cli@latest build \
      --platform ios \
      --profile production \
      --non-interactive \
      --auto-submit
  env:
    EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
```

### Tagging Git Post-Build
```yaml
- name: Tag release
  run: |
    VERSION=$(node -e "console.log(require('./package.json').version)")
    BUILD=$(npx eas-cli@latest build:version:get --platform ios --json | jq -r '.buildNumber')
    git tag "v${VERSION}-build${BUILD}"
    git push origin "v${VERSION}-build${BUILD}"
```

---

## Common Mistakes

1. **Editing buildNumber/versionCode in app.json when using remote source** — ignored; use `eas build:version:set` instead.
2. **Not incrementing before every store submission** — Apple and Google reject builds with duplicate build numbers.
3. **Using `autoIncrement` on development profile** — wastes version counter on dev builds. Only set on production/preview.
4. **iOS and Android buildNumbers drifting** — remote versioning prevents this; local versioning requires discipline.
5. **Bumping `version` for OTA-only fixes** — unnecessary; the native binary version is what the store tracks.

---

## Checking Version in App

```tsx
import * as Application from 'expo-application';

// User-facing version string (from app.json "version")
const version = Application.nativeApplicationVersion;  // "1.2.3"

// Build number / version code
const build = Application.nativeBuildVersion;          // "42"

// Full display string
const displayVersion = `v${version} (${build})`;
```
