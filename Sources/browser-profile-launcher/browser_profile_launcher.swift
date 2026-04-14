import AppKit
import Darwin
import Foundation
import SwiftUI

enum BrowserKind: String, CaseIterable, Identifiable {
    case chrome
    case edge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome:
            return "Chrome"
        case .edge:
            return "Edge"
        }
    }

    var appPath: String {
        switch self {
        case .chrome:
            return "/Applications/Google Chrome.app"
        case .edge:
            return "/Applications/Microsoft Edge.app"
        }
    }

    var executablePath: String {
        switch self {
        case .chrome:
            return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        case .edge:
            return "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
        }
    }

    var userDataPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .chrome:
            return "\(home)/Library/Application Support/Google/Chrome"
        case .edge:
            return "\(home)/Library/Application Support/Microsoft Edge"
        }
    }

    var localStatePath: String {
        "\(userDataPath)/Local State"
    }
}

struct BrowserProfile: Hashable, Identifiable {
    let browser: BrowserKind
    let directory: String
    let displayName: String
    let userName: String?
    let userDataPath: String
    let isDefault: Bool

    var id: String {
        "\(browser.rawValue)::\(userDataPath)::\(directory)"
    }

    var label: String {
        if let userName, !userName.isEmpty {
            return "\(displayName) (\(userName))"
        }
        return displayName
    }
}

struct BrowserConfig: Hashable, Identifiable {
    let browser: BrowserKind
    let profiles: [BrowserProfile]

    var id: String { browser.rawValue }
}

struct BrowserLaunchPlan: Equatable {
    let executablePath: String
    let arguments: [String]
}

enum BrowserLaunchAction: Equatable {
    case activate(Int32)
    case launch(BrowserLaunchPlan)
}

struct BrowserProcessMatch: Equatable, Identifiable {
    let pid: Int32
    let command: String

    var id: Int32 { pid }
}

struct BrowserClosePlan: Equatable {
    let pids: [Int32]
}

enum ProfileDeleteTarget: Equatable {
    case userDataRoot(String)
    case profileDirectory(String)
    case blocked
}

enum BrowserLaunchPlanner {
    static func makeAction(for profile: BrowserProfile, runningPID: Int32?) -> BrowserLaunchAction {
        if let runningPID {
            return .activate(runningPID)
        }

        return .launch(
            BrowserLaunchPlan(
                executablePath: "/usr/bin/open",
                arguments: [
                    "-na",
                    profile.browser.appPath,
                    "--args",
                    "--user-data-dir=\(profile.userDataPath)",
                    "--profile-directory=\(profile.directory)"
                ]
            )
        )
    }
}

enum BrowserClosePlanner {
    static func makePlan(primaryPID: Int32?, matchedProcesses: [BrowserProcessMatch]) -> BrowserClosePlan {
        var ordered: [Int32] = []

        if let primaryPID {
            ordered.append(primaryPID)
        }

        for pid in matchedProcesses.map(\.pid) where !ordered.contains(pid) {
            ordered.append(pid)
        }

        return BrowserClosePlan(pids: ordered)
    }
}

enum BrowserProcessPlanner {
    static func matches(in processListOutput: String, profile: BrowserProfile) -> [BrowserProcessMatch] {
        let userDataArgument = "--user-data-dir=\(profile.userDataPath)"
        let browserMarker = profile.browser == .chrome ? "Google Chrome" : "Microsoft Edge"

        return processListOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }

                let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard parts.count == 2, let pid = Int32(parts[0]) else {
                    return nil
                }

                let command = String(parts[1])
                guard command.contains(userDataArgument) else {
                    return nil
                }
                guard command.contains(browserMarker) || command.contains(profile.browser.executablePath) else {
                    return nil
                }

                return BrowserProcessMatch(pid: pid, command: command)
            }
    }
}

enum BrowserProfileRuntimePlanner {
    static func singletonLockPID(from symbolicLinkDestination: String) -> Int32? {
        let value = symbolicLinkDestination.split(separator: "-").last.map(String.init) ?? symbolicLinkDestination
        return Int32(value)
    }
}

