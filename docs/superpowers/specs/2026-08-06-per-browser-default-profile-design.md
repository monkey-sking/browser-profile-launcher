# Per-Browser Default Profile Design Spec

**Date**: 2026-08-06  
**Status**: Approved  
**Target Feature**: Per-Browser Default Profile (按浏览器分别指定默认配置)  

---

## 1. Feature Overview & Goal

`Browser Profile Launcher` is a macOS app designed to scan, list, manage, and launch local browser profiles for Chromium-based browsers (Chrome, Edge, Brave, Arc, Vivaldi, etc.).

This feature introduces **Per-Browser Default Profile** support. Users can nominate one profile as the default profile for each browser kind (e.g. Chrome's default is "Work", Edge's default is "Personal"). 

Key capabilities:
- Mark/unmark any profile as the default profile for its browser kind.
- Visual badge indicator (⭐ 默认) on default profiles.
- Quick launch button (⚡ 启动默认) on browser section headers in both main window and menu bar panel.
- Persistence across app launches via `UserDefaults`.
- Automatic cleanup if a default profile is deleted or missing.

---

## 2. Data Model & Storage

### 2.1 Storage Key
- `UserDefaults` Key: `"browser_profile_launcher_default_profile_ids"`
- Format: `[String: String]` mapping `BrowserKind.rawValue` -> `Profile.id`.
  - Example: `["chrome": "chrome::/Users/x/Library/Application Support/Google/Chrome::Profile 1"]`

### 2.2 Store API Changes (`BrowserProfileStore`)
Add `@Published private(set) var defaultProfileIDsByBrowser: [BrowserKind: String] = [:]`

Public methods:
1. `setDefaultProfile(_ profile: BrowserProfile)`
   - Sets `defaultProfileIDsByBrowser[profile.browser] = profile.id`.
   - Persists updated dictionary to `UserDefaults`.
   - Updates `statusMessage`: `已将 "\(profile.displayName)" 设为 \(profile.browser.displayName) 的默认配置。`

2. `unsetDefaultProfile(for browser: BrowserKind)`
   - Removes `defaultProfileIDsByBrowser[browser]`.
   - Persists updated dictionary to `UserDefaults`.
   - Updates `statusMessage`: `已取消 \(browser.displayName) 的默认配置。`

3. `isDefaultProfile(_ profile: BrowserProfile) -> Bool`
   - Returns `defaultProfileIDsByBrowser[profile.browser] == profile.id`.

4. `defaultProfile(for browser: BrowserKind) -> BrowserProfile?`
   - Finds and returns the `BrowserProfile` matching `defaultProfileIDsByBrowser[browser]` from current loaded configs/profiles.

5. `launchDefaultProfile(for browser: BrowserKind)`
   - Looks up `defaultProfile(for: browser)`. If found, calls `launchProfile(_:)`. Otherwise sets an appropriate status message.

---

## 3. UI & Interaction Design

### 3.1 Profile Row / Badge
- Next to the profile's `displayName` or `userName`, render a ⭐ badge or `Capsule` tag labeled **默认** if `isDefaultProfile(profile)` is `true`.

### 3.2 Action Menu / Context Menu
In the context menu or action buttons for a `BrowserProfile`:
- If `isDefaultProfile(profile)` is `false`:
  - Show option: **“设为 [Browser] 默认配置”** (e.g. "设为 Chrome 默认配置")
- If `isDefaultProfile(profile)` is `true`:
  - Show option: **“取消默认配置”**

### 3.3 Browser Section Header & Quick Launch
In both the Main Window list and Menu Bar popover:
- Next to each browser section header (e.g., `Chrome (3)`), if a default profile is set:
  - Show a small quick launch button: **⚡ 启动默认**
  - Clicking this button invokes `launchDefaultProfile(for: browser)`.

---

## 4. Edge Cases & Resilience

1. **Profile Deletion / Path Disappearance**:
   - During `refreshProfiles()`, validate `defaultProfileIDsByBrowser`. If the saved `profile.id` no longer resolves to a existing profile directory, leave `defaultProfileIDsByBrowser` intact or prune stale IDs, ensuring `defaultProfile(for:)` safely returns `nil` without crashing.
2. **Re-assignment**:
   - Setting a new default profile for a browser automatically overwrites the previous default selection for that browser.
3. **Empty / Search State**:
   - Default badge and quick-launch buttons maintain correct state regardless of active search queries or filters.

---

## 5. Verification Plan

- **Automated Tests**: Add unit test cases in `Tests/browser-profile-launcherTests/` covering setting, clearing, persisting, and retrieving per-browser default profile IDs.
- **Manual UI Verification**: Run `swift run` to verify badge rendering, context menu actions, and header quick launch buttons.
