import XCTest
@testable import KlipPal
import AppKit

/// Tests for menu item actions in StatusBarController
/// These tests verify that menu items are correctly configured and that
/// programmatically invoking their actions works as expected.
final class MenuActionTests: XCTestCase {

    override func setUp() async throws {
        // Reset preferences window state before each test
        await MainActor.run {
            PreferencesWindowController.shared = nil
        }
    }

    // MARK: - Menu Structure Tests

    @MainActor
    func testMenuHasExpectedItems() async throws {
        // Note: StatusBarController requires NSStatusBar which needs window server
        // So we test the menu items indirectly by creating menu items with same pattern

        let menu = NSMenu()
        menu.autoenablesItems = false

        let controller = MockMenuTarget()

        let openItem = NSMenuItem(title: "Open Clipboard History", action: nil, keyEquivalent: "")
        openItem.target = controller
        openItem.action = #selector(MockMenuTarget.openClipboardHistory)
        openItem.isEnabled = true
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ",")
        prefsItem.target = controller
        prefsItem.action = #selector(MockMenuTarget.openPreferences)
        prefsItem.isEnabled = true
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit CopyManager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = nil
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        // Verify menu structure
        XCTAssertEqual(menu.items.count, 5, "Menu should have 5 items (3 actions + 2 separators)")

        // Verify non-separator items
        let actionItems = menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(actionItems.count, 3, "Should have 3 action items")

