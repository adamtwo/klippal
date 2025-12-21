import AppKit
import Foundation
import ApplicationServices

/// Application delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    var storage: SQLiteStorageEngine?
    private var clipboardMonitor: ClipboardMonitor?
    private var statusBarController: StatusBarController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        print("KlipPal starting...")

        // Request accessibility permissions if not already granted
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("Requesting accessibility permissions...")
            // This will prompt the user to grant permissions
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        } else {
            print("Accessibility permissions already granted")
        }

        // IMPORTANT: Initialize UI components FIRST, synchronously on main thread
        // This ensures menu bar and hotkey are ready immediately
        statusBarController = StatusBarController()
        print("Menu bar icon created")

        // Register global hotkey (from preferences, defaults to Cmd+Shift+V)
        hotKeyManager = GlobalHotKeyManager()
        let prefs = PreferencesManager.shared
        let success = hotKeyManager?.registerHotKey(
            keyCode: UInt32(prefs.hotkeyKeyCode),
            modifiers: UInt32(prefs.hotkeyModifiers)
        ) { [weak self] in
            self?.statusBarController?.toggleOverlay()
        }

        if success == true {
            print("Global hotkey registered (\(prefs.hotkeyDescription))")
        } else {
            print("Failed to register global hotkey - you may need accessibility permissions")
        }

        // Set up storage paths
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDirectory = appSupport.appendingPathComponent("KlipPal", isDirectory: true)
        let dbPath = appDirectory.appendingPathComponent("clipboard.db").path

        // Initialize storage asynchronously
        Task {
            do {
                storage = try await SQLiteStorageEngine(dbPath: dbPath)
                print("Storage initialized")

                // Print storage location
                print("Database: \(dbPath)")

                // Initialize and start clipboard monitoring on main actor
                await MainActor.run {
                    if let storage = storage {
                        clipboardMonitor = ClipboardMonitor(storage: storage)
                        clipboardMonitor?.startMonitoring()
                    }
                }

                // Print current item count
                if let storage = storage {
                    let count = try await storage.count()
                    print("Current clipboard history: \(count) items")
                }

                print("KlipPal ready!")
                print("Press Cmd+Shift+V to open overlay, or click menu bar icon")

            } catch {
                print("Failed to initialize storage: \(error)")
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("KlipPal stopping...")
        clipboardMonitor?.stopMonitoring()
    }

    /// Re-register the global hotkey with updated settings from preferences
    @MainActor
    func reregisterHotKey() {
        let prefs = PreferencesManager.shared
        let success = hotKeyManager?.reregister(
            keyCode: prefs.hotkeyKeyCode,
            modifiers: prefs.hotkeyModifiers
        )

        if success == true {
            print("Global hotkey re-registered (\(prefs.hotkeyDescription))")
        } else {
            print("Failed to re-register global hotkey")
        }
    }
}
