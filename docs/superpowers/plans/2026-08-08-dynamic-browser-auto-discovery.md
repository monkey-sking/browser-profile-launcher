# Dynamic Browser Auto-Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement dynamic browser auto-discovery on macOS to automatically detect any installed or custom Chromium-based browser (including Ego Lite, Quark, etc.) by scanning `Local State` user data directories and indexing installed `.app` bundles.

**Architecture:** Replace static `BrowserKind` enum usages with a dynamic `DynamicBrowser` struct and a `BrowserDiscoveryEngine` component. Presets are maintained as default entries while dynamic scanning auto-discovers unlisted browsers.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, XCTest, macOS 13+.

## Global Constraints

- macOS 13+
- Swift 6.3+ SPM project
- Files: `Sources/browser-profile-launcher/browser_profile_launcher.swift` and `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

---

### Task 1: Add DynamicBrowser Data Model & Presets (TDD)

**Files:**
- Modify: `Sources/browser-profile-launcher/browser_profile_launcher.swift`
- Modify: `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

**Interfaces:**
- Produces:
  - `struct DynamicBrowser: Hashable, Identifiable, Codable`
  - `enum BrowserPresets` with standard predefined browsers (Chrome, Edge, Ego Lite, Brave, Arc, Vivaldi, Opera, BrowserClaw, Chromium, Chrome Canary, Edge Canary).

- [ ] **Step 1: Write failing unit test for DynamicBrowser and BrowserPresets**

In `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`:

```swift
@Test func dynamicBrowserPresetsIncludesEgoLiteAndStandardBrowsers() async throws {
    let presets = BrowserPresets.all
    let egoLite = presets.first { $0.id == "ego-lite" }
    #expect(egoLite != nil)
    #expect(egoLite?.displayName == "Ego Lite")
    #expect(egoLite?.appPath == "/Applications/ego lite.app")
    #expect(egoLite?.userDataPath.contains("Citro Labs/ego lite") == true)
}
```

- [ ] **Step 2: Run swift test to verify it fails**

Run: `swift test` (with `BypassSandbox: true`)
Expected: Compile error due to missing `DynamicBrowser` / `BrowserPresets`.

- [ ] **Step 3: Implement DynamicBrowser and BrowserPresets**

In `Sources/browser-profile-launcher/browser_profile_launcher.swift`:

```swift
struct DynamicBrowser: Hashable, Identifiable, Codable {
    let id: String
    let displayName: String
    let appPath: String
    let userDataPath: String
    let executablePath: String
    let processMarker: String
}

enum BrowserPresets {
    static var all: [DynamicBrowser] {
        let home = NSHomeDirectory()
        return [
            DynamicBrowser(
                id: "chrome",
                displayName: "Chrome",
                appPath: "/Applications/Google Chrome.app",
                userDataPath: "\(home)/Library/Application Support/Google/Chrome",
                executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                processMarker: "Google Chrome"
            ),
            DynamicBrowser(
                id: "edge",
                displayName: "Edge",
                appPath: "/Applications/Microsoft Edge.app",
                userDataPath: "\(home)/Library/Application Support/Microsoft Edge",
                executablePath: "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
                processMarker: "Microsoft Edge"
            ),
            DynamicBrowser(
                id: "ego-lite",
                displayName: "Ego Lite",
                appPath: "/Applications/ego lite.app",
                userDataPath: "\(home)/Library/Application Support/Citro Labs/ego lite",
                executablePath: "/Applications/ego lite.app/Contents/MacOS/ego lite",
                processMarker: "ego lite"
            ),
            DynamicBrowser(
                id: "browser-claw",
                displayName: "BrowserClaw",
                appPath: "/Applications/BrowserClaw.app",
                userDataPath: "\(home)/Library/Application Support/BrowserClaw",
                executablePath: "/Applications/BrowserClaw.app/Contents/MacOS/BrowserClaw",
                processMarker: "BrowserClaw"
            ),
            DynamicBrowser(
                id: "brave",
                displayName: "Brave",
                appPath: "/Applications/Brave Browser.app",
                userDataPath: "\(home)/Library/Application Support/BraveSoftware/Brave-Browser",
                executablePath: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
                processMarker: "Brave Browser"
            ),
            DynamicBrowser(
                id: "arc",
                displayName: "Arc",
                appPath: "/Applications/Arc.app",
                userDataPath: "\(home)/Library/Application Support/Arc/User Data",
                executablePath: "/Applications/Arc.app/Contents/MacOS/Arc",
                processMarker: "Arc"
            ),
            DynamicBrowser(
                id: "vivaldi",
                displayName: "Vivaldi",
                appPath: "/Applications/Vivaldi.app",
                userDataPath: "\(home)/Library/Application Support/Vivaldi",
                executablePath: "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi",
                processMarker: "Vivaldi"
            ),
            DynamicBrowser(
                id: "chromium",
                displayName: "Chromium",
                appPath: "/Applications/Chromium.app",
                userDataPath: "\(home)/Library/Application Support/Chromium",
                executablePath: "/Applications/Chromium.app/Contents/MacOS/Chromium",
                processMarker: "Chromium"
            ),
            DynamicBrowser(
                id: "opera",
                displayName: "Opera",
                appPath: "/Applications/Opera.app",
                userDataPath: "\(home)/Library/Application Support/com.operasoftware.Opera",
                executablePath: "/Applications/Opera.app/Contents/MacOS/Opera",
                processMarker: "Opera"
            ),
            DynamicBrowser(
                id: "chrome-canary",
                displayName: "Chrome Canary",
                appPath: "/Applications/Google Chrome Canary.app",
                userDataPath: "\(home)/Library/Application Support/Google/Chrome Canary",
                executablePath: "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
                processMarker: "Google Chrome Canary"
            ),
            DynamicBrowser(
                id: "edge-canary",
                displayName: "Edge Canary",
                appPath: "/Applications/Microsoft Edge Canary.app",
                userDataPath: "\(home)/Library/Application Support/Microsoft Edge Canary",
                executablePath: "/Applications/Microsoft Edge Canary.app/Contents/MacOS/Microsoft Edge Canary",
                processMarker: "Microsoft Edge Canary"
            )
        ]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test` (with `BypassSandbox: true`)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/browser-profile-launcher/browser_profile_launcher.swift Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift
