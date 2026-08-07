import Foundation
import Testing
@testable import browser_profile_launcher

@Test func profileSearchMatchesFields() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Profile 1",
        displayName: "工作账号",
        userName: "demo@example.com",
        userDataPath: "/tmp/chrome",
        isDefault: false
    )

    #expect(ProfileSearchMatcher.matches(profile, query: ""))
    #expect(ProfileSearchMatcher.matches(profile, query: "chrome"))
    #expect(ProfileSearchMatcher.matches(profile, query: "工作"))
    #expect(ProfileSearchMatcher.matches(profile, query: "profile 1"))
    #expect(ProfileSearchMatcher.matches(profile, query: "demo@example.com"))
    #expect(!ProfileSearchMatcher.matches(profile, query: "edge"))
}

@Test func directoryScanPlannerIncludesLibraryApplicationSupport() async throws {
    let roots = DirectoryScanPlanner.rootPaths(
        homeDirectory: "/Users/example",
        volumePaths: ["/Volumes/SSD", "/Volumes/AG1206"]
    )

    #expect(roots.contains("/Users/example/Library/Application Support"))
    #expect(roots.contains("/Volumes/SSD"))
    #expect(roots.contains("/Volumes/AG1206"))
}

@Test func profileSearchMatchesGenericNonDefaultChromeProfile() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Default",
        displayName: "工作副本",
        userName: nil,
        userDataPath: "/Users/example/Custom Chrome/User Data",
        isDefault: false
    )

    #expect(ProfileSearchMatcher.matches(profile, query: "工作"))
    #expect(ProfileSearchMatcher.matches(profile, query: "default"))
    #expect(ProfileSearchMatcher.matches(profile, query: "chrome"))
}

@Test func directoryScanPlannerKeepsProvidedVolumeRootsUnique() async throws {
    let roots = DirectoryScanPlanner.rootPaths(
        homeDirectory: "/Users/example",
        volumePaths: ["/Volumes/SSD", "/Volumes/SSD"]
    )

    #expect(roots.filter { $0 == "/Volumes/SSD" }.count == 1)
}

@Test func profileDeletePlannerDeletesWholeNonDefaultRootWhenSingleProfile() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Default",
        displayName: "副本目录",
        userName: nil,
        userDataPath: "/tmp/chrome-user-data-copy",
        isDefault: false
    )

    let target = ProfileDeletePlanner.target(
        for: profile,
        allProfiles: [profile],
        defaultUserDataPath: "/Users/example/Library/Application Support/Google/Chrome"
    )

    #expect(target == .userDataRoot("/tmp/chrome-user-data-copy"))
}

@Test func profileDeletePlannerBlocksDefaultRootDefaultProfile() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Default",
        displayName: "用户1",
        userName: nil,
        userDataPath: "/Users/example/Library/Application Support/Google/Chrome",
        isDefault: true
    )

    let target = ProfileDeletePlanner.target(
        for: profile,
        allProfiles: [profile],
        defaultUserDataPath: "/Users/example/Library/Application Support/Google/Chrome"
    )

    #expect(target == .blocked)
}

@Test func additionalUserDataPathStorageRoundTripsByBrowser() async throws {
    let encoded = AdditionalUserDataPathStorage.encode([
        .chrome: Set(["/tmp/chrome-a", "/tmp/chrome-b"]),
        .edge: Set(["/tmp/edge-a"]),
    ])

    let decoded = AdditionalUserDataPathStorage.decode(encoded)

    #expect(decoded[.chrome] == Set(["/tmp/chrome-a", "/tmp/chrome-b"]))
    #expect(decoded[.edge] == Set(["/tmp/edge-a"]))
}

@Test func browserLaunchPlannerUsesUserDataDirectoryAndProfileDirectory() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Profile 7",
        displayName: "测试账号",
        userName: "test@example.com",
        userDataPath: "/tmp/custom-chrome-root",
        isDefault: false
    )

    let action = BrowserLaunchPlanner.makeAction(for: profile, runningPID: nil)

    guard case let .launch(plan) = action else {
        Issue.record("Expected launch action")
        return
    }

    #expect(plan.executablePath == "/usr/bin/open")
    #expect(plan.arguments == [
        "-na",
        "/Applications/Google Chrome.app",
        "--args",
        "--user-data-dir=/tmp/custom-chrome-root",
        "--profile-directory=Profile 7"
    ])
}

