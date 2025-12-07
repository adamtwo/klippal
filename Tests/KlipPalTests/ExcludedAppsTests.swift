import XCTest
@testable import KlipPal

/// Tests for ExcludedAppsManager
final class ExcludedAppsTests: XCTestCase {

    override func setUp() async throws {
        // Clear excluded apps preferences for clean tests
        UserDefaults.standard.removeObject(forKey: "excludedApps")
        UserDefaults.standard.removeObject(forKey: "excludeAppsEnabled")
    }

    // MARK: - ExcludedApp Model Tests

    func testExcludedAppInitialization() {
        let app = ExcludedApp(name: "TestApp", isEnabled: true)

        XCTAssertEqual(app.name, "TestApp")
        XCTAssertTrue(app.isEnabled)
        XCTAssertNotNil(app.id)
    }

    func testExcludedAppDefaultIsEnabled() {
        let app = ExcludedApp(name: "TestApp")

        XCTAssertTrue(app.isEnabled, "Default isEnabled should be true")
    }

    func testExcludedAppEquality() {
        let id = UUID()
        let app1 = ExcludedApp(id: id, name: "TestApp", isEnabled: true)
        let app2 = ExcludedApp(id: id, name: "TestApp", isEnabled: true)

        XCTAssertEqual(app1, app2)
    }

    func testExcludedAppCodable() throws {
        let original = ExcludedApp(name: "TestApp", isEnabled: false)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExcludedApp.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    }

    // MARK: - ExcludedAppsManager Tests

