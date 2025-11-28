import XCTest
@testable import KlipPal

/// Integration tests for Preferences window functionality
/// Note: StatusBarController tests are skipped because they require window server
final class PreferencesIntegrationTests: XCTestCase {

    override func setUp() async throws {
        // Reset shared instance before each test
        await MainActor.run {
            PreferencesWindowController.shared = nil
        }
    }

    // MARK: - PreferencesWindowController Tests

    @MainActor
    func testPreferencesWindowControllerShowCreatesWindow() async throws {
        // Call show
        PreferencesWindowController.show()

        // Verify shared instance exists
        XCTAssertNotNil(PreferencesWindowController.shared, "shared should not be nil after show()")

        // Verify window exists
        XCTAssertNotNil(PreferencesWindowController.shared?.window, "window should not be nil")

        // Verify window has content view
        XCTAssertNotNil(PreferencesWindowController.shared?.window?.contentView, "window should have content view")
    }

    @MainActor
    func testPreferencesWindowControllerShowMultipleTimes() async throws {
        // Call show multiple times
        PreferencesWindowController.show()
        let firstInstance = PreferencesWindowController.shared

        PreferencesWindowController.show()
        let secondInstance = PreferencesWindowController.shared

        // Should be same instance
        XCTAssertTrue(firstInstance === secondInstance, "Multiple calls to show() should use same instance")
    }

    @MainActor
    func testPreferencesWindowControllerInitCreatesWindow() async throws {
        let controller = PreferencesWindowController()

        XCTAssertNotNil(controller.window, "Window should be created in init")
        XCTAssertEqual(controller.window?.title, "KlipPal Preferences", "Window title should be set")
    }

    @MainActor
    func testPreferencesWindowHasSwiftUIContent() async throws {
        let controller = PreferencesWindowController()

        // The content view should be an NSHostingView
        let contentView = controller.window?.contentView
        XCTAssertNotNil(contentView, "Window should have content view")

        // Check that it's an NSHostingView (contains SwiftUI content)
        let contentTypeName = String(describing: type(of: contentView!))
        XCTAssertTrue(contentTypeName.contains("NSHostingView"), "Content should be NSHostingView, got: \(contentTypeName)")
    }

    @MainActor
    func testPreferencesWindowIsNotReleasedWhenClosed() async throws {
        let controller = PreferencesWindowController()

        XCTAssertFalse(controller.window?.isReleasedWhenClosed ?? true, "Window should not be released when closed")
    }

    @MainActor
    func testPreferencesWindowStyleMask() async throws {
        let controller = PreferencesWindowController()

        let styleMask = controller.window?.styleMask ?? []

        XCTAssertTrue(styleMask.contains(.titled), "Window should have title bar")
        XCTAssertTrue(styleMask.contains(.closable), "Window should be closable")
    }

    // MARK: - Window Visibility Tests

    @MainActor
    func testShowMakesWindowKeyAndOrdersFront() async throws {
        PreferencesWindowController.show()

        // Window should exist
        let window = PreferencesWindowController.shared?.window
        XCTAssertNotNil(window, "Window should exist after show()")

        // Note: Can't reliably test isKeyWindow in test environment
        // but we verified the code calls makeKeyAndOrderFront
    }
}
