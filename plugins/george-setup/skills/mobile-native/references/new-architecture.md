# New Architecture

The New Architecture is enabled by default in Expo SDK 53+. It replaces the legacy bridge with a faster, synchronous communication layer between JavaScript and native code.

## Documentation

Full guide: https://docs.expo.dev/guides/new-architecture/

## What Changed

- **JSI (JavaScript Interface)** -- Direct synchronous calls between JS and native
- **Fabric** -- New rendering system with concurrent features
- **TurboModules** -- Lazy-loaded native modules with type safety

## SDK Compatibility

| SDK Version | React Native | New Architecture Status |
| ----------- | ------------ | ----------------------- |
| SDK 55      | RN 0.83 + React 19.2 | **Always enabled, cannot be disabled** |
| SDK 54      | RN 0.81 | Enabled by default, last version that supports legacy |
| SDK 53      | RN 0.79 | Enabled by default |
| SDK 52      | RN 0.76 | Opt-in via app.json |
| SDK 51-     | - | Experimental |

**IMPORTANT (2026)**: Starting with React Native 0.82, the New Architecture is always enabled and cannot be disabled. SDK 55 uses RN 0.83, inheriting this behavior. The legacy architecture was frozen in June 2025 -- no new features or bugfixes. Setting `newArchEnabled: false` has no effect on SDK 55+.

## SDK 55 Key Changes

- **Hermes v1**: Major performance improvements across scenarios
- **Hermes bytecode diffing**: Significantly smaller OTA update downloads
- **expo-brownfield**: Isolated approach to adding Expo to existing native apps
- **expo-blur RenderNode API**: Efficient background blurs on Android 12+
- **Expo Router v7**: New routing features
- **83% of SDK 54 projects** already use New Architecture (Jan 2026)

## Configuration

For SDK 54 and earlier, New Architecture is enabled by default. To explicitly disable (SDK 54 only):

```json
{
  "expo": {
    "newArchEnabled": false
  }
}
```

On SDK 55+, this setting is ignored.

## Expo Go

Expo Go only supports the New Architecture as of SDK 53. Apps using the old architecture must use development builds.

## Common Migration Issues

### Native Module Compatibility

Some older native modules may not support the New Architecture. Check:

1. Module documentation for New Architecture support
2. GitHub issues for compatibility discussions
3. Consider alternatives if module is unmaintained

### Reanimated

React Native Reanimated requires `react-native-worklets` in SDK 54+:

```bash
npx expo install react-native-worklets
```

### Layout Animations

Some layout animations behave differently. Test thoroughly after upgrading.

## Verifying New Architecture

Check if New Architecture is active:

```tsx
import { Platform } from "react-native";

// Returns true if Fabric is enabled
const isNewArch = global._IS_FABRIC !== undefined;
```

Verify from the command line if the currently running app uses the New Architecture: `bunx xcobra expo eval "_IS_FABRIC"` -> `true`

## Troubleshooting

1. **Clear caches** -- `npx expo start --clear`
2. **Clean prebuild** -- `npx expo prebuild --clean`
3. **Check native modules** -- Ensure all dependencies support New Architecture
4. **Review console warnings** -- Legacy modules log compatibility warnings