    @MainActor
    func testManagerDefaultState() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        XCTAssertTrue(manager.isEnabled, "Manager should be enabled by default")
        XCTAssertTrue(manager.excludedApps.isEmpty, "Should start with empty apps list")
    }

    @MainActor
    func testManagerWithCustomInitialState() {
        let apps = [ExcludedApp(name: "1Password"), ExcludedApp(name: "Bitwarden")]
        let manager = ExcludedAppsManager(isEnabled: false, excludedApps: apps)

        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(manager.excludedApps.count, 2)
    }

    @MainActor
    func testAddApp() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        manager.addApp(name: "TestApp")

        XCTAssertEqual(manager.excludedApps.count, 1)
        XCTAssertEqual(manager.excludedApps.first?.name, "TestApp")
        XCTAssertTrue(manager.excludedApps.first?.isEnabled ?? false)
    }

    @MainActor
    func testAddAppPreventsDuplicates() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        manager.addApp(name: "TestApp")
        manager.addApp(name: "TestApp")

        XCTAssertEqual(manager.excludedApps.count, 1, "Should not add duplicate apps")
    }

    @MainActor
    func testAddAppsSortsAlphabetically() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        manager.addApp(name: "Zoom")
        manager.addApp(name: "Apple Notes")
        manager.addApp(name: "Mail")

        XCTAssertEqual(manager.excludedApps[0].name, "Apple Notes")
        XCTAssertEqual(manager.excludedApps[1].name, "Mail")
        XCTAssertEqual(manager.excludedApps[2].name, "Zoom")
    }

    @MainActor
    func testAddMultipleApps() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        manager.addApps(names: ["App1", "App2", "App3"])

        XCTAssertEqual(manager.excludedApps.count, 3)
    }

    @MainActor
    func testAddMultipleAppsPreventsDuplicates() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [ExcludedApp(name: "App1")])

        manager.addApps(names: ["App1", "App2", "App3"])

        XCTAssertEqual(manager.excludedApps.count, 3, "Should not add duplicate App1")
    }

    @MainActor
    func testRemoveApp() {
        let app = ExcludedApp(name: "TestApp")
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [app])

        manager.removeApp(id: app.id)

        XCTAssertTrue(manager.excludedApps.isEmpty)
    }

    @MainActor
    func testRemoveNonexistentApp() {
        let app = ExcludedApp(name: "TestApp")
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [app])

        manager.removeApp(id: UUID())

        XCTAssertEqual(manager.excludedApps.count, 1, "Should not remove any app")
    }

    @MainActor
    func testToggleApp() {
        let app = ExcludedApp(name: "TestApp", isEnabled: true)
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [app])

        manager.toggleApp(id: app.id)

        XCTAssertFalse(manager.excludedApps.first?.isEnabled ?? true)

        manager.toggleApp(id: app.id)

        XCTAssertTrue(manager.excludedApps.first?.isEnabled ?? false)
    }

    @MainActor
    func testToggleNonexistentApp() {
        let app = ExcludedApp(name: "TestApp", isEnabled: true)
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [app])

        manager.toggleApp(id: UUID())

        XCTAssertTrue(manager.excludedApps.first?.isEnabled ?? false, "Original app should remain unchanged")
    }

    // MARK: - shouldExclude Tests

    @MainActor
    func testShouldExcludeWhenEnabled() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: true)
        ])

        XCTAssertTrue(manager.shouldExclude(appName: "1Password"))
    }

    @MainActor
    func testShouldNotExcludeWhenManagerDisabled() {
        let manager = ExcludedAppsManager(isEnabled: false, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: true)
        ])

        XCTAssertFalse(manager.shouldExclude(appName: "1Password"))
    }

    @MainActor
    func testShouldNotExcludeWhenAppDisabled() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: false)
        ])

        XCTAssertFalse(manager.shouldExclude(appName: "1Password"))
    }

    @MainActor
    func testShouldNotExcludeUnlistedApp() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: true)
        ])

        XCTAssertFalse(manager.shouldExclude(appName: "Safari"))
    }

    @MainActor
    func testShouldNotExcludeNilAppName() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: true)
        ])

        XCTAssertFalse(manager.shouldExclude(appName: nil))
    }

    @MainActor
    func testShouldExcludeIsCaseSensitive() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [
            ExcludedApp(name: "1Password", isEnabled: true)
        ])

        XCTAssertTrue(manager.shouldExclude(appName: "1Password"))
        XCTAssertFalse(manager.shouldExclude(appName: "1password"))
    }

    // MARK: - Reset to Defaults Tests

    @MainActor
    func testResetToDefaults() {
        let manager = ExcludedAppsManager(isEnabled: false, excludedApps: [
            ExcludedApp(name: "CustomApp", isEnabled: false)
        ])

        manager.resetToDefaults()

        XCTAssertTrue(manager.isEnabled)
        XCTAssertFalse(manager.excludedApps.isEmpty)
        XCTAssertTrue(manager.excludedApps.contains { $0.name == "1Password" })
        XCTAssertTrue(manager.excludedApps.allSatisfy { $0.isEnabled })
    }

    @MainActor
    func testDefaultExcludedAppsContainsPasswordManagers() {
        let defaults = ExcludedAppsManager.defaultExcludedApps

        XCTAssertTrue(defaults.contains("1Password"))
        XCTAssertTrue(defaults.contains("Bitwarden"))
        XCTAssertTrue(defaults.contains("LastPass"))
        XCTAssertTrue(defaults.contains("KeePassXC"))
        XCTAssertTrue(defaults.contains("Keychain Access"))
    }

    // MARK: - Running Apps Tests

    @MainActor
    func testGetRunningAppsNotExcludedFiltersExcluded() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        // Get running apps before and after adding an exclusion
        let appsBefore = manager.getRunningAppsNotExcluded()

        if let firstApp = appsBefore.first {
            manager.addApp(name: firstApp)
            let appsAfter = manager.getRunningAppsNotExcluded()

            XCTAssertFalse(appsAfter.contains(firstApp), "Excluded app should not appear in list")
        }
    }

    @MainActor
    func testGetRunningAppsIsSorted() {
        let manager = ExcludedAppsManager(isEnabled: true, excludedApps: [])

        let apps = manager.getRunningAppsNotExcluded()

        let sorted = apps.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(apps, sorted, "Running apps should be sorted alphabetically")
    }
}
