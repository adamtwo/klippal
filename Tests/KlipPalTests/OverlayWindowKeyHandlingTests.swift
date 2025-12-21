import XCTest
import AppKit
import SwiftUI
import ObjectiveC
@testable import KlipPal

/// Tests that verify the actual OverlayWindowController handles keyboard events
final class OverlayWindowKeyHandlingTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_window_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        // Seed test data
        for i in 1...5 {
            let item = ClipboardItem(
                content: "Window test item \(i)",
                contentType: .text,
                contentHash: "windowhash\(i)_\(UUID().uuidString)",
                sourceApp: "TestApp"
            )
            try await storage.save(item)
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Direct sendEvent Tests

    /// Tests that calling sendEvent directly on OverlayPanel works
    @MainActor
    func testDirectSendEventCallWorks() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 300_000_000)

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        XCTAssertEqual(viewModel.selectedIndex, 0)

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{F701}",
            charactersIgnoringModifiers: "\u{F701}",
            isARepeat: false,
            keyCode: 125
        ) else {
            XCTFail("Failed to create event")
            return
        }

        // sendEvent intercepts arrow keys
        panel.sendEvent(event)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 1, "sendEvent should handle arrow keys")
        panel.close()
    }

    // MARK: - sendEvent Tests (simulates real event flow)

    /// Tests that arrow keys work when sent through sendEvent (simulates real app behavior)
    /// This test will FAIL if events are being intercepted by the TextField
    @MainActor
    func testSendEventDownArrowChangesSelection() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard !viewModel.filteredItems.isEmpty else {
            XCTFail("ViewModel should have items")
            return
        }

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        // Add SwiftUI content view (like real app does)
        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)

        // Show the panel
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 0, "Initial selection should be 0")

        guard let downEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{F701}",
            charactersIgnoringModifiers: "\u{F701}",
            isARepeat: false,
            keyCode: 125
        ) else {
            XCTFail("Failed to create event")
            return
        }

        // Send through normal event processing (like real key press)
        panel.sendEvent(downEvent)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 1,
            """
            Down arrow sent via sendEvent should change selection from 0 to 1.
            If this fails, the TextField is likely intercepting arrow key events.
            Solution: Override sendEvent() in OverlayPanel to intercept arrow keys
            before they reach the TextField.
            """)

        panel.close()
    }

    /// Tests that up arrow works through sendEvent
    @MainActor
    func testSendEventUpArrowChangesSelection() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard !viewModel.filteredItems.isEmpty else {
            XCTFail("ViewModel should have items")
            return
        }

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Set selectedIndex AFTER window appears (onAppear resets it to 0)
        viewModel.selectedIndex = 2

        guard let upEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{F700}",
            charactersIgnoringModifiers: "\u{F700}",
            isARepeat: false,
            keyCode: 126
        ) else {
            XCTFail("Failed to create event")
            return
        }

        panel.sendEvent(upEvent)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 1,
            """
            Up arrow sent via sendEvent should change selection from 2 to 1.
            If this fails, the TextField is likely intercepting arrow key events.
            """)

        panel.close()
    }

    /// Tests Escape via sendEvent
    @MainActor
    func testSendEventEscapeTriggersClose() async throws {
        let viewModel = OverlayViewModel(storage: storage)

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        var closeCalled = false
        panel.onClose = { closeCalled = true }

        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        guard let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ) else {
            XCTFail("Failed to create event")
            return
        }

        panel.sendEvent(escEvent)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(closeCalled, "Escape via sendEvent should trigger onClose")

        panel.close()
    }

    /// Tests Return via sendEvent
    @MainActor
    func testSendEventReturnTriggersPaste() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard !viewModel.filteredItems.isEmpty else {
            XCTFail("ViewModel should have items")
            return
        }

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        var pasteCalled = false
        viewModel.onBeforePaste = { pasteCalled = true }

        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        guard let returnEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ) else {
            XCTFail("Failed to create event")
            return
        }

        panel.sendEvent(returnEvent)
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(pasteCalled, "Return via sendEvent should trigger paste")

        panel.close()
    }

    // MARK: - Infrastructure Tests

    @MainActor
    func testOverlayWindowControllerUsesOverlayPanel() async throws {
        let windowController = OverlayWindowController()
        try await Task.sleep(nanoseconds: 300_000_000)

        let panelClassName = String(describing: type(of: windowController.window!))
        XCTAssertEqual(panelClassName, "OverlayPanel",
            "OverlayWindowController should use OverlayPanel class")

        windowController.closeWindow()
    }

    @MainActor
    func testPanelHasCustomSendEventImplementation() async throws {
        let panelClass: AnyClass = OverlayPanel.self
        let hasCustomSendEvent = class_getInstanceMethod(panelClass, #selector(NSWindow.sendEvent(_:))) !=
                                 class_getInstanceMethod(NSPanel.self, #selector(NSWindow.sendEvent(_:)))

        XCTAssertTrue(hasCustomSendEvent, "OverlayPanel should override sendEvent(_:)")
    }
}
