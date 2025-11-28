import XCTest
import AppKit
import SwiftUI
@testable import KlipPal

/// Tests for key event handling in the overlay window
/// These tests verify that the NSPanel properly routes keyboard events
final class OverlayKeyEventTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_keys_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        // Seed test data
        for i in 1...5 {
            let item = ClipboardItem(
                content: "Item \(i) content for testing",
                contentType: .text,
                contentHash: "keyhash\(i)_\(UUID().uuidString)",
                sourceApp: "TestApp"
            )
            try await storage.save(item)
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Key Code Constants

    struct KeyCodes {
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
        static let tab: UInt16 = 48
        static let space: UInt16 = 49
        // Edit command keys
        static let a: UInt16 = 0      // Cmd+A (Select All)
        static let c: UInt16 = 8      // Cmd+C (Copy)
        static let v: UInt16 = 9      // Cmd+V (Paste)
        static let x: UInt16 = 7      // Cmd+X (Cut)
        static let z: UInt16 = 6      // Cmd+Z (Undo)
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
    }

    // MARK: - Event Creation Helper

    func createKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    // MARK: - Panel Key Event Routing Tests

    @MainActor
    func testPanelAcceptsFirstResponder() async throws {
        let panel = TestableOverlayPanel()

        XCTAssertTrue(panel.canBecomeKey, "Panel should be able to become key window")
        XCTAssertTrue(panel.acceptsFirstResponder, "Panel should accept first responder")
    }

    @MainActor
    func testPanelCapturesDownArrowKey() async throws {
        let panel = TestableOverlayPanel()
        var capturedKeyCode: UInt16?

        panel.onKeyDown = { event in
            capturedKeyCode = event.keyCode
            return true
        }

        guard let event = createKeyEvent(keyCode: KeyCodes.downArrow) else {
            XCTFail("Failed to create key event")
            return
        }

        panel.keyDown(with: event)

        XCTAssertEqual(capturedKeyCode, KeyCodes.downArrow, "Panel should capture down arrow key")
    }

    @MainActor
    func testPanelCapturesUpArrowKey() async throws {
        let panel = TestableOverlayPanel()
        var capturedKeyCode: UInt16?

        panel.onKeyDown = { event in
            capturedKeyCode = event.keyCode
            return true
        }

        guard let event = createKeyEvent(keyCode: KeyCodes.upArrow) else {
            XCTFail("Failed to create key event")
            return
        }

        panel.keyDown(with: event)

        XCTAssertEqual(capturedKeyCode, KeyCodes.upArrow, "Panel should capture up arrow key")
    }

    @MainActor
    func testPanelCapturesReturnKey() async throws {
        let panel = TestableOverlayPanel()
        var capturedKeyCode: UInt16?

        panel.onKeyDown = { event in
            capturedKeyCode = event.keyCode
            return true
        }

        guard let event = createKeyEvent(keyCode: KeyCodes.returnKey) else {
            XCTFail("Failed to create key event")
            return
        }

        panel.keyDown(with: event)

        XCTAssertEqual(capturedKeyCode, KeyCodes.returnKey, "Panel should capture return key")
    }

    @MainActor
    func testPanelCapturesEscapeKey() async throws {
        let panel = TestableOverlayPanel()
        var capturedKeyCode: UInt16?

        panel.onKeyDown = { event in
            capturedKeyCode = event.keyCode
            return true
        }

        guard let event = createKeyEvent(keyCode: KeyCodes.escape) else {
            XCTFail("Failed to create key event")
            return
        }

        panel.keyDown(with: event)

        XCTAssertEqual(capturedKeyCode, KeyCodes.escape, "Panel should capture escape key")
    }

    // MARK: - Full Integration: ViewModel + Key Events

    @MainActor
    func testKeyEventToViewModelIntegration() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        // Wait for items to load
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        guard !viewModel.filteredItems.isEmpty else {
            XCTFail("ViewModel should have items loaded")
            return
        }

        // Create a key handler that routes to viewModel
        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        // Test down arrow
        if let downEvent = createKeyEvent(keyCode: KeyCodes.downArrow) {
            let initialIndex = viewModel.selectedIndex
            let handled = keyHandler.handleKeyDown(downEvent)

            XCTAssertTrue(handled, "Down arrow should be handled")
            XCTAssertEqual(viewModel.selectedIndex, initialIndex + 1, "Down arrow should increment selection")
        }

        // Test up arrow
        if let upEvent = createKeyEvent(keyCode: KeyCodes.upArrow) {
            let initialIndex = viewModel.selectedIndex
            let handled = keyHandler.handleKeyDown(upEvent)

            XCTAssertTrue(handled, "Up arrow should be handled")
            XCTAssertEqual(viewModel.selectedIndex, initialIndex - 1, "Up arrow should decrement selection")
        }
    }

    @MainActor
    func testEscapeClosesWindow() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        var windowClosed = false

        viewModel.onCloseWindow = {
            windowClosed = true
        }

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        if let escEvent = createKeyEvent(keyCode: KeyCodes.escape) {
            let handled = keyHandler.handleKeyDown(escEvent)

            XCTAssertTrue(handled, "Escape should be handled")
            XCTAssertTrue(windowClosed, "Escape should trigger window close")
        }
    }

    @MainActor
    func testReturnTriggersPaste() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        // Wait for items to load
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        var pasteTriggered = false
        viewModel.onBeforePaste = {
            pasteTriggered = true
        }

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        if let returnEvent = createKeyEvent(keyCode: KeyCodes.returnKey) {
            let handled = keyHandler.handleKeyDown(returnEvent)

            XCTAssertTrue(handled, "Return should be handled")
            // Give async paste time to start
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            XCTAssertTrue(pasteTriggered, "Return should trigger paste")
        }
    }

    // MARK: - Navigation Boundary Tests

    @MainActor
    func testNavigationAtTopBoundary() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Ensure we're at the top
        viewModel.selectedIndex = 0

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        // Try to go up from index 0
        if let upEvent = createKeyEvent(keyCode: KeyCodes.upArrow) {
            _ = keyHandler.handleKeyDown(upEvent)
            XCTAssertEqual(viewModel.selectedIndex, 0, "Should stay at 0 when at top boundary")
        }
    }

    @MainActor
    func testNavigationAtBottomBoundary() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        guard !viewModel.filteredItems.isEmpty else {
            XCTFail("Need items to test boundary")
            return
        }

        // Move to last item
        let lastIndex = viewModel.filteredItems.count - 1
        viewModel.selectedIndex = lastIndex

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        // Try to go down from last index
        if let downEvent = createKeyEvent(keyCode: KeyCodes.downArrow) {
            _ = keyHandler.handleKeyDown(downEvent)
            XCTAssertEqual(viewModel.selectedIndex, lastIndex, "Should stay at last index when at bottom boundary")
        }
    }

    // MARK: - Rapid Key Press Tests

    @MainActor
    func testRapidDownArrowPresses() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        // Rapidly press down arrow 3 times
        for _ in 0..<3 {
            if let downEvent = createKeyEvent(keyCode: KeyCodes.downArrow) {
                _ = keyHandler.handleKeyDown(downEvent)
            }
        }

        XCTAssertEqual(viewModel.selectedIndex, min(3, viewModel.filteredItems.count - 1),
                      "Rapid down arrows should increment by 3 (or stop at end)")
    }

    @MainActor
    func testRapidUpArrowPresses() async throws {
        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItems()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Start from index 3
        viewModel.selectedIndex = 3

        let keyHandler = OverlayKeyHandler(viewModel: viewModel)

        // Rapidly press up arrow 5 times
        for _ in 0..<5 {
            if let upEvent = createKeyEvent(keyCode: KeyCodes.upArrow) {
                _ = keyHandler.handleKeyDown(upEvent)
            }
        }

        XCTAssertEqual(viewModel.selectedIndex, 0, "Rapid up arrows should stop at 0")
    }

    // MARK: - Edit Command Tests (should pass through to TextField)

    @MainActor
    func testCmdAPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+A (Select All) should NOT be handled by keyHandler - should pass to TextField
        if let cmdAEvent = createKeyEvent(keyCode: KeyCodes.a, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(cmdAEvent)
            XCTAssertFalse(handled, "Cmd+A should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdCPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+C (Copy) should NOT be handled by keyHandler - should pass to TextField
        if let cmdCEvent = createKeyEvent(keyCode: KeyCodes.c, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(cmdCEvent)
            XCTAssertFalse(handled, "Cmd+C should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdVPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+V (Paste) should NOT be handled by keyHandler - should pass to TextField
        if let cmdVEvent = createKeyEvent(keyCode: KeyCodes.v, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(cmdVEvent)
            XCTAssertFalse(handled, "Cmd+V should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdXPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+X (Cut) should NOT be handled by keyHandler - should pass to TextField
        if let cmdXEvent = createKeyEvent(keyCode: KeyCodes.x, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(cmdXEvent)
            XCTAssertFalse(handled, "Cmd+X should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdZPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+Z (Undo) should NOT be handled by keyHandler - should pass to TextField
        if let cmdZEvent = createKeyEvent(keyCode: KeyCodes.z, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(cmdZEvent)
            XCTAssertFalse(handled, "Cmd+Z should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testLeftArrowPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Left arrow (cursor movement) should NOT be handled - should pass to TextField
        if let leftEvent = createKeyEvent(keyCode: KeyCodes.leftArrow) {
            let handled = keyHandler.handleKeyDown(leftEvent)
            XCTAssertFalse(handled, "Left arrow should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testRightArrowPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Right arrow (cursor movement) should NOT be handled - should pass to TextField
        if let rightEvent = createKeyEvent(keyCode: KeyCodes.rightArrow) {
            let handled = keyHandler.handleKeyDown(rightEvent)
            XCTAssertFalse(handled, "Right arrow should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdLeftArrowPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+Left arrow (move to beginning) should pass through
        if let event = createKeyEvent(keyCode: KeyCodes.leftArrow, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(event)
            XCTAssertFalse(handled, "Cmd+Left should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testCmdRightArrowPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Cmd+Right arrow (move to end) should pass through
        if let event = createKeyEvent(keyCode: KeyCodes.rightArrow, modifiers: .command) {
            let handled = keyHandler.handleKeyDown(event)
            XCTAssertFalse(handled, "Cmd+Right should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testOptionLeftArrowPassesThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Option+Left arrow (move by word) should pass through
        if let event = createKeyEvent(keyCode: KeyCodes.leftArrow, modifiers: .option) {
            let handled = keyHandler.handleKeyDown(event)
            XCTAssertFalse(handled, "Option+Left should pass through to TextField (not handled)")
        }
    }

    @MainActor
    func testShiftArrowsPassThroughToTextField() async throws {
        let keyHandler = OverlayKeyHandler(viewModel: OverlayViewModel(storage: storage))

        // Shift+Left arrow (select left) should pass through
        if let event = createKeyEvent(keyCode: KeyCodes.leftArrow, modifiers: .shift) {
            let handled = keyHandler.handleKeyDown(event)
            XCTAssertFalse(handled, "Shift+Left should pass through to TextField (not handled)")
        }

        // Shift+Right arrow (select right) should pass through
        if let event = createKeyEvent(keyCode: KeyCodes.rightArrow, modifiers: .shift) {
            let handled = keyHandler.handleKeyDown(event)
            XCTAssertFalse(handled, "Shift+Right should pass through to TextField (not handled)")
        }
    }
}

// MARK: - Test Doubles

/// A testable NSPanel that allows intercepting key events
class TestableOverlayPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var capturedEvents: [NSEvent] = []

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        capturedEvents.append(event)
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}

/// Key handler that routes NSEvent to OverlayViewModel actions
/// This mirrors the logic in OverlayPanel.handleKeyEvent
@MainActor
class OverlayKeyHandler {
    private let viewModel: OverlayViewModel

    // Key codes for edit commands that should pass through to TextField
    private let editCommandKeys: Set<UInt16> = [
        0,   // A (Cmd+A: Select All)
        8,   // C (Cmd+C: Copy)
        9,   // V (Cmd+V: Paste)
        7,   // X (Cmd+X: Cut)
        6,   // Z (Cmd+Z: Undo)
    ]

    // Arrow keys for cursor navigation
    private let horizontalArrowKeys: Set<UInt16> = [
        123, // Left arrow
        124, // Right arrow
    ]

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        // Allow edit commands (Cmd+A/C/V/X/Z) to pass through to TextField
        if modifiers.contains(.command) && editCommandKeys.contains(keyCode) {
            return false
        }

        // Allow horizontal arrow keys to pass through for cursor movement
        // This includes plain arrows, Shift+arrows (selection), Cmd+arrows (jump to start/end),
        // and Option+arrows (word movement)
        if horizontalArrowKeys.contains(keyCode) {
            return false
        }

        switch keyCode {
        case 125: // Down arrow
            viewModel.selectNext()
            return true

        case 126: // Up arrow
            viewModel.selectPrevious()
            return true

        case 36: // Return/Enter
            viewModel.pasteSelected()
            return true

        case 53: // Escape
            viewModel.onCloseWindow?()
            return true

        default:
            return false
        }
    }
}
