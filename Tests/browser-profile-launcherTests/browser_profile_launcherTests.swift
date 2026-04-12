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

    let plan = BrowserLaunchPlanner.makePlan(for: profile)

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

    let plan = BrowserLaunchPlanner.makePlan(for: profile)

    #expect(plan.arguments.starts(with: [
        "-na",
        "/Applications/Microsoft Edge.app",
        "--args"
    ]))
    #expect(plan.arguments.contains("--user-data-dir=/tmp/custom-edge-root"))
    #expect(plan.arguments.contains("--profile-directory=Default"))
}
