# Per-Browser Default Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement per-browser default profile functionality allowing users to designate and quick-launch a default profile for each browser kind.

**Architecture:** Extend `BrowserProfileStore` with state and persistence for default profile mapping (`[BrowserKind: String]`), update `BrowserProfile` UI rows with badge badges and context menu items, and add quick launch buttons on browser section headers.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, XCTest, macOS 13+.

## Global Constraints

- Platform: macOS 13+
- Swift 6.3+ with Swift Package Manager
- Project structure: `Sources/browser-profile-launcher/browser_profile_launcher.swift` and `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

---

### Task 1: Store Data Model & Methods in BrowserProfileStore (TDD)

**Files:**
- Modify: `Sources/browser-profile-launcher/browser_profile_launcher.swift`
- Modify: `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`

**Interfaces:**
- Consumes: `BrowserProfile`, `BrowserKind`, `UserDefaults`
- Produces:
  - `BrowserProfileStore.defaultProfileIDsByBrowser: [BrowserKind: String]`
  - `BrowserProfileStore.setDefaultProfile(_ profile: BrowserProfile)`
  - `BrowserProfileStore.unsetDefaultProfile(for browser: BrowserKind)`
  - `BrowserProfileStore.isDefaultProfile(_ profile: BrowserProfile) -> Bool`
  - `BrowserProfileStore.defaultProfile(for browser: BrowserKind) -> BrowserProfile?`
  - `BrowserProfileStore.launchDefaultProfile(for browser: BrowserKind)`

- [ ] **Step 1: Write the failing unit tests for default profile store methods**

Add unit tests in `Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift`:

```swift
@Test func testPerBrowserDefaultProfileManagement() async throws {
    let suiteName = "test_default_profile_\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        XCTFail("Failed to create isolated UserDefaults")
        return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    // Test store methods setting, querying, persisting default profiles per browser
    let store = BrowserProfileStore(userDefaults: userDefaults)
    let chromeProfile = BrowserProfile(
        browser: .chrome,
        directory: "Profile 1",
        displayName: "Work Chrome",
        userName: "work@example.com",
        userDataPath: "/tmp/chrome",
        isDefault: false
    )
    let edgeProfile = BrowserProfile(
        browser: .edge,
        directory: "Default",
        displayName: "Personal Edge",
        userName: nil,
        userDataPath: "/tmp/edge",
        isDefault: true
    )

    #expect(!store.isDefaultProfile(chromeProfile))
    store.setDefaultProfile(chromeProfile)
    #expect(store.isDefaultProfile(chromeProfile))
    #expect(store.defaultProfileIDsByBrowser[.chrome] == chromeProfile.id)

    store.setDefaultProfile(edgeProfile)
    #expect(store.isDefaultProfile(edgeProfile))
    #expect(store.defaultProfileIDsByBrowser[.edge] == edgeProfile.id)

    // Verify unsetting
    store.unsetDefaultProfile(for: .chrome)
    #expect(!store.isDefaultProfile(chromeProfile))
    #expect(store.isDefaultProfile(edgeProfile))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test`
Expected: Compile failure due to missing `setDefaultProfile`, `unsetDefaultProfile`, etc.

- [ ] **Step 3: Implement store methods and persistence**

In `Sources/browser-profile-launcher/browser_profile_launcher.swift`:
1. Add storage key constant: `private let defaultProfileIDsKey = "browser_profile_launcher_default_profile_ids"`
2. Add `@Published private(set) var defaultProfileIDsByBrowser: [BrowserKind: String] = [:]`
3. Load initial dictionary in `init`:
   ```swift
   if let raw = userDefaults.dictionary(forKey: defaultProfileIDsKey) as? [String: String] {
       var loaded: [BrowserKind: String] = [:]
       for (key, val) in raw {
           if let browser = BrowserKind(rawValue: key) {
               loaded[browser] = val
           }
       }
       defaultProfileIDsByBrowser = loaded
   }
   ```
4. Add helper functions:
   ```swift
   func setDefaultProfile(_ profile: BrowserProfile) {
       defaultProfileIDsByBrowser[profile.browser] = profile.id
       saveDefaultProfileIDs()
       statusMessage = "已将“\(profile.displayName)”设为 \(profile.browser.displayName) 的默认配置。"
   }

   func unsetDefaultProfile(for browser: BrowserKind) {
       defaultProfileIDsByBrowser.removeValue(forKey: browser)
       saveDefaultProfileIDs()
       statusMessage = "已取消 \(browser.displayName) 的默认配置。"
   }

   func isDefaultProfile(_ profile: BrowserProfile) -> Bool {
       defaultProfileIDsByBrowser[profile.browser] == profile.id
   }

   func defaultProfile(for browser: BrowserKind) -> BrowserProfile? {
       guard let targetID = defaultProfileIDsByBrowser[browser] else { return nil }
       return profileByID(targetID)
   }

   func launchDefaultProfile(for browser: BrowserKind) {
       if let profile = defaultProfile(for: browser) {
           launchProfile(profile)
       } else {
           statusMessage = "未指定 \(browser.displayName) 的默认配置。"
       }
   }

   private func saveDefaultProfileIDs() {
       var raw: [String: String] = [:]
       for (browser, profileID) in defaultProfileIDsByBrowser {
           raw[browser.rawValue] = profileID
       }
       userDefaults.set(raw, forKey: defaultProfileIDsKey)
   }
   ```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/browser-profile-launcher/browser_profile_launcher.swift Tests/browser-profile-launcherTests/browser_profile_launcherTests.swift
git commit -m "feat: implement per-browser default profile store state and persistence"
```

---

### Task 2: UI Views Integration (Badge, Context Menu, & Header Quick Launch)

**Files:**
- Modify: `Sources/browser-profile-launcher/browser_profile_launcher.swift`

**Interfaces:**
- Consumes: `BrowserProfileStore` default profile API (`isDefaultProfile`, `setDefaultProfile`, `unsetDefaultProfile`, `launchDefaultProfile`)
- Produces: Updated SwiftUI components (`ProfileRowView`, `BrowserConfigSectionView`, `MenuBarView`)

- [ ] **Step 1: Add Default Badge & Context Menu to Profile Rows**

In profile row rendering (both main window and menu bar panel):
1. If `store.isDefaultProfile(profile)` is true, render a badge next to title:
   ```swift
   if store.isDefaultProfile(profile) {
       Text("⭐ 默认")
           .font(.caption2)
           .fontWeight(.bold)
           .padding(.horizontal, 5)
           .padding(.vertical, 2)
           .background(Color.yellow.opacity(0.2))
           .foregroundColor(.orange)
           .cornerRadius(4)
   }
   ```
2. In Context Menu / Actions:
   ```swift
   if store.isDefaultProfile(profile) {
       Button(action: { store.unsetDefaultProfile(for: profile.browser) }) {
           Label("取消默认配置", systemImage: "star.slash")
       }
   } else {
       Button(action: { store.setDefaultProfile(profile) }) {
           Label("设为 \(profile.browser.displayName) 默认配置", systemImage: "star.fill")
       }
   }
   ```

- [ ] **Step 2: Add Section Header Quick Launch Button**

In browser section header (Main View & Menu Bar View):
```swift
if let defaultProfile = store.defaultProfile(for: config.browser) {
    Button(action: { store.launchDefaultProfile(for: config.browser) }) {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
            Text("启动默认")
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(6)
    }
    .buttonStyle(.plain)
    .help("启动 \(config.browser.displayName) 的默认配置: \(defaultProfile.displayName)")
}
```

- [ ] **Step 3: Test build**

Run: `swift build`
Expected: Build succeeds with 0 errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/browser-profile-launcher/browser_profile_launcher.swift
git commit -m "feat: add default profile badge, context menu options, and section quick-launch button"
```

---

### Task 3: Package Dev App & Restart Running Instance

**Files:**
- Output: `dist/BrowserProfileLauncher.app`

- [ ] **Step 1: Run package script**

Run: `./scripts/package_dev_app.sh`
Expected: `dist/BrowserProfileLauncher.app` generated successfully.

- [ ] **Step 2: Replace running process**

Check running process: `pgrep -x BrowserProfileLauncher`
Kill existing process if running: `pkill -x BrowserProfileLauncher`
Launch newly built app: `open dist/BrowserProfileLauncher.app`

- [ ] **Step 3: Commit final packaging updates if any**

```bash
git add .
git commit -m "build: update packaged app with default profile feature"
```