enum ProfileSearchMatcher {
    static func matches(_ profile: BrowserProfile, query: String) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return true
        }

        let searchable = [
            profile.browser.displayName,
            profile.displayName,
            profile.directory,
            profile.userName ?? ""
        ].joined(separator: " ")

        return searchable.localizedCaseInsensitiveContains(text)
    }
}

enum DirectoryScanPlanner {
    static let skipDirectoryNames: Set<String> = [
        ".git", "node_modules", ".build", ".swiftpm", "DerivedData", "Pods"
    ]

    static func rootPaths(homeDirectory: String, volumePaths: [String]) -> [String] {
        let roots = ["\(homeDirectory)/Library/Application Support"] + volumePaths
        return Array(Set(roots)).sorted()
    }
}

enum AdditionalUserDataPathStorage {
    static func decode(_ raw: [String: [String]]) -> [BrowserKind: Set<String>] {
        var result: [BrowserKind: Set<String>] = [:]
        for (key, paths) in raw {
            guard let browser = BrowserKind(rawValue: key) else {
                continue
            }
            result[browser] = Set(paths)
        }
        return result
    }

    static func encode(_ value: [BrowserKind: Set<String>]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (browser, paths) in value {
            result[browser.rawValue] = Array(paths).sorted()
        }
        return result
    }
}

enum ProfileDeletePlanner {
    static func target(
        for profile: BrowserProfile,
        allProfiles: [BrowserProfile],
        defaultUserDataPath: String
    ) -> ProfileDeleteTarget {
        let sameRootProfiles = allProfiles.filter { $0.browser == profile.browser && $0.userDataPath == profile.userDataPath }
        let isDefaultRoot = profile.userDataPath == defaultUserDataPath

        if !isDefaultRoot && sameRootProfiles.count <= 1 {
            return .userDataRoot(profile.userDataPath)
        }

        if profile.directory == "Default" && isDefaultRoot {
            return .blocked
        }

        let profilePath = URL(fileURLWithPath: profile.userDataPath).appendingPathComponent(profile.directory).path
        return .profileDirectory(profilePath)
    }
}

@MainActor
final class BrowserProfileStore: ObservableObject {
    @Published private(set) var configs: [BrowserConfig] = []
    @Published var searchQuery: String = ""
    @Published private(set) var recentProfileIDs: [String] = []
    @Published private(set) var runningProfileIDs = Set<String>()
    @Published private(set) var isScanningNonDefaultDirectories: Bool = false
    @Published var pendingDeleteProfile: BrowserProfile?
    @Published var statusMessage: String = "点击“刷新配置”读取本机浏览器 Profile。"

    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let recentProfilesKey = "browser_profile_launcher_recent_profile_ids"
    private let additionalUserDataPathsKey = "browser_profile_launcher_additional_user_data_paths"
    private let maxRecentProfiles = 20
    private var additionalUserDataPaths: [BrowserKind: Set<String>] = [:]

    init() {
        recentProfileIDs = userDefaults.stringArray(forKey: recentProfilesKey) ?? []
        if let raw = userDefaults.dictionary(forKey: additionalUserDataPathsKey) as? [String: [String]] {
            additionalUserDataPaths = AdditionalUserDataPathStorage.decode(raw)
        }
    }

    var recentProfiles: [BrowserProfile] {
        recentProfileIDs
            .compactMap(profileByID)
            .filter { ProfileSearchMatcher.matches($0, query: searchQuery) }
    }

    var hasVisibleProfiles: Bool {
        if !recentProfiles.isEmpty {
            return true
        }
        return configs.contains { !sectionProfiles(for: $0).isEmpty }
    }

    func refreshProfiles() {
        let loadedConfigs = rebuildConfigs()

        guard !loadedConfigs.isEmpty else {
            statusMessage = "未检测到可用的 Chrome / Edge 配置。"
            runningProfileIDs = []
            return
        }

        refreshRunningProfiles()
        let summary = loadedConfigs
            .map { "\($0.browser.displayName): \($0.profiles.count) 个" }
            .joined(separator: "，")
        statusMessage = "已读取配置 -> \(summary)"
    }