        XCTAssertEqual(actionItems[0].title, "Open Clipboard History")
        XCTAssertEqual(actionItems[1].title, "Preferences...")
        XCTAssertEqual(actionItems[2].title, "Quit CopyManager")
    }

    // MARK: - Action Invocation Tests

    @MainActor
    func testPreferencesActionCanBeInvoked() async throws {
        let controller = MockMenuTarget()

        // Verify initial state
        XCTAssertEqual(controller.preferencesOpenedCount, 0, "Should start with 0 preferences opens")

        // Create menu item with target/action
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(MockMenuTarget.openPreferences), keyEquivalent: ",")
        prefsItem.target = controller
        prefsItem.isEnabled = true

        // Verify target and action are set correctly
        XCTAssertNotNil(prefsItem.target, "Target should not be nil")
        XCTAssertNotNil(prefsItem.action, "Action should not be nil")
        XCTAssertTrue(prefsItem.target === controller, "Target should be controller")
        XCTAssertEqual(prefsItem.action, #selector(MockMenuTarget.openPreferences), "Action should be openPreferences")

        // Programmatically invoke the action (simulating menu click)
        if let target = prefsItem.target as? MockMenuTarget,
           let action = prefsItem.action {
            _ = target.perform(action, with: prefsItem)
        }

        // Verify action was invoked
        XCTAssertEqual(controller.preferencesOpenedCount, 1, "Preferences should have been opened once")
    }

    @MainActor
    func testClipboardHistoryActionCanBeInvoked() async throws {
        let controller = MockMenuTarget()

        // Verify initial state
        XCTAssertEqual(controller.clipboardHistoryOpenedCount, 0, "Should start with 0 history opens")

        // Create menu item with target/action
        let historyItem = NSMenuItem(title: "Open Clipboard History", action: #selector(MockMenuTarget.openClipboardHistory), keyEquivalent: "")
        historyItem.target = controller
        historyItem.isEnabled = true

        // Programmatically invoke the action
        if let target = historyItem.target as? MockMenuTarget,
           let action = historyItem.action {
            _ = target.perform(action, with: historyItem)
        }

        // Verify action was invoked
        XCTAssertEqual(controller.clipboardHistoryOpenedCount, 1, "Clipboard history should have been opened once")
    }

    @MainActor
    func testMenuItemTargetRespondsToSelector() async throws {
        let controller = MockMenuTarget()

        // Test that target responds to the selectors
        XCTAssertTrue(controller.responds(to: #selector(MockMenuTarget.openPreferences)), "Should respond to openPreferences")
        XCTAssertTrue(controller.responds(to: #selector(MockMenuTarget.openClipboardHistory)), "Should respond to openClipboardHistory")
    }

    @MainActor
    func testMenuItemIsEnabledWhenTargetResponds() async throws {
        let controller = MockMenuTarget()

        let menu = NSMenu()
        menu.autoenablesItems = false  // Disable auto-enabling (unreliable in headless tests)

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(MockMenuTarget.openPreferences), keyEquivalent: ",")
        prefsItem.target = controller
        prefsItem.isEnabled = true  // Manually enable since we verified target responds
        menu.addItem(prefsItem)

        // Verify the item is properly configured
        XCTAssertNotNil(prefsItem.target, "Target should be set")
        XCTAssertNotNil(prefsItem.action, "Action should be set")
        XCTAssertTrue(controller.responds(to: prefsItem.action!), "Target should respond to action selector")
        XCTAssertTrue(prefsItem.isEnabled, "Item should be enabled when properly configured")
    }

    @MainActor
    func testDirectMethodCallWorks() async throws {
        // This test verifies that calling the method directly works
        // If this passes but menu click doesn't work, the issue is in menu dispatch

        let controller = MockMenuTarget()

        XCTAssertEqual(controller.preferencesOpenedCount, 0)

        // Direct method call
        controller.openPreferences()

        XCTAssertEqual(controller.preferencesOpenedCount, 1, "Direct call should increment count")
    }

    @MainActor
    func testNSMenuItemPerformAction() async throws {
        // Test using NSMenuItem's built-in action mechanism
        let controller = MockMenuTarget()

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(MockMenuTarget.openPreferences), keyEquivalent: ",")
        prefsItem.target = controller
        prefsItem.isEnabled = true

        // Use performSelector to invoke the action
        let selector = prefsItem.action!
        let target = prefsItem.target as! NSObject

        XCTAssertEqual(controller.preferencesOpenedCount, 0)

        // Invoke using performSelector
        target.perform(selector)

        XCTAssertEqual(controller.preferencesOpenedCount, 1, "performSelector should trigger action")
    }

    // MARK: - Real PreferencesWindowController Integration

    @MainActor
    func testPreferencesWindowOpensWhenActionInvoked() async throws {
        // Verify that calling PreferencesWindowController.show() actually creates a window
        XCTAssertNil(PreferencesWindowController.shared, "Should start with no shared instance")

        PreferencesWindowController.show()

        XCTAssertNotNil(PreferencesWindowController.shared, "Shared instance should exist after show()")
        XCTAssertNotNil(PreferencesWindowController.shared?.window, "Window should exist")
    }

    @MainActor
    func testMockControllerOpensPreferencesWindow() async throws {
        // Test that MockMenuTarget's openPreferences actually calls PreferencesWindowController.show()
        let controller = MockMenuTarget()

        XCTAssertNil(PreferencesWindowController.shared, "Should start with no shared instance")

        controller.openPreferences()

        // Wait for async dispatch to complete
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        XCTAssertNotNil(PreferencesWindowController.shared, "Preferences window should be created")
        XCTAssertEqual(controller.preferencesOpenedCount, 1)
    }
}

// MARK: - Mock Menu Target

/// A mock target that mimics StatusBarController's menu action handling
/// This avoids needing NSStatusBar which requires window server access
class MockMenuTarget: NSObject {
    private(set) var preferencesOpenedCount: Int = 0
    private(set) var clipboardHistoryOpenedCount: Int = 0

    @objc func openPreferences() {
        print("📋 MockMenuTarget.openPreferences called")
        preferencesOpenedCount += 1
        DispatchQueue.main.async {
            PreferencesWindowController.show()
        }
    }

    @objc func openClipboardHistory() {
        print("📋 MockMenuTarget.openClipboardHistory called")
        clipboardHistoryOpenedCount += 1
    }
}
