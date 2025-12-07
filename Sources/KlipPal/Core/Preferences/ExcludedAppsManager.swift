import Foundation
import Combine
import AppKit

/// Represents an app that can be excluded from clipboard history
struct ExcludedApp: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
    }
}

/// Manages the list of apps excluded from clipboard history
@MainActor
final class ExcludedAppsManager: ObservableObject {
    static let shared = ExcludedAppsManager()

    private let userDefaultsKey = "excludedApps"
    private let masterToggleKey = "excludeAppsEnabled"

    /// Whether the exclusion feature is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: masterToggleKey)
        }
    }

    /// List of excluded apps
    @Published var excludedApps: [ExcludedApp] {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Default password manager apps to exclude
    static let defaultExcludedApps: [String] = [
        "1Password",
        "1Password 7",
        "1Password 8",
        "Bitwarden",
        "LastPass",
        "Dashlane",
        "KeePassXC",
        "KeePass",
        "Keeper",
        "NordPass",
        "RoboForm",
        "Enpass",
        "mSecure",
        "SafeInCloud",
        "Secrets",
        "Strongbox",
        "pass",
        "gopass",
        "MacPass",
        "AuthPass",
        "Buttercup",
        "Padloc",
        "Passbolt",
        "Proton Pass",
        "ExpressVPN Keys",
        "Norton Password Manager",
        "Avira Password Manager",
        "Zoho Vault",
        "Sticky Password",
        "Password Boss",
        "True Key",
        "LogMeOnce",
        "Keychain Access"
    ]

    private init() {
        // Load master toggle (default: enabled)
        isEnabled = UserDefaults.standard.object(forKey: masterToggleKey) as? Bool ?? true

        // Load excluded apps from UserDefaults or use defaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data) {
            excludedApps = apps
        } else {
            // First launch: populate with default password managers
            excludedApps = Self.defaultExcludedApps.map { ExcludedApp(name: $0, isEnabled: true) }
        }
    }

    /// For testing: create with custom initial state
    init(isEnabled: Bool, excludedApps: [ExcludedApp]) {
        self.isEnabled = isEnabled
        self.excludedApps = excludedApps
    }

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(excludedApps) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Check if an app should be excluded from clipboard history
    func shouldExclude(appName: String?) -> Bool {
        guard isEnabled, let appName = appName else { return false }
        return excludedApps.contains { $0.name == appName && $0.isEnabled }
    }

    /// Add an app to the exclusion list
    func addApp(name: String) {
        guard !excludedApps.contains(where: { $0.name == name }) else { return }
        excludedApps.append(ExcludedApp(name: name, isEnabled: true))
        // Sort alphabetically
        excludedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Add multiple apps to the exclusion list
    func addApps(names: [String]) {
        for name in names {
            if !excludedApps.contains(where: { $0.name == name }) {
                excludedApps.append(ExcludedApp(name: name, isEnabled: true))
            }
        }
        // Sort alphabetically
        excludedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Remove an app from the exclusion list
    func removeApp(id: UUID) {
        excludedApps.removeAll { $0.id == id }
    }

    /// Toggle the enabled state of an app
    func toggleApp(id: UUID) {
        if let index = excludedApps.firstIndex(where: { $0.id == id }) {
            excludedApps[index].isEnabled.toggle()
        }
    }

    /// Reset to default excluded apps
    func resetToDefaults() {
        isEnabled = true
        excludedApps = Self.defaultExcludedApps.map { ExcludedApp(name: $0, isEnabled: true) }
    }

    /// Get list of currently running applications
    func getRunningApps() -> [String] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let excludedNames = Set(excludedApps.map { $0.name })

        return runningApps
            .filter { $0.activationPolicy == .regular }  // Only regular apps (not background/accessory)
            .compactMap { $0.localizedName }
            .filter { !excludedNames.contains($0) }  // Exclude already added apps
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Get list of running apps not already in the exclusion list
    func getRunningAppsNotExcluded() -> [String] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let excludedNames = Set(excludedApps.map { $0.name })

        return runningApps
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .filter { !excludedNames.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