    func parseProfiles(from directoryPath: String, browser: BrowserKind) {
        let trimmed = directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = NSString(string: trimmed).expandingTildeInPath
        guard !expanded.isEmpty else {
            statusMessage = "请先输入配置目录路径。"
            return
        }

        guard let canonicalPath = validatedUserDataPath(expanded) else {
            statusMessage = "目录不存在或不包含 Local State：\(expanded)"
            return
        }

        guard loadProfiles(for: browser, userDataPath: canonicalPath) != nil else {
            statusMessage = "解析失败：\(browser.displayName) 配置格式不正确。"
            return
        }

        var existing = additionalUserDataPaths[browser, default: Set<String>()]
        existing.insert(canonicalPath)
        additionalUserDataPaths[browser] = existing
        persistAdditionalUserDataPaths()

        _ = rebuildConfigs()
        let count = configs.first(where: { $0.browser == browser })?.profiles.count ?? 0
        statusMessage = "已加入 \(browser.displayName) 目录：\(canonicalPath)（当前 \(count) 个配置）"
    }

    func scanNonDefaultDirectories() {
        guard !isScanningNonDefaultDirectories else {
            return
        }
        isScanningNonDefaultDirectories = true
        statusMessage = "正在扫描非默认目录，请稍候..."

        let discovered = discoverNonDefaultUserDataDirectories()
        var addedByBrowser: [BrowserKind: Int] = [.chrome: 0, .edge: 0]

        for (browser, paths) in discovered {
            var existing = additionalUserDataPaths[browser, default: Set<String>()]
            for path in paths {
                if !existing.contains(path) {
                    existing.insert(path)
                    addedByBrowser[browser, default: 0] += 1
                }
            }
            additionalUserDataPaths[browser] = existing
        }
        persistAdditionalUserDataPaths()

        _ = rebuildConfigs()
        isScanningNonDefaultDirectories = false

        let addedTotal = addedByBrowser.values.reduce(0, +)
        if addedTotal == 0 {
            statusMessage = "扫描完成：未发现新的非默认目录。"
            return
        }

        let detail = BrowserKind.allCases
            .map { "\($0.displayName)+\(addedByBrowser[$0, default: 0])" }
            .joined(separator: "，")
        statusMessage = "扫描完成：新增 \(addedTotal) 个目录（\(detail)）"
    }

