import AppKit
import SwiftUI

/// Controls the overlay window (floating panel)
class OverlayWindowController: NSWindowController {
    private var overlayPanel: OverlayPanel?
    private var viewModel: OverlayViewModel?
    private var previousApp: NSRunningApplication?

    // UserDefaults keys for persisting window size
    private static let windowWidthKey = "overlayWindowWidth"
    private static let windowHeightKey = "overlayWindowHeight"

    // Default and constraint sizes
    private static let defaultWidth: CGFloat = 600
    private static let defaultHeight: CGFloat = 400
    private static let minWidth: CGFloat = 400
    private static let minHeight: CGFloat = 300
    private static let maxWidth: CGFloat = 1200
    private static let maxHeight: CGFloat = 800

    init(preloadedItems: [ClipboardItem] = []) {
        // Load saved size or use defaults
        let savedWidth = UserDefaults.standard.double(forKey: Self.windowWidthKey)
        let savedHeight = UserDefaults.standard.double(forKey: Self.windowHeightKey)

        let width = savedWidth > 0 ? CGFloat(savedWidth) : Self.defaultWidth
        let height = savedHeight > 0 ? CGFloat(savedHeight) : Self.defaultHeight

        // Create the custom panel with keyboard handling
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.isOpaque = true
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        // Set size constraints
        panel.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        panel.maxSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)

        self.overlayPanel = panel
        super.init(window: panel)

        // Set delegate to track window size changes
        panel.delegate = self

        // Create view model with pre-loaded items and set content view to SwiftUI
        Task { @MainActor in
            self.viewModel = OverlayViewModel(preloadedItems: preloadedItems)

            // Connect panel to view model for keyboard navigation
            panel.viewModel = self.viewModel

            // Set callback to close window and restore previous app before paste
            self.viewModel?.onBeforePaste = { [weak self] in
                self?.closeWindow()
                self?.restorePreviousApp()
            }

            // Set callback to close window
            self.viewModel?.onCloseWindow = { [weak self] in
                self?.closeWindow()
            }

            // Set panel's close callback to also restore previous app
            panel.onClose = { [weak self] in
                self?.closeWindow()
                self?.restorePreviousApp()
            }

            let contentView = OverlayView(viewModel: self.viewModel!)
            panel.contentView = NSHostingView(rootView: contentView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        guard let panel = overlayPanel else { return }

        // Store the currently active application before showing overlay
        previousApp = NSWorkspace.shared.frontmostApplication
        if let app = previousApp {
            print("📱 Stored previous app: \(app.localizedName ?? "unknown")")
        }

        // Reset selection to first item when showing
        Task { @MainActor in
            viewModel?.selectedIndex = 0
            viewModel?.loadItems()
        }

        // Position at cursor or center of screen
        if let screen = NSScreen.main {
            let mouseLocation = NSEvent.mouseLocation
            var origin = mouseLocation

            // Adjust to ensure window is fully visible
            let windowSize = panel.frame.size
            let screenFrame = screen.visibleFrame

            if origin.x + windowSize.width > screenFrame.maxX {
                origin.x = screenFrame.maxX - windowSize.width
            }
            if origin.y - windowSize.height < screenFrame.minY {
                origin.y = screenFrame.minY + windowSize.height
            }

            panel.setFrameTopLeftPoint(origin)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func restorePreviousApp() {
        if let app = previousApp {
            print("📱 Restoring previous app: \(app.localizedName ?? "unknown")")
            app.activate(options: .activateIgnoringOtherApps)
        } else {
            print("⚠️ No previous app to restore")
        }
    }

    func closeWindow() {
        overlayPanel?.close()
    }

    var isVisible: Bool {
        overlayPanel?.isVisible ?? false
    }

    /// Save the current window size to UserDefaults
    private func saveWindowSize() {
        guard let panel = overlayPanel else { return }
        let size = panel.frame.size
        UserDefaults.standard.set(Double(size.width), forKey: Self.windowWidthKey)
        UserDefaults.standard.set(Double(size.height), forKey: Self.windowHeightKey)
    }
}

// MARK: - NSWindowDelegate

extension OverlayWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        saveWindowSize()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveWindowSize()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Close the overlay when it loses focus
        closeWindow()
    }
}
