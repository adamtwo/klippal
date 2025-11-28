import AppKit
import SwiftUI

/// Window controller for the preferences window
class PreferencesWindowController: NSWindowController {
    static var shared: PreferencesWindowController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "KlipPal Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView())

        // Ensure window appears above other windows
        window.level = .floating

        self.init(window: window)
    }

    static func show() {
        print("📋 PreferencesWindowController.show() called")
        if shared == nil {
            print("📋 Creating new PreferencesWindowController")
            shared = PreferencesWindowController()
        }

        guard let window = shared?.window else {
            print("❌ Window is nil!")
            return
        }

        print("📋 Making window key and ordering front")

        // Reset window level to normal before showing (in case it was changed)
        window.level = .floating

        // Center and show window
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Activate the app to bring it to front
        NSApp.activate(ignoringOtherApps: true)

        // After activation, reset to normal level so it behaves normally
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.level = .normal
        }

        print("📋 Window frame: \(window.frame), isVisible: \(window.isVisible)")
    }
}
