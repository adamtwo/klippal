import AppKit

// Single-instance guard: if another KlipPal is already running, exit immediately.
// Handles cases where both LaunchAgent and SMAppService fire simultaneously at login,
// or where launchctl unload fails to kill an existing instance before a new one starts.
let others = NSRunningApplication.runningApplications(withBundleIdentifier: "com.klippal.app")
    .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
if !others.isEmpty {
    print("KlipPal already running (pid \(others[0].processIdentifier)), exiting.")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
