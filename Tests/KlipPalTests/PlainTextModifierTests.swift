import XCTest
import AppKit
@testable import KlipPal

/// Tests for configurable plain text paste modifier
final class PlainTextModifierTests: XCTestCase {

    // MARK: - PlainTextPasteModifier Enum Tests

    func testAllModifierCasesExist() {
        let allCases = PlainTextPasteModifier.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.shift))
        XCTAssertTrue(allCases.contains(.option))
        XCTAssertTrue(allCases.contains(.control))
        XCTAssertTrue(allCases.contains(.command))
    }

    func testModifierDisplayNames() {
        XCTAssertEqual(PlainTextPasteModifier.shift.displayName, "⇧ Shift")
        XCTAssertEqual(PlainTextPasteModifier.option.displayName, "⌥ Option")
        XCTAssertEqual(PlainTextPasteModifier.control.displayName, "⌃ Control")
        XCTAssertEqual(PlainTextPasteModifier.command.displayName, "⌘ Command")
    }

    func testModifierFlags() {
        XCTAssertEqual(PlainTextPasteModifier.shift.modifierFlags, .shift)
        XCTAssertEqual(PlainTextPasteModifier.option.modifierFlags, .option)
        XCTAssertEqual(PlainTextPasteModifier.control.modifierFlags, .control)
        XCTAssertEqual(PlainTextPasteModifier.command.modifierFlags, .command)
    }

    func testModifierRawValues() {
        XCTAssertEqual(PlainTextPasteModifier.shift.rawValue, "shift")
        XCTAssertEqual(PlainTextPasteModifier.option.rawValue, "option")
        XCTAssertEqual(PlainTextPasteModifier.control.rawValue, "control")
        XCTAssertEqual(PlainTextPasteModifier.command.rawValue, "command")
    }

    func testModifierIdentifiable() {
        XCTAssertEqual(PlainTextPasteModifier.shift.id, "shift")
        XCTAssertEqual(PlainTextPasteModifier.option.id, "option")
    }

    func testModifierInitFromRawValue() {
        XCTAssertEqual(PlainTextPasteModifier(rawValue: "shift"), .shift)
        XCTAssertEqual(PlainTextPasteModifier(rawValue: "option"), .option)
        XCTAssertEqual(PlainTextPasteModifier(rawValue: "control"), .control)
        XCTAssertEqual(PlainTextPasteModifier(rawValue: "command"), .command)
        XCTAssertNil(PlainTextPasteModifier(rawValue: "invalid"))
    }

    // MARK: - Modifier Flag Checking Tests

    func testShiftModifierFlagContains() {
        let shiftFlags: NSEvent.ModifierFlags = .shift
        let modifier = PlainTextPasteModifier.shift

        XCTAssertTrue(shiftFlags.contains(modifier.modifierFlags))
    }

    func testOptionModifierFlagContains() {
        let optionFlags: NSEvent.ModifierFlags = .option
        let modifier = PlainTextPasteModifier.option

        XCTAssertTrue(optionFlags.contains(modifier.modifierFlags))
    }

    func testControlModifierFlagContains() {
        let controlFlags: NSEvent.ModifierFlags = .control
        let modifier = PlainTextPasteModifier.control

        XCTAssertTrue(controlFlags.contains(modifier.modifierFlags))
    }

    func testCommandModifierFlagContains() {
        let commandFlags: NSEvent.ModifierFlags = .command
        let modifier = PlainTextPasteModifier.command

        XCTAssertTrue(commandFlags.contains(modifier.modifierFlags))
    }

    func testModifierFlagDoesNotMatchOther() {
        let shiftFlags: NSEvent.ModifierFlags = .shift
        let optionModifier = PlainTextPasteModifier.option

        XCTAssertFalse(shiftFlags.contains(optionModifier.modifierFlags))
    }

    func testCombinedModifierFlagsContainsConfigured() {
        // Simulates Shift+Option being pressed
        let combinedFlags: NSEvent.ModifierFlags = [.shift, .option]
        let shiftModifier = PlainTextPasteModifier.shift
        let optionModifier = PlainTextPasteModifier.option
        let controlModifier = PlainTextPasteModifier.control

        XCTAssertTrue(combinedFlags.contains(shiftModifier.modifierFlags))
        XCTAssertTrue(combinedFlags.contains(optionModifier.modifierFlags))
        XCTAssertFalse(combinedFlags.contains(controlModifier.modifierFlags))
    }

    // MARK: - Key Handler Integration Tests

    @MainActor
    func testKeyHandlerUsesConfiguredShiftModifier() async throws {
        // Create a test storage
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBPath = tempDir.appendingPathComponent("test_modifier_\(UUID().uuidString).db").path
        let storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        defer {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }

        // Save an item
        let item = ClipboardItem(
            content: "Test",
            contentType: .text,
            contentHash: "modifier_test_\(UUID().uuidString)",
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        // Set up test
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Test with configured modifier (Shift by default)
        let keyHandler = ConfigurableModifierKeyHandler(viewModel: viewModel)

        var plainTextPasteTriggered = false
        keyHandler.onPlainTextPaste = {
            plainTextPasteTriggered = true
        }

        // Simulate pressing Return with Shift (the default modifier)
        keyHandler.handleKeyDown(keyCode: 36, modifiers: .shift)

        XCTAssertTrue(plainTextPasteTriggered, "Shift+Return should trigger plain text paste when Shift is configured")
    }

    @MainActor
    func testKeyHandlerRespectsOptionModifierWhenConfigured() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBPath = tempDir.appendingPathComponent("test_option_\(UUID().uuidString).db").path
        let storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        defer {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }

        let item = ClipboardItem(
            content: "Test",
            contentType: .text,
            contentHash: "option_test_\(UUID().uuidString)",
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Configure to use Option modifier
        let keyHandler = ConfigurableModifierKeyHandler(viewModel: viewModel)
        keyHandler.configuredModifier = .option

        var plainTextPasteTriggered = false
        var normalPasteTriggered = false

        keyHandler.onPlainTextPaste = {
            plainTextPasteTriggered = true
        }
        keyHandler.onNormalPaste = {
            normalPasteTriggered = true
        }

        // Shift+Return should NOT trigger plain text when Option is configured
        keyHandler.handleKeyDown(keyCode: 36, modifiers: .shift)
        XCTAssertFalse(plainTextPasteTriggered, "Shift+Return should NOT trigger plain text when Option is configured")
        XCTAssertTrue(normalPasteTriggered, "Shift+Return should trigger normal paste when Option is configured")

        // Reset
        plainTextPasteTriggered = false
        normalPasteTriggered = false

        // Option+Return SHOULD trigger plain text
        keyHandler.handleKeyDown(keyCode: 36, modifiers: .option)
        XCTAssertTrue(plainTextPasteTriggered, "Option+Return should trigger plain text when Option is configured")
    }
}

// MARK: - Test Helpers

/// Key handler that respects configurable modifier
@MainActor
class ConfigurableModifierKeyHandler {
    private let viewModel: OverlayViewModel

    /// The configured modifier for plain text paste
    var configuredModifier: PlainTextPasteModifier = .shift

    var onPlainTextPaste: (() -> Void)?
    var onNormalPaste: (() -> Void)?

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    func handleKeyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        switch keyCode {
        case 36: // Return/Enter
            let asPlainText = modifiers.contains(configuredModifier.modifierFlags)
            if asPlainText {
                onPlainTextPaste?()
                viewModel.pasteSelected(asPlainText: true)
            } else {
                onNormalPaste?()
                viewModel.pasteSelected(asPlainText: false)
            }

        default:
            break
        }
    }
}