@Test func browserLaunchPlannerUsesEdgeAppPath() async throws {
    let profile = BrowserProfile(
        browser: .edge,
        directory: "Default",
        displayName: "Edge 默认",
        userName: nil,
        userDataPath: "/tmp/custom-edge-root",
        isDefault: true
    )

    let action = BrowserLaunchPlanner.makeAction(for: profile, runningPID: nil)

    guard case let .launch(plan) = action else {
        Issue.record("Expected launch action")
        return
    }

    #expect(plan.arguments.starts(with: [
        "-na",
        "/Applications/Microsoft Edge.app",
        "--args"
    ]))
    #expect(plan.arguments.contains("--user-data-dir=/tmp/custom-edge-root"))
    #expect(plan.arguments.contains("--profile-directory=Default"))
}

@Test func browserLaunchPlannerUsesActivationForRunningProfileSwitch() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Default",
        displayName: "已运行配置",
        userName: nil,
        userDataPath: "/tmp/running-chrome-root",
        isDefault: false
    )

    let action = BrowserLaunchPlanner.makeAction(for: profile, runningPID: 49104)

    #expect(action == .activate(49104))
}

@Test func browserProcessPlannerMatchesOnlyTargetProfileProcesses() async throws {
    let profile = BrowserProfile(
        browser: .chrome,
        directory: "Profile 3",
        displayName: "工作号",
        userName: nil,
        userDataPath: "/Users/example/Profiles/Work Chrome",
        isDefault: false
    )

    let processList = """
      101 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/example/Profiles/Work Chrome --profile-directory=Profile 3
      102 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper --type=renderer --user-data-dir=/Users/example/Profiles/Work Chrome
      103 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/example/Profiles/Other Chrome --profile-directory=Profile 1
      104 /Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge --user-data-dir=/Users/example/Profiles/Work Chrome --profile-directory=Default
    """

    let matches = BrowserProcessPlanner.matches(in: processList, profile: profile)

    #expect(matches.map(\.pid) == [101, 102])
}

@Test func browserProcessPlannerIgnoresMalformedLines() async throws {
    let profile = BrowserProfile(
        browser: .edge,
        directory: "Default",
        displayName: "Edge",
        userName: nil,
        userDataPath: "/tmp/edge-root",
        isDefault: true
    )

    let processList = """
    not-a-process-line
    301 /Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge --user-data-dir=/tmp/edge-root --profile-directory=Default
    """

    let matches = BrowserProcessPlanner.matches(in: processList, profile: profile)

    #expect(matches.map(\.pid) == [301])
}

@Test func browserProfileRuntimePlannerParsesPIDFromSingletonLockDestination() async throws {
    #expect(BrowserProfileRuntimePlanner.singletonLockPID(from: "Macmini.local-49104") == 49104)
    #expect(BrowserProfileRuntimePlanner.singletonLockPID(from: "host-name-12345") == 12345)
    #expect(BrowserProfileRuntimePlanner.singletonLockPID(from: "not-a-pid") == nil)
}

@Test func browserClosePlannerPrioritizesPrimaryPIDAndDeduplicates() async throws {
    let matches = [
        BrowserProcessMatch(pid: 49104, command: "main"),
        BrowserProcessMatch(pid: 49118, command: "helper1"),
        BrowserProcessMatch(pid: 49104, command: "duplicate"),
        BrowserProcessMatch(pid: 49129, command: "helper2"),
    ]

    let plan = BrowserClosePlanner.makePlan(primaryPID: 49104, matchedProcesses: matches)

    #expect(plan.pids == [49104, 49118, 49129])
}

@Test func menuProfilePlannerKeepsEachProfileOnceWithRecentFirst() async throws {
    let recent = BrowserProfile(
        browser: .chrome,
        directory: "Profile 1",
        displayName: "最近账号",
        userName: nil,
        userDataPath: "/tmp/chrome-root",
        isDefault: false
    )
    let other = BrowserProfile(
        browser: .chrome,
        directory: "Profile 2",
        displayName: "其他账号",
        userName: nil,
        userDataPath: "/tmp/chrome-root",
        isDefault: false
    )

    let profiles = MenuProfileMenuPlanner.orderedProfiles(
        recentProfiles: [recent],
        allProfiles: [other, recent, other]
    )

    #expect(profiles.map(\.id) == [recent.id, other.id])
}

@Test func menuProfilePlannerShowsOpenOnlyWhenProfileIsNotRunning() async throws {
    #expect(MenuProfileMenuPlanner.actions(isRunning: false) == [.open])
}

@Test func menuProfilePlannerShowsSwitchAndCloseWhenProfileIsRunning() async throws {
    #expect(MenuProfileMenuPlanner.actions(isRunning: true) == [.switchTo, .close])
}

