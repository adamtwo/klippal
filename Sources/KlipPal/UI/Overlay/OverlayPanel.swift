import AppKit

/// Custom NSPanel subclass that handles keyboard navigation for the overlay
class OverlayPanel: NSPanel {
    /// Reference to the view model for handling navigation actions
    weak var viewModel: OverlayViewModel?

    /// Callback for when the panel should close
    var onClose: (() -> Void)?

    // MARK: - Key Codes

    private enum KeyCode: UInt16 {
        case downArrow = 125
        case upArrow = 126
        case leftArrow = 123
        case rightArrow = 124
        case returnKey = 36
        case escape = 53
        case tab = 48
        // Edit command keys
        case a = 0      // Cmd+A: Select All
        case c = 8      // Cmd+C: Copy
        case v = 9      // Cmd+V: Paste
        case x = 7      // Cmd+X: Cut
        case z = 6      // Cmd+Z: Undo
    }

    /// Edit command keys that should pass through to TextField when Cmd is held
    private static let editCommandKeys: Set<UInt16> = [
        KeyCode.a.rawValue,
        KeyCode.c.rawValue,
        KeyCode.v.rawValue,
        KeyCode.x.rawValue,
        KeyCode.z.rawValue,
    ]

    /// Horizontal arrow keys for cursor movement in TextField
    private static let horizontalArrowKeys: Set<UInt16> = [
        KeyCode.leftArrow.rawValue,
        KeyCode.rightArrow.rawValue,
    ]

    // MARK: - Responder Chain

    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Event Handling

    /// Override sendEvent to intercept key events before they reach the TextField
    /// This is necessary because the focused TextField would otherwise consume
    /// arrow keys and escape before they reach keyDown(with:)
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if handleKeyEvent(event) {
                return // Event was handled, don't pass to super
            }
        }
        super.sendEvent(event)
    }

    /// Handle key equivalents (Cmd+key shortcuts) for edit commands
    /// This ensures edit commands work even without an Edit menu
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        // For edit commands with Cmd modifier, send standard actions through the responder chain
        if modifiers.contains(.command) && Self.editCommandKeys.contains(keyCode) {
            let action: Selector?
            switch keyCode {
            case KeyCode.a.rawValue: // Cmd+A: Select All
                action = #selector(NSText.selectAll(_:))
            case KeyCode.c.rawValue: // Cmd+C: Copy
                action = #selector(NSText.copy(_:))
            case KeyCode.v.rawValue: // Cmd+V: Paste
                action = #selector(NSText.paste(_:))
            case KeyCode.x.rawValue: // Cmd+X: Cut
                action = #selector(NSText.cut(_:))
            case KeyCode.z.rawValue: // Cmd+Z: Undo
                action = Selector(("undo:"))
            default:
                action = nil
            }

            if let action = action {
                // Send action through the responder chain - this is how menu items work
                if NSApp.sendAction(action, to: nil, from: self) {
                    return true
                }
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    /// Handles key events for navigation
    /// Returns true if the event was handled and should not be passed on
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        // Allow edit commands (Cmd+A/C/V/X/Z) to pass through to TextField
        if modifiers.contains(.command) && Self.editCommandKeys.contains(keyCode) {
            return false
        }

        // Allow horizontal arrow keys to pass through for cursor movement in TextField
        // This includes plain arrows, Shift+arrows (selection), Cmd+arrows (jump to start/end),
        // and Option+arrows (word movement)
        if Self.horizontalArrowKeys.contains(keyCode) {
            return false
        }

        guard let key = KeyCode(rawValue: keyCode) else {
            return false
        }

        switch key {
        case .downArrow:
            handleDownArrow()
            return true

        case .upArrow:
            handleUpArrow()
            return true

        case .escape:
            handleEscape()
            return true

        case .returnKey:
            // Let Return pass through to TextField's onSubmit
            // unless we want to handle it here directly
            handleReturn()
            return true

        case .tab:
            // Let tab work normally for focus navigation
            return false

        default:
            // All other keys (including edit command keys) pass through
            return false
        }
    }

    // MARK: - Key Handlers

    private func handleDownArrow() {
        guard let viewModel = viewModel else { return }
        Task { @MainActor in
            viewModel.selectNext()
        }
    }

    private func handleUpArrow() {
        guard let viewModel = viewModel else { return }
        Task { @MainActor in
            viewModel.selectPrevious()
        }
    }

    private func handleReturn() {
        guard let viewModel = viewModel else { return }
        Task { @MainActor in
            viewModel.pasteSelected()
        }
    }

    private func handleEscape() {
        onClose?()
    }
}
