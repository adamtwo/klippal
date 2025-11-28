import XCTest
@testable import KlipPal
import Carbon

/// Tests for keyboard shortcut functionality
final class KeyboardShortcutTests: XCTestCase {

    // MARK: - KeyCodeConverter Tests

    func testKeyCodeToStringForLetters() {
        // Test common letter keys
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(0), "A")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(9), "V")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(8), "C")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(7), "X")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(6), "Z")
    }

    func testKeyCodeToStringForNumbers() {
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(18), "1")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(19), "2")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(20), "3")
    }

    func testKeyCodeToStringForSpecialKeys() {
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(49), "Space")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(36), "↩")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(51), "⌫")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(53), "⎋")
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(48), "⇥")
    }

    func testKeyCodeToStringForUnknownKey() {
        XCTAssertEqual(KeyCodeConverter.keyCodeToString(999), "?")
    }

    // MARK: - Modifier Tests

    func testModifierSymbols() {
        // Command
        XCTAssertEqual(KeyCodeConverter.modifierSymbol(for: .command), "⌘")
        // Shift
        XCTAssertEqual(KeyCodeConverter.modifierSymbol(for: .shift), "⇧")
        // Option
        XCTAssertEqual(KeyCodeConverter.modifierSymbol(for: .option), "⌥")
        // Control
        XCTAssertEqual(KeyCodeConverter.modifierSymbol(for: .control), "⌃")
    }

    func testModifiersToCarbon() {
        // Command only
        let cmdFlags = NSEvent.ModifierFlags.command
        let cmdCarbon = KeyCodeConverter.modifiersToCarbon(cmdFlags)
        XCTAssertEqual(cmdCarbon, UInt32(cmdKey))

        // Shift only
        let shiftFlags = NSEvent.ModifierFlags.shift
        let shiftCarbon = KeyCodeConverter.modifiersToCarbon(shiftFlags)
        XCTAssertEqual(shiftCarbon, UInt32(shiftKey))

        // Command + Shift (default hotkey)
        let cmdShiftFlags: NSEvent.ModifierFlags = [.command, .shift]
        let cmdShiftCarbon = KeyCodeConverter.modifiersToCarbon(cmdShiftFlags)
        XCTAssertEqual(cmdShiftCarbon, UInt32(cmdKey | shiftKey))

        // Command + Option
        let cmdOptFlags: NSEvent.ModifierFlags = [.command, .option]
        let cmdOptCarbon = KeyCodeConverter.modifiersToCarbon(cmdOptFlags)
        XCTAssertEqual(cmdOptCarbon, UInt32(cmdKey | optionKey))
    }

    func testCarbonToModifiers() {
        // Command only
        let cmdModifiers = KeyCodeConverter.carbonToModifiers(UInt32(cmdKey))
        XCTAssertTrue(cmdModifiers.contains(.command))
        XCTAssertFalse(cmdModifiers.contains(.shift))

        // Command + Shift
        let cmdShiftModifiers = KeyCodeConverter.carbonToModifiers(UInt32(cmdKey | shiftKey))
        XCTAssertTrue(cmdShiftModifiers.contains(.command))
        XCTAssertTrue(cmdShiftModifiers.contains(.shift))
        XCTAssertFalse(cmdShiftModifiers.contains(.option))
    }

    // MARK: - Shortcut Description Tests

    func testShortcutDescription() {
        // Cmd+Shift+V (default)
        let desc1 = KeyCodeConverter.shortcutDescription(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertTrue(desc1.contains("⌘"), "Should contain Command symbol")
        XCTAssertTrue(desc1.contains("⇧"), "Should contain Shift symbol")
        XCTAssertTrue(desc1.contains("V"), "Should contain V key")

        // Cmd+Option+C
        let desc2 = KeyCodeConverter.shortcutDescription(keyCode: 8, modifiers: UInt32(cmdKey | optionKey))
        XCTAssertTrue(desc2.contains("⌘"), "Should contain Command symbol")
        XCTAssertTrue(desc2.contains("⌥"), "Should contain Option symbol")
        XCTAssertTrue(desc2.contains("C"), "Should contain C key")
    }

    // MARK: - Shortcut Validation Tests

    func testValidShortcuts() {
        // Cmd+Shift+V - valid
        XCTAssertTrue(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)))

        // Cmd+Option+V - valid
        XCTAssertTrue(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey | optionKey)))

        // Cmd+Ctrl+V - valid
        XCTAssertTrue(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey | controlKey)))
    }

    func testInvalidShortcuts() {
        // No modifiers - invalid
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 9, modifiers: 0))

        // Shift only - invalid (not enough)
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(shiftKey)))

        // Cmd+C (system copy) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 8, modifiers: UInt32(cmdKey)))

        // Cmd+V (system paste) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey)))

        // Cmd+X (system cut) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 7, modifiers: UInt32(cmdKey)))

        // Cmd+Q (quit) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 12, modifiers: UInt32(cmdKey)))

        // Cmd+W (close window) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 13, modifiers: UInt32(cmdKey)))

        // Cmd+Tab (app switch) - reserved
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 48, modifiers: UInt32(cmdKey)))
    }

    func testReservedShortcutMessage() {
        // Cmd+V should return appropriate message
        let message = ShortcutValidator.reservedShortcutMessage(keyCode: 9, modifiers: UInt32(cmdKey))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("paste") == true || message?.contains("reserved") == true)
    }

    // MARK: - KeyboardShortcut Model Tests

    func testKeyboardShortcutInit() {
        let shortcut = KeyboardShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(shortcut.keyCode, 9)
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(cmdKey | shiftKey))
    }

    func testKeyboardShortcutDescription() {
        let shortcut = KeyboardShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        let desc = shortcut.description
        XCTAssertTrue(desc.contains("⌘"))
        XCTAssertTrue(desc.contains("⇧"))
        XCTAssertTrue(desc.contains("V"))
    }

    func testKeyboardShortcutEquality() {
        let shortcut1 = KeyboardShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        let shortcut2 = KeyboardShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        let shortcut3 = KeyboardShortcut(keyCode: 8, modifiers: UInt32(cmdKey | shiftKey))

        XCTAssertEqual(shortcut1, shortcut2)
        XCTAssertNotEqual(shortcut1, shortcut3)
    }

    func testKeyboardShortcutDefault() {
        let defaultShortcut = KeyboardShortcut.default
        XCTAssertEqual(defaultShortcut.keyCode, 9)  // V
        XCTAssertEqual(defaultShortcut.carbonModifiers, UInt32(cmdKey | shiftKey))
    }
}