@Test func menuBarPanelLayoutPlannerUsesContentHeightForSmallLists() async throws {
    let height = MenuBarPanelLayoutPlanner.listHeight(for: 2)
    #expect(height == 112)
}

@Test func menuBarPanelLayoutPlannerClampsLargeListsToMaximumHeight() async throws {
    let height = MenuBarPanelLayoutPlanner.listHeight(for: 20)
    #expect(height == 440)
}

@Test func launchAtLoginPlannerMapsRequiresApprovalState() async throws {
    #expect(LaunchAtLoginPlanner.state(for: .requiresApproval) == .requiresApproval)
}

@MainActor
@Test func browserProfileStoreRegistersMainAppForLaunchAtLogin() async throws {
    let controller = MockLaunchAtLoginController(status: .disabled)
    let store = BrowserProfileStore(launchAtLoginController: controller)

    store.setLaunchAtLoginEnabled(true)

    #expect(controller.registerCallCount == 1)
    #expect(controller.unregisterCallCount == 0)
}

@MainActor
@Test func browserProfileStoreUnregistersMainAppForLaunchAtLogin() async throws {
    let controller = MockLaunchAtLoginController(status: .enabled)
    let store = BrowserProfileStore(launchAtLoginController: controller)

    store.setLaunchAtLoginEnabled(false)

    #expect(controller.registerCallCount == 0)
    #expect(controller.unregisterCallCount == 1)
}

@Test func browserLaunchPlannerUsesBrowserClawAppPath() async throws {
    let profile = BrowserProfile(
        browser: .browserClaw,
        directory: "Default",
        displayName: "BrowserClaw 默认",
        userName: nil,
        userDataPath: "/tmp/custom-browserclaw-root",
        isDefault: true
    )

    let action = BrowserLaunchPlanner.makeAction(for: profile, runningPID: nil)

    guard case let .launch(plan) = action else {
        Issue.record("Expected launch action")
        return
    }

    #expect(plan.arguments.starts(with: [
        "-na",
        "/Applications/BrowserClaw.app",
        "--args"
    ]))
    #expect(plan.arguments.contains("--user-data-dir=/tmp/custom-browserclaw-root"))
    #expect(plan.arguments.contains("--profile-directory=Default"))
}

private final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginServiceStatus
    var registerCallCount = 0
    var unregisterCallCount = 0

    init(status: LaunchAtLoginServiceStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .disabled
    }
}

@MainActor
@Test func testPerBrowserDefaultProfileManagement() async throws {
    let suiteName = "test_default_profile_\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Failed to create isolated UserDefaults")
        return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

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

    store.unsetDefaultProfile(for: .chrome)
    #expect(!store.isDefaultProfile(chromeProfile))
    #expect(store.isDefaultProfile(edgeProfile))
}

@Test func localStateModifierUpdatesLastUsedAndRemovesFromInfoCache() async throws {
    var localState: [String: Any] = [
        "profile": [
            "info_cache": [
                "Profile 1": ["name": "User 1"],
                "Profile 4": ["name": "User 4"]
            ],
            "last_used": "Profile 4"
        ]
    ]

    LocalStateModifier.setLastUsedProfile(directory: "Profile 1", in: &localState)
    let profileDict = localState["profile"] as? [String: Any]
    #expect(profileDict?["last_used"] as? String == "Profile 1")

    LocalStateModifier.removeProfileFromInfoCache(directory: "Profile 1", in: &localState)
    let updatedProfileDict = localState["profile"] as? [String: Any]
    let updatedInfoCache = updatedProfileDict?["info_cache"] as? [String: Any]
    #expect(updatedInfoCache?["Profile 1"] == nil)
    #expect(updatedInfoCache?["Profile 4"] != nil)
    #expect(updatedProfileDict?["last_used"] as? String == "Default")
}

@Test func dynamicBrowserPresetsIncludesEgoLiteAndStandardBrowsers() async throws {
    let presets = BrowserPresets.all
    let egoLite = presets.first { $0.id == "ego-lite" }
    #expect(egoLite != nil)
    #expect(egoLite?.displayName == "Ego Lite")
    #expect(egoLite?.appPath == "/Applications/ego lite.app")
    #expect(egoLite?.userDataPath.contains("Citro Labs/ego lite") == true)
}

@Test func browserDiscoveryEngineFindsPresetAndDynamicBrowsers() async throws {
    let home = NSHomeDirectory()
    let discovered = BrowserDiscoveryEngine.discoverBrowsers(homeDirectory: home)
    #expect(!discovered.isEmpty)
}




