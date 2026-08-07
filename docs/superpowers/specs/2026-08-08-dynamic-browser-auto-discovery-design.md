# Dynamic Browser Auto-Discovery Design Spec

**Date**: 2026-08-08  
**Status**: Proposal / Draft  
**Target Feature**: Dynamic Browser Auto-Discovery (动态浏览器全自动检测与适配)

---

## 1. Feature Overview & Goal

Currently, `Browser Profile Launcher` uses a hardcoded `enum BrowserKind` to recognize Chromium-based browsers. When a user installs a new browser (e.g. `Ego Lite`, `Quark`, custom Chromium distributions), the app fails to recognize it unless the developer manually adds a new enum case.

This feature replaces hardcoded browser matching with a **Dynamic Browser Auto-Discovery Engine**:
- Decouple `BrowserKind` into a dynamic data model `DynamicBrowser`.
- Maintain a list of preset standard browsers (Chrome, Edge, Brave, Arc, Vivaldi, Citro Labs / Ego Lite, Opera, BrowserClaw, Chromium, etc.) for zero-latency, high-precision matching.
- Dynamically scan `~/Library/Application Support/` and specified paths for any subdirectories containing a `Local State` file (the signature of Chromium user data roots).
- Index installed `.app` bundles in `/Applications` and `~/Applications` to dynamically associate new/unknown browser user-data directories with their parent `.app` bundles, icons, and executables.
- Support launching, deleting, listing, and per-browser default profile preferences dynamically across all discovered browsers.

---

## 2. Architecture & Data Model

### 2.1 Dynamic Browser Model (`DynamicBrowser`)

Replace or wrap static `BrowserKind` with a dynamic struct:

```swift
struct DynamicBrowser: Hashable, Identifiable, Codable {
    let id: String              // e.g. "google-chrome", "citro-labs-ego-lite", "microsoft-edge"
    let displayName: String     // e.g. "Google Chrome", "Ego Lite", "Microsoft Edge"
    let appPath: String         // e.g. "/Applications/Google Chrome.app", "/Applications/ego lite.app"
    let userDataPath: String    // e.g. "~/Library/Application Support/Citro Labs/ego lite"
    let executablePath: String  // e.g. "/Applications/ego lite.app/Contents/MacOS/ego lite"
    let processMarker: String   // e.g. "ego lite"
    let iconPath: String?       // App path for system icon lookup
}
```

### 2.2 Standard Browser Presets (`BrowserPreset`)
Define preset metadata for known browsers:
- Google Chrome: `~/Library/Application Support/Google/Chrome`, `/Applications/Google Chrome.app`
- Microsoft Edge: `~/Library/Application Support/Microsoft Edge`, `/Applications/Microsoft Edge.app`
- Citro Labs Ego Lite: `~/Library/Application Support/Citro Labs/ego lite`, `/Applications/ego lite.app`
- Brave: `~/Library/Application Support/BraveSoftware/Brave-Browser`, `/Applications/Brave Browser.app`
- Arc: `~/Library/Application Support/Arc/User Data`, `/Applications/Arc.app`
- Vivaldi: `~/Library/Application Support/Vivaldi`, `/Applications/Vivaldi.app`
- BrowserClaw: `~/Library/Application Support/BrowserClaw`, `/Applications/BrowserClaw.app`
- Opera: `~/Library/Application Support/com.operasoftware.Opera`, `/Applications/Opera.app`
- Chrome Canary: `~/Library/Application Support/Google/Chrome Canary`, `/Applications/Google Chrome Canary.app`
- Edge Canary: `~/Library/Application Support/Microsoft Edge Canary`, `/Applications/Microsoft Edge Canary.app`

---

## 3. Discovery Engine (`BrowserDiscoveryEngine`)

```swift
enum BrowserDiscoveryEngine {
    static func discoverBrowsers(
        homeDirectory: String = NSHomeDirectory(),
        additionalUserDataPaths: [String] = []
    ) -> [DynamicBrowser]
}
```

### 3.1 Algorithm
1. **Preset Evaluation**:
   - Check each `BrowserPreset`. If its `userDataPath` exists and contains a `Local State` file, instantiate a `DynamicBrowser` for it.
2. **Directory Scanning**:
   - Scan `~/Library/Application Support/` and any `additionalUserDataPaths` for non-preset directories containing a `Local State` file.
3. **App Matching for Unknown Browsers**:
   - For an unknown directory (e.g. `~/Library/Application Support/Vendor/CustomBrowser`):
     - Scan `/Applications` and `~/Applications` for matching `.app` bundles (matching directory name or bundle name).
     - If matching `.app` is found, extract `displayName`, `appPath`, and `executablePath`.
     - If no `.app` is found, fallback to directory name as `displayName` and generic browser icon.
4. **Deduplication**:
   - Deduplicate by `userDataPath` canonical path.

---

## 4. Integration into Store & UI

- `BrowserProfileStore` maintains `@Published private(set) var availableBrowsers: [DynamicBrowser] = []`.
- `refreshProfiles()` runs `BrowserDiscoveryEngine.discoverBrowsers()`, then loads profiles for each discovered browser.
- `BrowserConfig` uses `DynamicBrowser` instead of static `BrowserKind`.
- Per-browser default profiles continue to use `browser.id` for persistence in `UserDefaults`.

---

## 5. Verification Plan

- **Unit Tests**:
  - Test `BrowserDiscoveryEngine` correctly detects presets and dynamic directories with `Local State`.
  - Test matching between user data paths and `.app` bundles.
- **Manual Verification**:
  - Run `swift run` / package dev app and verify `Ego Lite` (`ego lite.app`) and standard browsers appear automatically in the UI without hardcoding.
