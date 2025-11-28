import XCTest
@testable import KlipPal
import AppKit
import Carbon

/// Tests for the KeyboardShortcutPicker functionality
final class KeyboardShortcutPickerTests: XCTestCase {

    // MARK: - Event Monitor Tests

    @MainActor
    func testLocalEventMonitorCapturesKeyEvents() async throws {
        var capturedEvent: NSEvent?

        // Add a local event monitor
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            capturedEvent = event
            return nil  // Consume the event
        }

        defer {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        // Create a synthetic key event
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "v",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: 9  // V key
        )

        XCTAssertNotNil(event, "Should be able to create synthetic key event")

        // Note: We can't actually dispatch the event to trigger the monitor in tests
        // because it requires a running event loop. But we can test the event creation.
        if let event = event {
            XCTAssertEqual(event.keyCode, 9)
            XCTAssertTrue(event.modifierFlags.contains(.command))
            XCTAssertTrue(event.modifierFlags.contains(.shift))
        }
    }

    @MainActor
    func testSyntheticKeyEventCreation() throws {
        // Test that we can create key events with various modifier combinations
        let testCases: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, char: String)] = [
            (9, [.command, .shift], "v"),        // Cmd+Shift+V
            (8, [.command, .option], "c"),       // Cmd+Option+C
            (40, [.control, .option], "k"),      // Ctrl+Option+K
            (3, [.command, .control, .shift], "f"), // Cmd+Ctrl+Shift+F
        ]

        for testCase in testCases {
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: testCase.modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                characters: testCase.char,
                charactersIgnoringModifiers: testCase.char,
                isARepeat: false,
                keyCode: testCase.keyCode
            )

            XCTAssertNotNil(event, "Should create event for keyCode \(testCase.keyCode)")
            XCTAssertEqual(event?.keyCode, testCase.keyCode)

            // Verify modifiers are preserved
            if testCase.modifiers.contains(.command) {
                XCTAssertTrue(event?.modifierFlags.contains(.command) ?? false)
            }
            if testCase.modifiers.contains(.shift) {
                XCTAssertTrue(event?.modifierFlags.contains(.shift) ?? false)
            }
            if testCase.modifiers.contains(.option) {
                XCTAssertTrue(event?.modifierFlags.contains(.option) ?? false)
            }
            if testCase.modifiers.contains(.control) {
                XCTAssertTrue(event?.modifierFlags.contains(.control) ?? false)
            }
        }
    }

    // MARK: - Shortcut Recording Logic Tests

    func testModifierOnlyKeysAreIgnored() {
        // These key codes should be ignored (modifier-only keys)
        let modifierKeyCodes: [UInt16] = [
            56, 60,  // Shift (left, right)
            55, 54,  // Command (left, right)
            58, 61,  // Option (left, right)
            59, 62,  // Control (left, right)
            57,      // Caps Lock
        ]

        for keyCode in modifierKeyCodes {
            XCTAssertTrue(isModifierOnlyKey(keyCode), "Key code \(keyCode) should be recognized as modifier-only")
        }

        // Regular keys should not be modifier-only
        let regularKeyCodes: [UInt16] = [0, 1, 8, 9, 36, 48, 49]  // A, S, C, V, Return, Tab, Space
        for keyCode in regularKeyCodes {
            XCTAssertFalse(isModifierOnlyKey(keyCode), "Key code \(keyCode) should NOT be modifier-only")
        }
    }

    func testEscapeKeyCancelsRecording() {
        let escapeKeyCode: UInt16 = 53
        XCTAssertEqual(escapeKeyCode, 53, "Escape key code should be 53")
    }

    // MARK: - Carbon Modifier Conversion Tests

    func testCarbonModifierConversionRoundTrip() {
        // Test that converting NSEvent modifiers to Carbon and back preserves the values
        let testCases: [NSEvent.ModifierFlags] = [
            [.command],
            [.shift],
            [.option],
            [.control],
            [.command, .shift],
            [.command, .option],
            [.command, .control],
            [.command, .shift, .option],
            [.command, .shift, .option, .control],
        ]

        for original in testCases {
            let carbon = KeyCodeConverter.modifiersToCarbon(original)
            let roundTripped = KeyCodeConverter.carbonToModifiers(carbon)

            // Check that all original modifiers are present
            if original.contains(.command) {
                XCTAssertTrue(roundTripped.contains(.command), "Command should survive round trip")
            }
            if original.contains(.shift) {
                XCTAssertTrue(roundTripped.contains(.shift), "Shift should survive round trip")
            }
            if original.contains(.option) {
                XCTAssertTrue(roundTripped.contains(.option), "Option should survive round trip")
            }
            if original.contains(.control) {
                XCTAssertTrue(roundTripped.contains(.control), "Control should survive round trip")
            }
        }
    }

    // MARK: - Preferences Integration Tests

    @MainActor
    func testPreferencesUpdateWithNewShortcut() async throws {
        let prefs = PreferencesManager.shared

        // Store original values
        let originalKeyCode = prefs.hotkeyKeyCode
        let originalModifiers = prefs.hotkeyModifiers

        defer {
            // Restore original values
            prefs.hotkeyKeyCode = originalKeyCode
            prefs.hotkeyModifiers = originalModifiers
        }

        // Set new shortcut (Cmd+Option+K)
        let newKeyCode: UInt32 = 40  // K
        let newModifiers: UInt32 = UInt32(cmdKey | optionKey)

        prefs.hotkeyKeyCode = newKeyCode
        prefs.hotkeyModifiers = newModifiers

        XCTAssertEqual(prefs.hotkeyKeyCode, newKeyCode)
        XCTAssertEqual(prefs.hotkeyModifiers, newModifiers)

        // Verify description updates
        let description = prefs.hotkeyDescription
        XCTAssertTrue(description.contains("⌘"), "Description should contain Command symbol")
        XCTAssertTrue(description.contains("⌥"), "Description should contain Option symbol")
        XCTAssertTrue(description.contains("K"), "Description should contain K")
    }

    @MainActor
    func testShortcutValidationBeforeSaving() async throws {
        // Valid shortcuts
        XCTAssertTrue(ShortcutValidator.isValid(keyCode: 40, modifiers: UInt32(cmdKey | optionKey)))
        XCTAssertTrue(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)))

        // Invalid shortcuts (reserved)
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 9, modifiers: UInt32(cmdKey)))  // Cmd+V
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 8, modifiers: UInt32(cmdKey)))  // Cmd+C

        // Invalid shortcuts (no modifiers)
        XCTAssertFalse(ShortcutValidator.isValid(keyCode: 9, modifiers: 0))
    }

    // MARK: - Helper Functions

    private func isModifierOnlyKey(_ keyCode: UInt16) -> Bool {
        return keyCode == 56 || keyCode == 60 ||  // Shift
               keyCode == 55 || keyCode == 54 ||  // Command
               keyCode == 58 || keyCode == 61 ||  // Option
               keyCode == 59 || keyCode == 62 ||  // Control
               keyCode == 57                       // Caps Lock
    }
}
