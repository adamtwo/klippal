import AppKit
import SwiftUI

/// Window controller for the preferences window
class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static var shared: PreferencesWindowController?

    convenience init(initialCategory: SettingsCategory = .general) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "KlipPal Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView(initialCategory: initialCategory))

        self.init(window: window)

        // Set delegate to handle window events
        window.delegate = self
    }

    static func show(category: SettingsCategory = .general) {
        if shared == nil {
            shared = PreferencesWindowController(initialCategory: category)
        } else if let window = shared?.window {
            // Update the content view to show the requested category
            window.contentView = NSHostingView(rootView: PreferencesView(initialCategory: category))
        }

        guard let window = shared?.window else { return }

        // Center window
        window.center()

        // Set floating level temporarily to ensure it appears above other windows
        window.level = .floating

        // CRITICAL: Switch to regular activation policy for proper keyboard input
        // This allows text fields in child windows to receive keyboard events
        NSApp.setActivationPolicy(.regular)

        // Activate the app and show window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Reset to normal level after a short delay so it behaves like a normal window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.level = .normal
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure app stays active when window becomes key
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Restore accessory activation policy when preferences window closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
        Self.shared = nil
    }
}
