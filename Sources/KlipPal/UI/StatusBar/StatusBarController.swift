import AppKit
import SwiftUI
import Combine

/// Manages the menu bar status item
/// Note: This class intentionally does NOT use @MainActor because NSMenu action dispatch
/// doesn't work well with MainActor isolation. Instead, we dispatch to main manually where needed.
class StatusBarController: NSObject, NSMenuDelegate {
    private(set) var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindowController?
    private(set) var menu: NSMenu?  // Exposed for testing
    private var cancellables = Set<AnyCancellable>()

    /// Track if preferences was opened (for testing)
    private(set) var preferencesOpenedCount: Int = 0

    /// Track if clipboard history was opened (for testing)
    private(set) var clipboardHistoryOpenedCount: Int = 0

    override init() {
        super.init()
        setupStatusItem()
        observePreferences()
    }

    /// Pre-create the overlay window controller with pre-loaded items
    /// Called after storage is initialized
    func preloadOverlay(with items: [ClipboardItem] = []) {
        if overlayWindow == nil {
            overlayWindow = OverlayWindowController(preloadedItems: items)
        }
    }

    private func observePreferences() {
        // Observe showMenuBarIcon preference changes
        DispatchQueue.main.async { [weak self] in
            PreferencesManager.shared.$showMenuBarIcon
                .dropFirst() // Skip initial value since we handle it in setupStatusItem
                .receive(on: DispatchQueue.main)
                .sink { [weak self] show in
                    self?.updateVisibility(show: show)
                }
                .store(in: &self!.cancellables)
        }
    }

    private func updateVisibility(show: Bool) {
        if show {
            if statusItem == nil {
                createStatusItem()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
                menu = nil
            }
        }
    }

    private func setupStatusItem() {
        // Check preference synchronously - must be on main thread
        DispatchQueue.main.async { [weak self] in
            guard PreferencesManager.shared.showMenuBarIcon else { return }
            self?.createStatusItem()
        }
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Custom "Kᵖ" text icon for KlipPal branding
        button.title = "Kᵖ"
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.image = nil
        button.setAccessibilityLabel("KlipPal Clipboard Manager")

        // Set up menu
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // Open Clipboard History item
        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(openClipboardHistory), keyEquivalent: "")
        openItem.target = self
        openItem.isEnabled = true
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences item
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        prefsItem.isEnabled = true
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // About item
        let aboutItem = NSMenuItem(title: "About KlipPal", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)

        // Quit item - use NSApp.terminate which always works
        let quitItem = NSMenuItem(title: "Quit KlipPal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = nil  // nil target sends to first responder / NSApp
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu

        print("📋 Menu setup complete with \(menu.items.count) items")
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        print("📋 Menu will open - items: \(menu.items.map { $0.title })")
        // Verify target is still valid
        for item in menu.items {
            if let target = item.target {
                print("📋   Item '\(item.title)' target: \(type(of: target)), action: \(String(describing: item.action))")
            } else {
                print("📋   Item '\(item.title)' target: nil (responder chain), action: \(String(describing: item.action))")
            }
        }
    }

    // MARK: - Menu Actions

    @objc func openClipboardHistory() {
        print("📋 openClipboardHistory called")
        preferencesOpenedCount += 1
        DispatchQueue.main.async { [weak self] in
            self?.showOverlay()
        }
    }

    @objc func openPreferences() {
        print("📋 openPreferences called")
        preferencesOpenedCount += 1
        DispatchQueue.main.async {
            PreferencesWindowController.show()
        }
    }

    @objc func openAbout() {
        print("📋 openAbout called")
        DispatchQueue.main.async {
            PreferencesWindowController.show(category: .about)
        }
    }

    func toggleOverlay() {
        if let overlayWindow = overlayWindow, overlayWindow.isVisible {
            overlayWindow.closeWindow()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        if overlayWindow == nil {
            overlayWindow = OverlayWindowController()
        }

        overlayWindow?.showWindow()
    }

    func hideOverlay() {
        overlayWindow?.closeWindow()
    }
}