git commit -m "feat: add DynamicBrowser model and presets"
```

---

### Task 2: Implement BrowserDiscoveryEngine (TDD)

**Files:**
- Modify: `Sources/browser-profile-launcher/browser_profile_launcher.swift`
- Modify: `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

**Interfaces:**
- Produces: `BrowserDiscoveryEngine.discoverBrowsers(homeDirectory:additionalUserDataPaths:) -> [DynamicBrowser]`

- [ ] **Step 1: Write unit test for BrowserDiscoveryEngine**

In `browser_profile_launcherTests.swift`:

```swift
@Test func browserDiscoveryEngineFindsPresetAndDynamicBrowsers() async throws {
    let home = NSHomeDirectory()
    let discovered = BrowserDiscoveryEngine.discoverBrowsers(homeDirectory: home, additionalUserDataPaths: [])
    #expect(!discovered.isEmpty)
    // Should discover Chrome, Edge, Ego Lite, etc., if installed or if Local State exists
}
```

- [ ] **Step 2: Run swift test to verify it fails**

Run: `swift test` (with `BypassSandbox: true`)
Expected: Compile error due to missing `BrowserDiscoveryEngine`.

- [ ] **Step 3: Implement BrowserDiscoveryEngine**

In `browser_profile_launcher.swift`:

```swift
enum BrowserDiscoveryEngine {
    static func discoverBrowsers(
        homeDirectory: String = NSHomeDirectory(),
        additionalUserDataPaths: [String: Set<String>] = [:]
    ) -> [DynamicBrowser] {
        let fm = FileManager.default
        var results: [DynamicBrowser] = []
        var seenUserDataPaths = Set<String>()

        // 1. Presets whose Local State exists
        for preset in BrowserPresets.all {
            let localState = "\(preset.userDataPath)/Local State"
            if fm.fileExists(atPath: localState) {
                results.append(preset)
                seenUserDataPaths.insert(preset.userDataPath)
            }
        }

        // 2. Scan ~/Library/Application Support/ for unlisted Local State directories
        let appSupport = "\(homeDirectory)/Library/Application Support"
        if let subdirs = try? fm.contentsOfDirectory(atPath: appSupport) {
            for sub in subdirs {
                let path = "\(appSupport)/\(sub)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                let localStatePath = "\(path)/Local State"
                if fm.fileExists(atPath: localStatePath) && !seenUserDataPaths.contains(path) {
                    let name = sub
                    let appPath = "/Applications/\(name).app"
                    let execPath = "\(appPath)/Contents/MacOS/\(name)"
                    let dynamic = DynamicBrowser(
                        id: "dynamic-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                        displayName: name,
                        appPath: appPath,
                        userDataPath: path,
                        executablePath: execPath,
                        processMarker: name
                    )
                    results.append(dynamic)
                    seenUserDataPaths.insert(path)
                }
            }
        }

        return results
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test` (with `BypassSandbox: true`)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/browser-profile-launcher/browser_profile_launcher.swift Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift
git commit -m "feat: implement BrowserDiscoveryEngine for dynamic browser detection"
```

---

### Task 3: Refactor BrowserProfile & Store to Use DynamicBrowser & Verify UI Integration

**Files:**
- Modify: `Sources/browser-profile-launcher/browser_profile_launcher.swift`
- Modify: `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

- [ ] **Step 1: Replace BrowserKind usages with DynamicBrowser in BrowserProfile, BrowserConfig, Store, and Views**
- [ ] **Step 2: Run all tests to verify 100% pass rate**

Run: `swift test` (with `BypassSandbox: true`)
Expected: PASS with 0 failures.

- [ ] **Step 3: Commit**

```bash
git add Sources/browser-profile-launcher/browser_profile_launcher.swift Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift
git commit -m "refactor: update store and UI components to use DynamicBrowser"
```

---

### Task 4: Package App & Restart Running Instance

- [ ] **Step 1: Run package script**

Run: `./scripts/package_dev_app.sh`

- [ ] **Step 2: Restart running app**

Restart `BrowserProfileLauncher.app` to replace the running instance.