    func launch(profile: BrowserProfile) {
        guard fileManager.fileExists(atPath: profile.browser.appPath) else {
            statusMessage = "未找到浏览器应用：\(profile.browser.appPath)"
            return
        }

        let runningPID = singletonLockPID(for: profile)
        let action = BrowserLaunchPlanner.makeAction(for: profile, runningPID: runningPID)

        switch action {
        case let .activate(pid):
            guard let app = NSRunningApplication(processIdentifier: pid) else {
                statusMessage = "切换失败：找不到运行中的浏览器进程。"
                return
            }

            let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            if activated {
                pushRecentProfile(id: profile.id)
                statusMessage = "已切换到 \(profile.browser.displayName) - \(profile.label)"
            } else {
                statusMessage = "切换失败：无法激活对应窗口。"
            }

        case let .launch(launchPlan):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPlan.executablePath)
            process.arguments = launchPlan.arguments

            do {
                try process.run()
                pushRecentProfile(id: profile.id)
                statusMessage = "已启动 \(profile.browser.displayName) - \(profile.label)"
                scheduleRunningProfilesRefresh()
            } catch {
                statusMessage = "启动失败：\(error.localizedDescription)"
            }
        }
    }

    func close(profile: BrowserProfile) {
        let primaryPID = singletonLockPID(for: profile)
        let matches = runningProcesses(for: profile)
        let closePlan = BrowserClosePlanner.makePlan(primaryPID: primaryPID, matchedProcesses: matches)

        guard !closePlan.pids.isEmpty else {
            statusMessage = "没有发现 \(profile.displayName) 的运行中进程。"
            return
        }

        var terminatedCount = 0
        for pid in closePlan.pids {
            if Darwin.kill(pid, SIGTERM) == 0 {
                terminatedCount += 1
            }
        }

        if terminatedCount > 0 {
            statusMessage = "已关闭 \(profile.displayName) 的 \(terminatedCount) 个进程。"
            scheduleRunningProfilesRefresh()
        } else {
            statusMessage = "关闭失败：没有可终止的进程。"
        }
    }

    func requestDelete(profile: BrowserProfile) {
        pendingDeleteProfile = profile
    }

    func cancelDelete() {
        pendingDeleteProfile = nil
    }

    func confirmDelete() {
        guard let profile = pendingDeleteProfile else {
            return
        }
        pendingDeleteProfile = nil

        let defaultUserDataPath = canonicalizePath(profile.browser.userDataPath)
        let allProfiles = configs.flatMap(\.profiles)
        let deleteTarget = ProfileDeletePlanner.target(
            for: profile,
            allProfiles: allProfiles,
            defaultUserDataPath: defaultUserDataPath
        )

        let targetPath: String
        switch deleteTarget {
        case let .userDataRoot(path):
            targetPath = path
        case let .profileDirectory(path):
            targetPath = path
        case .blocked:
            statusMessage = "默认浏览器根配置不能直接删除。"
            return
        }

        guard fileManager.fileExists(atPath: targetPath) else {
            statusMessage = "删除失败，目标不存在：\(targetPath)"
            return
        }

        do {
            var trashedURL: NSURL?
            try fileManager.trashItem(
                at: URL(fileURLWithPath: targetPath),
                resultingItemURL: &trashedURL
            )

            removeAdditionalUserDataPathIfNeeded(profile: profile, deleteTarget: deleteTarget)
            _ = rebuildConfigs()
            statusMessage = "已移到废纸篓：\(profile.displayName)"
        } catch {
            statusMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func isDefaultProfile(_ profile: BrowserProfile) -> Bool {
        profile.isDefault
    }

    func isRecentProfile(_ profile: BrowserProfile) -> Bool {
        recentProfileIDs.contains(profile.id)
    }

    func sectionProfiles(for config: BrowserConfig) -> [BrowserProfile] {
        let filtered = config.profiles.filter { ProfileSearchMatcher.matches($0, query: searchQuery) }
        return filtered.filter { !recentProfileIDs.contains($0.id) }
    }

    func isNonDefaultProfile(_ profile: BrowserProfile) -> Bool {
        !profile.isDefault
    }

    func canDelete(_ profile: BrowserProfile) -> Bool {
        let defaultUserDataPath = canonicalizePath(profile.browser.userDataPath)
        let target = ProfileDeletePlanner.target(
            for: profile,
            allProfiles: configs.flatMap(\.profiles),
            defaultUserDataPath: defaultUserDataPath
        )
        return target != .blocked
    }

    func deleteDescription(for profile: BrowserProfile) -> String {
        let defaultUserDataPath = canonicalizePath(profile.browser.userDataPath)
        let target = ProfileDeletePlanner.target(
            for: profile,
            allProfiles: configs.flatMap(\.profiles),
            defaultUserDataPath: defaultUserDataPath
        )

        switch target {
        case .userDataRoot:
            return "会把整套配置目录移到废纸篓。"
        case .profileDirectory:
            return "会把这个配置子目录移到废纸篓。"
        case .blocked:
            return "默认浏览器根配置不能直接删除。"
        }
    }

    func allVisibleProfiles() -> [BrowserProfile] {
        var result: [BrowserProfile] = []
        var seenIDs = Set<String>()

        for profile in recentProfiles {
            if seenIDs.insert(profile.id).inserted {
                result.append(profile)
            }
        }

        for config in configs {
            for profile in sectionProfiles(for: config) {
                if seenIDs.insert(profile.id).inserted {
                    result.append(profile)
                }
            }
        }

        return result
    }

    func menuProfiles() -> [BrowserProfile] {
        var result: [BrowserProfile] = []
        var seenIDs = Set<String>()

        for profile in recentProfilesForMenu() {
            if seenIDs.insert(profile.id).inserted {
                result.append(profile)
            }
        }

        for profile in configs.flatMap(\.profiles) {
            if seenIDs.insert(profile.id).inserted {
                result.append(profile)
            }
        }

        return result
    }

    func recentProfilesForMenu() -> [BrowserProfile] {
        recentProfileIDs.compactMap(profileByID)
    }

    func profilesExcludingRecentForMenu() -> [BrowserProfile] {
        let recentIDs = Set(recentProfilesForMenu().map(\.id))
        return configs.flatMap(\.profiles).filter { !recentIDs.contains($0.id) }
    }

    func runningProfilesForMenu() -> [BrowserProfile] {
        menuProfiles().filter { runningProfileIDs.contains($0.id) }
    }

    func isRunning(_ profile: BrowserProfile) -> Bool {
        runningProfileIDs.contains(profile.id)
    }

    func groupedProfiles() -> [(browser: BrowserKind, profiles: [BrowserProfile])] {
        BrowserKind.allCases.compactMap { browser in
            guard let config = configs.first(where: { $0.browser == browser }) else {
                return nil
            }

            let profiles = sectionProfiles(for: config)
            guard !profiles.isEmpty else {
                return nil
            }

            return (browser, profiles)
        }
    }

    private func rebuildConfigs() -> [BrowserConfig] {
        pruneAdditionalUserDataPaths()
        var loadedConfigs: [BrowserConfig] = []

        for browser in BrowserKind.allCases {
            guard fileManager.fileExists(atPath: browser.appPath) else {
                continue
            }

            var mergedProfiles: [BrowserProfile] = []
            var seenIDs = Set<String>()
            var pathsToLoad: [String] = [canonicalizePath(browser.userDataPath)]
            pathsToLoad.append(contentsOf: additionalUserDataPaths[browser, default: []].map { canonicalizePath($0) })
            pathsToLoad = Array(Set(pathsToLoad)).sorted()

            for path in pathsToLoad {
                guard let profiles = loadProfiles(for: browser, userDataPath: path) else {
                    continue
                }

                for profile in profiles {
                    if !seenIDs.contains(profile.id) {
                        seenIDs.insert(profile.id)
                        mergedProfiles.append(profile)
                    }
                }
            }

            if !mergedProfiles.isEmpty {
                loadedConfigs.append(BrowserConfig(browser: browser, profiles: mergedProfiles))
            }
        }

        loadedConfigs.sort { $0.browser.rawValue < $1.browser.rawValue }
        configs = loadedConfigs
        pruneRecentProfiles()
        return loadedConfigs
    }

    private func runningProcesses(for profile: BrowserProfile) -> [BrowserProcessMatch] {
        guard let output = processListOutput() else {
            return []
        }
        return BrowserProcessPlanner.matches(in: output, profile: profile)
    }

    private func loadProfiles(for browser: BrowserKind, userDataPath: String) -> [BrowserProfile]? {
        let canonicalPath = canonicalizePath(userDataPath)
        let localStatePath = "\(canonicalPath)/Local State"
        guard let root = readJSON(path: localStatePath),
              let profile = root["profile"] as? [String: Any] else {
            return nil
        }

        let lastUsed = profile["last_used"] as? String
        let defaultPath = canonicalizePath(browser.userDataPath)
        let isDefaultPath = canonicalPath == defaultPath

        var profiles: [BrowserProfile] = []
        if let infoCache = profile["info_cache"] as? [String: Any] {
            for (directory, value) in infoCache {
                guard let item = value as? [String: Any] else {
                    continue
                }
                let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = (name?.isEmpty == false) ? name! : directory
                let userName = item["user_name"] as? String
                let isDefaultProfile = isDefaultPath && lastUsed == directory
                profiles.append(
                    BrowserProfile(
                        browser: browser,
                        directory: directory,
                        displayName: displayName,
                        userName: userName,
                        userDataPath: canonicalPath,
                        isDefault: isDefaultProfile
                    )
                )
            }
        }

        profiles.sort { lhs, rhs in
            profileSortKey(lhs.directory) < profileSortKey(rhs.directory)
        }
        return profiles
    }

    func refreshRunningProfiles() {
        let profiles = configs.flatMap(\.profiles)
        runningProfileIDs = Set(
            profiles
                .filter(isProfileRunning)
                .map(\.id)
        )
    }

    private func scheduleRunningProfilesRefresh() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            refreshRunningProfiles()
        }
    }

    private func processListOutput() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            return output
        } catch {
            statusMessage = "读取进程列表失败：\(error.localizedDescription)"
            return nil
        }
    }

    private func isProfileRunning(_ profile: BrowserProfile) -> Bool {
        if singletonLockPID(for: profile) != nil {
            return true
        }

        if hasActiveSingletonSocket(in: profile.userDataPath) {
            return true
        }

        guard let output = processListOutput() else {
            return false
        }
        return !BrowserProcessPlanner.matches(in: output, profile: profile).isEmpty
    }

    private func hasActiveSingletonLock(in userDataPath: String) -> Bool {
        singletonLockPID(at: userDataPath) != nil
    }

    private func singletonLockPID(for profile: BrowserProfile) -> Int32? {
        singletonLockPID(at: profile.userDataPath)
    }

    private func singletonLockPID(at userDataPath: String) -> Int32? {
        let lockPath = URL(fileURLWithPath: userDataPath).appendingPathComponent("SingletonLock").path
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: lockPath),
              let pid = BrowserProfileRuntimePlanner.singletonLockPID(from: destination),
              processExists(pid: pid) else {
            return nil
        }
        return pid
    }

    private func hasActiveSingletonSocket(in userDataPath: String) -> Bool {
        let socketURL = URL(fileURLWithPath: userDataPath).appendingPathComponent("SingletonSocket")
        let resolved = socketURL.resolvingSymlinksInPath().path
        return fileManager.fileExists(atPath: resolved)
    }

    private func processExists(pid: Int32) -> Bool {
        if Darwin.kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    private func readJSON(path: String) -> [String: Any]? {
        guard let data = fileManager.contents(atPath: path) else {
            return nil
        }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private func profileSortKey(_ directory: String) -> (Int, Int, String) {
        if directory == "Default" {
            return (0, 0, directory)
        }
        if let number = profileNumber(in: directory) {
            return (1, number, directory)
        }
        if directory == "Guest Profile" {
            return (2, 0, directory)
        }
        if directory == "System Profile" {
            return (3, 0, directory)
        }
        return (4, 0, directory)
    }

    private func profileNumber(in directory: String) -> Int? {
        guard directory.hasPrefix("Profile ") else {
            return nil
        }
        let value = directory.replacingOccurrences(of: "Profile ", with: "")
        return Int(value)
    }

    private func profileByID(_ id: String) -> BrowserProfile? {
        for config in configs {
            if let profile = config.profiles.first(where: { $0.id == id }) {
                return profile
            }
        }
        return nil
    }

    private func pushRecentProfile(id: String) {
        var updated = recentProfileIDs.filter { $0 != id }
        updated.insert(id, at: 0)
        if updated.count > maxRecentProfiles {
            updated = Array(updated.prefix(maxRecentProfiles))
        }
        recentProfileIDs = updated
        userDefaults.set(updated, forKey: recentProfilesKey)
    }

    private func pruneRecentProfiles() {
        let allIDs = Set(configs.flatMap { $0.profiles.map(\.id) })
        let pruned = recentProfileIDs.filter { allIDs.contains($0) }
        if pruned != recentProfileIDs {
            recentProfileIDs = pruned
            userDefaults.set(pruned, forKey: recentProfilesKey)
        }
    }

    private func removeAdditionalUserDataPathIfNeeded(profile: BrowserProfile, deleteTarget: ProfileDeleteTarget) {
        switch deleteTarget {
        case .userDataRoot:
            additionalUserDataPaths[profile.browser]?.remove(profile.userDataPath)
            persistAdditionalUserDataPaths()
        case .profileDirectory, .blocked:
            break
        }
    }

    private func pruneAdditionalUserDataPaths() {
        var changed = false
        for browser in BrowserKind.allCases {
            let current = additionalUserDataPaths[browser, default: Set<String>()]
            let pruned = Set(current.compactMap { validatedUserDataPath($0) })
            if pruned != current {
                additionalUserDataPaths[browser] = pruned
                changed = true
            }
        }
        if changed {
            persistAdditionalUserDataPaths()
        }
    }

    private func persistAdditionalUserDataPaths() {
        let raw = AdditionalUserDataPathStorage.encode(additionalUserDataPaths)
        userDefaults.set(raw, forKey: additionalUserDataPathsKey)
    }

    private func validatedUserDataPath(_ rawPath: String) -> String? {
        let canonicalPath = canonicalizePath(rawPath)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: canonicalPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        guard fileManager.fileExists(atPath: "\(canonicalPath)/Local State") else {
            return nil
        }
        return canonicalPath
    }

    private func canonicalizePath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func discoverNonDefaultUserDataDirectories() -> [BrowserKind: Set<String>] {
        var discovered: [BrowserKind: Set<String>] = [.chrome: Set<String>(), .edge: Set<String>()]
        let rootPaths = DirectoryScanPlanner.rootPaths(
            homeDirectory: NSHomeDirectory(),
            volumePaths: discoverVolumeRootPaths()
        )
        let defaultPaths = Dictionary(uniqueKeysWithValues: BrowserKind.allCases.map { ($0, canonicalizePath($0.userDataPath)) })

        for rootPath in rootPaths {
            let canonicalRoot = canonicalizePath(rootPath)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: canonicalRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let rootURL = URL(fileURLWithPath: canonicalRoot)
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }

            let rootDepth = rootURL.pathComponents.count

            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
                let name = values?.name ?? fileURL.lastPathComponent
                let isDir = values?.isDirectory ?? false

                if isDir {
                    let depth = fileURL.pathComponents.count - rootDepth
                    if depth > 8 || DirectoryScanPlanner.skipDirectoryNames.contains(name) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard name == "Local State" else {
                    continue
                }

                let userDataPath = canonicalizePath(fileURL.deletingLastPathComponent().path)
                guard let browser = inferBrowser(for: userDataPath) else {
                    continue
                }
                guard userDataPath != defaultPaths[browser] else {
                    continue
                }
                discovered[browser, default: Set<String>()].insert(userDataPath)
            }
        }

        return discovered
    }

    private func discoverVolumeRootPaths() -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: "/Volumes") else {
            return []
        }

        var results: [String] = []
        for entry in entries {
            let path = "/Volumes/\(entry)"
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            if let attributes = try? fileManager.attributesOfItem(atPath: path),
               let type = attributes[.type] as? FileAttributeType,
               type == .typeSymbolicLink {
                continue
            }
            results.append(canonicalizePath(path))
        }
        return results
    }

    private func inferBrowser(for userDataPath: String) -> BrowserKind? {
        let lowerPath = userDataPath.lowercased()
        guard let root = readJSON(path: "\(userDataPath)/Local State") else {
            return nil
        }

        if root["edge"] != nil || root["edge_operation_config"] != nil || lowerPath.contains("microsoft edge") {
            return .edge
        }
        if lowerPath.contains("chrome")
            || lowerPath.contains("google/chrome")
            || root["profile"] != nil
        {
            return .chrome
        }
        return nil
    }
}

