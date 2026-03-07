---
name: expo-dev
description: Master skill for Expo and React Native mobile app development. Activate for ANY task involving mobile apps, native apps, React Native, Expo, Expo Router, Expo Go, EAS Build, EAS Submit, EAS Hosting, EAS Workflows, NativeWind, Tailwind in React Native, dev clients, TestFlight, App Store, Play Store, Google Play, App Store Connect, OTA updates, EAS Update, canary, SDK upgrades, API routes (+api.ts), iOS builds, Android builds, app deployment, app publishing, mobile CI/CD, expo-av migration, New Architecture, deprecated packages, AsyncStorage migration, expo-av, expo-symbols, vector-icons, expo.install.exclude, CORS, auth middleware, proxy API, beta release, expo@next, performance, React Compiler, Hermes, profiling, Reanimated, 60 FPS, version management, buildNumber, appVersionSource, OTA update, streaming, expo/fetch, SSE, streaming AI, WinterCG.
---

# Expo Development

Master skill for building, styling, deploying, and upgrading Expo / React Native applications with EAS (Expo Application Services).

## When to Use This Skill vs. Alternatives

- **Expo (this skill)** -- Default choice for mobile apps. Use when: targeting iOS + Android (+ web), want managed native builds, prefer file-based routing, need OTA updates.
- **React Native CLI** -- Only when: brownfield integration into existing native app, need full Xcode/Gradle control, corporate policy forbids third-party build services.
- **Flutter / other** -- Out of scope. If user asks, note Expo covers the React Native ecosystem.

## Decision Tree -- Pick the Right Reference

Read the user's task, then follow this tree:

1. **Styling with Tailwind / NativeWind / CSS?**
   --> `./references/tailwind-setup.md` (Tailwind v4 + NativeWind v5 + react-native-css wrappers)

2. **Creating server endpoints or backend logic?**
   --> `./references/api-routes.md` (+api.ts files, EAS Hosting on Cloudflare Workers)

3. **CI/CD, build automation, workflow YAML?**
   --> `./references/cicd.md` (EAS Workflows syntax, pre-packaged jobs, validation scripts)

4. **Custom dev client / native module testing?**
   --> `./references/dev-client.md` (when Expo Go is insufficient -- native modules, widgets, extensions)

5. **Deploying or publishing to stores / web?**
   --> `./references/deployment.md` (orchestrates the sub-references below)
   - TestFlight beta testing --> `./references/testflight.md`
   - iOS App Store submission --> `./references/ios-app-store.md`
   - Google Play Store --> `./references/play-store.md`
   - App Store metadata & ASO --> `./references/app-store-metadata.md`
   - Workflow-based deploys --> `./references/workflows.md`

6. **Upgrading Expo SDK or fixing breaking changes?**
   --> `./references/upgrading.md` (orchestrates the sub-references below)
   - New Architecture migration --> `./references/new-architecture.md`
   - React 19 changes --> `./references/react-19.md`
   - React Compiler setup --> `./references/react-compiler.md`
   - Native Tabs (SDK 55) --> `./references/native-tabs.md`
   - expo-av to expo-audio --> `./references/expo-av-to-audio.md`
   - expo-av to expo-video --> `./references/expo-av-to-video.md`

7. **Performance, profiling, Hermes, New Architecture perf, 60 FPS, Reanimated?**
   --> `./references/performance-profiling.md` (JSI, TurboModules, Fabric, React Compiler, FlatList, memory)

8. **App version management, buildNumber, versionCode, autoIncrement, appVersionSource?**
   --> `./references/eas-version-management.md` (remote vs local source, CI/CD versioning, semantic versioning)

9. **OTA updates, EAS Update, update channels, rollback, staged rollout, canary?**
   --> `./references/eas-update-strategy.md` (channels, branches, monitoring, critical updates, workflows)

10. **Streaming responses, expo/fetch, SSE, AI chat streaming, WinterCG?**
    --> `./references/expo-fetch-streaming.md` (ReadableStream, Claude/OpenAI streaming, SSE parsing, abort)

11. **Multiple domains?** Load all relevant references. They are designed to be composed.

## CI/CD Scripts

The CI/CD skill includes helper scripts for fetching EAS workflow schemas and validating workflow YAML files:

```bash
# Fetch EAS workflow reference docs (caches with ETags)
node {baseDir}/scripts/fetch.js <url>

# Validate workflow YAML against schema
[ -d "{baseDir}/scripts/node_modules" ] || npm install --prefix {baseDir}/scripts
node {baseDir}/scripts/validate.js <workflow.yml>
```

Key URLs for CI/CD reference:
- Schema: https://api.expo.dev/v2/workflows/schema
- Syntax docs: https://raw.githubusercontent.com/expo/expo/refs/heads/main/docs/pages/eas/workflows/syntax.mdx
- Pre-packaged jobs: https://raw.githubusercontent.com/expo/expo/refs/heads/main/docs/pages/eas/workflows/pre-packaged-jobs.mdx

## Quick Commands

```bash
# Start development
npx expo start                    # Expo Go
npx expo start --dev-client       # Custom dev client

# Build
npx eas-cli@latest build -p ios --profile production
npx eas-cli@latest build -p android --profile production

# OTA Update
npx eas-cli@latest update --channel production --message "Fix"

# Version management
npx eas-cli@latest build:version:get
npx eas-cli@latest build:version:set --platform ios

# Deploy
npx testflight                    # Quick TestFlight submission
npx eas-cli@latest deploy --prod  # Web / API route deployment

# Upgrade SDK
npx expo install expo@latest && npx expo install --fix
npx expo-doctor                   # Diagnostics

# API routes
npx expo serve                    # Local server with API routes
eas deploy                        # Deploy to EAS Hosting
```

## Rules

- ALWAYS use `npx eas-cli@latest` (not bare `eas`) to avoid stale CLI versions.
- ALWAYS run `npx expo-doctor` after SDK upgrades or dependency changes.
- Prefer Expo Go for development. Only build dev clients when native modules require it.
- Use `appVersionSource: "remote"` in eas.json so EAS manages version numbers.
- For Tailwind in React Native, wrap components with `useCssElement` -- direct className on RN primitives does not work.
- When unsure about an Expo API, use Context7 (`resolve-library-id` -> `query-docs`) rather than guessing.
- Use `expo/fetch` (not global fetch) for any streaming response or AI API integration in React Native.
- OTA updates only work for JS/asset changes -- any native code change requires a new store build.

## Cross-References

- **UI components for Expo**: See `building-native-ui` skill for native UI patterns
- **DOM components in Expo**: See `use-dom` skill for web-view based components in React Native
- **Tailwind styling details**: See `./references/tailwind-setup.md` for CSS wrappers and platform colors
