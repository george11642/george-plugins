# EAS Update Strategy

OTA (Over-The-Air) update strategy using EAS Update. Covers when to use OTA vs store builds, channels, rollback, monitoring, and CI/CD integration.

## OTA vs Store Build Decision Tree

```
Did you change any native code?
  → iOS/ or android/ directories
  → New native module (expo install something with native code)
  → SDK upgrade
  → New permissions in app.json
  → app.json "plugins" array changed
     YES → Store build required (OTA will not work)
     NO  → OTA update is safe
```

### What OTA Can Update
- TypeScript/JavaScript source code
- React components and screens
- Assets bundled with Metro (images, fonts loaded via require())
- Business logic, API calls, navigation structure
- Styles (NativeWind classes, StyleSheet)

### What OTA Cannot Update
- Native modules (C++, Java, Swift, Kotlin)
- SDK version upgrades
- Expo config plugins output (generated native code)
- App permissions and entitlements
- App icons, splash screen (these are native assets)

---

## Setup

```bash
npx expo install expo-updates
npx eas-cli@latest update:configure
```

### app.json
```json
{
  "expo": {
    "updates": {
      "url": "https://u.expo.dev/[your-project-id]",
      "enabled": true,
      "checkAutomatically": "ON_LOAD",
      "fallbackToCacheTimeout": 0
    },
    "runtimeVersion": {
      "policy": "appVersion"
    }
  }
}
```

### eas.json Channel Assignment
```json
{
  "build": {
    "production": {
      "channel": "production"
    },
    "preview": {
      "channel": "preview",
      "distribution": "internal"
    },
    "development": {
      "developmentClient": true,
      "channel": "development"
    }
  }
}
```

---

## Channels and Branches

- A **branch** holds a sequence of published update bundles
- A **channel** is mapped to a branch; devices on that channel receive updates from the branch
- Decouple channels from branches to enable staged rollouts and hotfix patterns

### Channel → Branch Mapping
```bash
# Point production channel at main branch
npx eas-cli@latest channel:edit production --branch main

# Point preview channel at staging branch
npx eas-cli@latest channel:edit preview --branch staging

# Check current mappings
npx eas-cli@latest channel:list
```

---

## Publishing Updates

```bash
# Publish to a channel (most common)
npx eas-cli@latest update --channel production --message "Fix checkout bug"

# Publish to a specific branch
npx eas-cli@latest update --branch main --message "Feature flag update"

# Target a platform
npx eas-cli@latest update --channel production --platform ios

# Preview what will be included (dry run)
npx eas-cli@latest update --channel production --dry-run
```

---

## Staged Rollout Strategy

EAS Update does not natively support percentage-based rollouts. Recommended workaround:

### Pattern 1: Channel Promotion
1. Publish to `preview` channel first
2. Internal testers (TestFlight / internal track) validate
3. Monitor error rate in Sentry / EAS Dashboard for 24-48h
4. Promote to `production` by pointing channel at same branch:

```bash
npx eas-cli@latest channel:edit production --branch [branch-name]
```

### Pattern 2: Feature Flags
Use feature flags (LaunchDarkly, Statsig, PostHog) to gate features within a single OTA update:

```tsx
import { useFeatureFlag } from 'posthog-react-native';

function CheckoutScreen() {
  const newCheckout = useFeatureFlag('new-checkout-flow');
  return newCheckout ? <NewCheckout /> : <LegacyCheckout />;
}
```

Publish OTA with feature disabled → gradually enable flag → instant rollback without new OTA.

### Pattern 3: Canary Users
Maintain a separate `canary` channel for power users who opt in to early updates.

```tsx
// In app settings
async function enableCanaryUpdates() {
  await AsyncStorage.setItem('update-channel', 'canary');
  // Restart app to apply channel change
  await Updates.reloadAsync();
}
```

---

## Rollback Strategy

### Identify Previous Update
```bash
# List recent updates on a branch
npx eas-cli@latest update:list --branch main

# Get details of a specific update
npx eas-cli@latest update:view [update-id]
```

### Rollback by Re-Publishing
```bash
# Rollback: point channel to previous branch state
# (EAS Update does not have a native rollback command as of 2025)
# Method: republish a known-good update

npx eas-cli@latest update --channel production --message "Rollback to v1.2.1" \
  --input-dir ./snapshots/v1.2.1-bundle
```