struct ManagerView: View {
    @ObservedObject var store: BrowserProfileStore
    @State private var customDirectoryPath: String = ""
    @State private var customDirectoryBrowser: BrowserKind = .chrome

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Browser Profile Launcher")
                .font(.title2.bold())

            HStack(spacing: 12) {
                Text("目录")
                    .frame(width: 64, alignment: .leading)
                Picker("浏览器", selection: $customDirectoryBrowser) {
                    ForEach(BrowserKind.allCases) { browser in
                        Text(browser.displayName).tag(browser)
                    }
                }
                .frame(width: 140)
                TextField("输入配置目录，例如 ~/Library/Application Support/Google/Chrome", text: $customDirectoryPath)
                    .textFieldStyle(.roundedBorder)
                Button("解析目录") {
                    store.parseProfiles(from: customDirectoryPath, browser: customDirectoryBrowser)
                }
            }

            HStack(spacing: 12) {
                Text("搜索")
                    .frame(width: 64, alignment: .leading)
                TextField("按浏览器 / 配置名 / 目录 / 账号过滤", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("刷新配置") {
                    store.refreshProfiles()
                }
                Button(store.isScanningNonDefaultDirectories ? "扫描中..." : "扫描非默认目录") {
                    store.scanNonDefaultDirectories()
                }
                .disabled(store.isScanningNonDefaultDirectories)
                Spacer()
            }

            Text(store.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("本机检测到的配置")
                .font(.headline)

            List {
                if !store.recentProfiles.isEmpty {
                    Section("最近使用") {
                        ForEach(store.recentProfiles) { profile in
                            profileRow(profile, showRecentTag: true, includeBrowserInSubtitle: true)
                        }
                    }
                }

                ForEach(store.configs) { config in
                    let profiles = store.sectionProfiles(for: config)
                    if !profiles.isEmpty {
                        Section(config.browser.displayName) {
                            ForEach(profiles) { profile in
                                profileRow(profile, showRecentTag: false, includeBrowserInSubtitle: false)
                            }
                        }
                    }
                }

                if !store.configs.isEmpty && !store.hasVisibleProfiles {
                    Text("没有匹配的配置")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 460)
        .onAppear {
            store.refreshProfiles()
        }
        .alert(
            "删除配置",
            isPresented: deleteAlertBinding,
            presenting: store.pendingDeleteProfile
        ) { profile in
            Button("取消", role: .cancel) {
                store.cancelDelete()
            }
            Button("移到废纸篓", role: .destructive) {
                store.confirmDelete()
            }
        } message: { profile in
            Text("\(profile.displayName)\n\(store.deleteDescription(for: profile))")
        }
    }

    @ViewBuilder
    private func profileRow(
        _ profile: BrowserProfile,
        showRecentTag: Bool,
        includeBrowserInSubtitle: Bool
    ) -> some View {
        let sourceHint = profile.userDataPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let baseSubtitle = profile.userName.map { "\(profile.directory) · \($0)" } ?? profile.directory
        let subtitleWithPath = "\(baseSubtitle) · \(sourceHint)"
        let subtitle = includeBrowserInSubtitle ? "\(profile.browser.displayName) · \(subtitleWithPath)" : subtitleWithPath

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile.displayName)
                    if store.isDefaultProfile(profile) {
                        Text("默认")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if showRecentTag || store.isRecentProfile(profile) {
                        Text("最近")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if store.isNonDefaultProfile(profile) {
                        Text("非默认目录")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("启动") {
                store.launch(profile: profile)
            }
            .buttonStyle(.borderedProminent)
            Button("删除", role: .destructive) {
                store.requestDelete(profile: profile)
            }
            .disabled(!store.canDelete(profile))
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { store.pendingDeleteProfile != nil },
            set: { isPresented in
                if !isPresented {
                    store.cancelDelete()
                }
            }
        )
    }
}

struct MenuBarContentView: View {
    @ObservedObject var store: BrowserProfileStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("打开管理窗口") {
                openWindow(id: "manager")
            }

            Divider()

            if !store.runningProfilesForMenu().isEmpty {
                Section("正在运行") {
                    ForEach(store.runningProfilesForMenu()) { profile in
                        Button("关闭 · \(profileMenuTitle(profile))") {
                            store.close(profile: profile)
                        }
                    }
                }
            }

            if !store.recentProfilesForMenu().isEmpty {
                Section("最近使用") {
                    ForEach(store.recentProfilesForMenu()) { profile in
                        Button("\(store.isRunning(profile) ? "切换" : "启动") · \(profileMenuTitle(profile))") {
                            store.launch(profile: profile)
                        }
                    }
                }
            }

            if !store.profilesExcludingRecentForMenu().isEmpty {
                Section("所有配置") {
                    ForEach(store.profilesExcludingRecentForMenu()) { profile in
                        Button("\(store.isRunning(profile) ? "切换" : "启动") · \(profileMenuTitle(profile))") {
                            store.launch(profile: profile)
                        }
                    }
                }
            }

            if store.menuProfiles().isEmpty {
                Text("没有可用配置")
            }

            Divider()

            Button("刷新配置") {
                store.refreshProfiles()
            }

            Button(store.isScanningNonDefaultDirectories ? "扫描中..." : "扫描非默认目录") {
                store.scanNonDefaultDirectories()
            }
            .disabled(store.isScanningNonDefaultDirectories)

            Divider()

            Text(store.statusMessage)
                .lineLimit(2)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            if store.configs.isEmpty {
                store.refreshProfiles()
            } else {
                store.refreshRunningProfiles()
            }
        }
    }

    private func profileMenuTitle(_ profile: BrowserProfile) -> String {
        let browserLabel = profile.browser.displayName
        if let userName = profile.userName, !userName.isEmpty {
            return "\(browserLabel) · \(profile.displayName) (\(userName))"
        }
        return "\(browserLabel) · \(profile.displayName) (\(profile.directory))"
    }
}

@main
struct BrowserProfileLauncherApp: App {
    @StateObject private var store = BrowserProfileStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Browser Profiles", systemImage: "globe") {
            MenuBarContentView(store: store)
        }

        WindowGroup(id: "manager") {
            ManagerView(store: store)
        }
    }
}