### Rollback via Branch Re-mapping
```bash
# Maintain a "stable" branch pointing to last known-good state
npx eas-cli@latest channel:edit production --branch stable
```

**Rule**: Never auto-rollback. Always verify manually before changing production channel. An automated rollback that fires on a false positive is worse than a temporary bad update.

---

## Monitoring Updates

### EAS Dashboard
- Update adoption rate (% of devices on each update)
- Error counts per update
- Update delivery latency

### Sentry Post-Update Monitoring
```tsx
// Tag Sentry events with current update ID
import * as Updates from 'expo-updates';
import * as Sentry from '@sentry/react-native';

const updateId = Updates.currentlyRunning.updateId;
Sentry.setTag('eas-update-id', updateId ?? 'embedded');
Sentry.setTag('eas-channel', Updates.currentlyRunning.channel ?? 'none');
```

### useUpdates() Hook
```tsx
import { useUpdates } from 'expo-updates';

function UpdateStatus() {
  const { currentlyRunning, isUpdateAvailable, isUpdatePending } = useUpdates();

  return (
    <Text>
      Running: {currentlyRunning.updateId ?? 'embedded bundle'}
      {isUpdateAvailable && ' (update ready)'}
    </Text>
  );
}
```

---

## Custom Update Check Logic

Override default check-on-load behavior:

```tsx
import * as Updates from 'expo-updates';

async function checkForUpdate() {
  try {
    const update = await Updates.checkForUpdateAsync();
    if (update.isAvailable) {
      await Updates.fetchUpdateAsync();
      // Prompt user or defer to next launch
      await Updates.reloadAsync();  // immediate apply
    }
  } catch (err) {
    console.error('Update check failed:', err);
    // Never throw — app should work without OTA connectivity
  }
}
```

---

## Critical Updates

Force an update to apply immediately on next app foreground (not deferred to next launch):

```json
{
  "expo": {
    "updates": {
      "checkAutomatically": "ON_LOAD"
    }
  }
}
```

For truly critical updates (security patch, data corruption fix):

```tsx
async function applyEmergencyUpdate() {
  const update = await Updates.checkForUpdateAsync();
  if (update.isAvailable) {
    await Updates.fetchUpdateAsync();
    // No user prompt — immediate reload
    await Updates.reloadAsync();
  }
}

// Call on app focus/foreground
useAppState({
  onChange: (state) => {
    if (state === 'active') applyEmergencyUpdate();
  }
});
```

Use sparingly — interrupting a user mid-task is a bad experience.

---

## Integration with EAS Workflows

Trigger OTA update automatically when JS-only changes merge to main:

```yaml
# .eas/workflows/ota-deploy.yml
on:
  push:
    branches: [main]

jobs:
  detect-native-changes:
    steps:
      - uses: checkout
      - name: Check for native changes
        id: native
        run: |
          CHANGED=$(git diff HEAD~1 --name-only | grep -E '^(ios|android|app\.json)' | wc -l)
          echo "native_changed=$CHANGED" >> $GITHUB_OUTPUT

  ota-update:
    needs: detect-native-changes
    if: ${{ needs.detect-native-changes.outputs.native_changed == '0' }}
    steps:
      - uses: checkout
      - uses: eas/update
        with:
          channel: production
          message: "Auto OTA from ${{ github.sha }}"
```

### GitHub Actions Equivalent
```yaml
- name: OTA Update
  if: ${{ !steps.check-native.outputs.native_changed }}
  run: |
    npx eas-cli@latest update \
      --channel production \
      --message "Deploy ${{ github.ref_name }}" \
      --non-interactive
  env:
    EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
```

---

## Runtime Version Policy

The `runtimeVersion` determines update compatibility — an OTA update only applies to builds with the same runtime version.

```json
{
  "expo": {
    "runtimeVersion": {
      "policy": "appVersion"
    }
  }
}
```

| Policy | When runtimeVersion changes | Notes |
|--------|----------------------------|-------|
| `appVersion` | When `version` in app.json changes | Most common; ties OTA to user-facing version |
| `nativeBuildVersion` | Every build | Very conservative; OTA rarely applies |
| `sdkVersion` | SDK upgrades | Good balance |
| `fingerprint` | Any native change (auto-detected) | Most precise; requires `@expo/fingerprint` |

**Fingerprint policy** (recommended for advanced setups):
```bash
npx expo install @expo/fingerprint
```
Automatically detects native dependency changes and updates runtimeVersion only when necessary.
