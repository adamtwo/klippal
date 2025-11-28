import SwiftUI
import AppKit
import Carbon

/// A SwiftUI view for capturing and displaying a keyboard shortcut
struct KeyboardShortcutPicker: View {
    @ObservedObject var preferences: PreferencesManager
    @State private var isRecording = false
    @State private var errorMessage: String?
    @StateObject private var recorder = ShortcutRecorder()

    /// Check if current shortcut is the default
    private var isDefaultShortcut: Bool {
        preferences.hotkeyKeyCode == ShortcutValidator.defaultKeyCode &&
        preferences.hotkeyModifiers == ShortcutValidator.defaultModifiers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keyboard shortcut:")
                Spacer()

                if isRecording {
                    Text("Press keys...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                } else {
                    Text(preferences.hotkeyDescription)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                Button(isRecording ? "Cancel" : "Change") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.bordered)

                if !isDefaultShortcut && !isRecording {
                    Button("Reset") {
                        resetToDefault()
                    }
                    .buttonStyle(.bordered)
                    .help("Reset to default shortcut (⌘⇧V)")
                }
            }
            .help("Press this shortcut to open the clipboard overlay")

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onReceive(recorder.$recordedShortcut) { shortcut in
            if let shortcut = shortcut {
                handleShortcut(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
            }
        }
        .onReceive(recorder.$cancelled) { cancelled in
            if cancelled {
                stopRecording()
            }
        }
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true
        recorder.startRecording()
        print("📋 Started recording keyboard shortcut")
    }

    private func stopRecording() {
        recorder.stopRecording()
        isRecording = false
        print("📋 Stopped recording keyboard shortcut")
    }

    private func resetToDefault() {
        errorMessage = nil
        preferences.hotkeyKeyCode = ShortcutValidator.defaultKeyCode
        preferences.hotkeyModifiers = ShortcutValidator.defaultModifiers

        print("📋 Reset shortcut to default: ⌘⇧V")

        // Re-register the hotkey
        if let appDelegate = AppDelegate.shared {
            appDelegate.reregisterHotKey()
        }
    }

    private func handleShortcut(keyCode: UInt32, modifiers: UInt32) {
        // Validate the shortcut
        if !ShortcutValidator.isValid(keyCode: keyCode, modifiers: modifiers) {
            if let message = ShortcutValidator.reservedShortcutMessage(keyCode: keyCode, modifiers: modifiers) {
                errorMessage = message
            } else {
                errorMessage = "Invalid shortcut. Use at least Command, Control, or Option with a key."
            }
            stopRecording()
            return
        }

        // Valid shortcut - save it
        errorMessage = nil
        preferences.hotkeyKeyCode = keyCode
        preferences.hotkeyModifiers = modifiers

        let description = KeyCodeConverter.shortcutDescription(keyCode: keyCode, modifiers: modifiers)
        print("📋 Recorded shortcut: \(description)")

        // Re-register the hotkey
        if let appDelegate = AppDelegate.shared {
            appDelegate.reregisterHotKey()
        }

        stopRecording()
    }
}

/// Separate class to handle shortcut recording with proper event monitoring
class ShortcutRecorder: ObservableObject {
    struct RecordedShortcut {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    @Published var recordedShortcut: RecordedShortcut?
    @Published var cancelled = false

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func startRecording() {
        recordedShortcut = nil
        cancelled = false

        // Activate our app to ensure we receive events
        NSApp.activate(ignoringOtherApps: true)

        // Use both local AND global monitors to capture all key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil  // Consume the event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        print("📋 Event monitors installed")
    }

    func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        print("📋 Event monitors removed")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode

        // Ignore modifier-only key presses
        if isModifierOnlyKey(keyCode) {
            return
        }

        // Escape cancels recording
        if keyCode == 53 {
            DispatchQueue.main.async {
                self.cancelled = true
            }
            return
        }

        // Get modifier flags and convert to Carbon
        let modifiers = event.modifierFlags
        let carbonModifiers = KeyCodeConverter.modifiersToCarbon(modifiers)

        print("📋 Key event: keyCode=\(keyCode), modifiers=\(carbonModifiers)")

        DispatchQueue.main.async {
            self.recordedShortcut = RecordedShortcut(keyCode: UInt32(keyCode), modifiers: carbonModifiers)
        }
    }

    private func isModifierOnlyKey(_ keyCode: UInt16) -> Bool {
        return keyCode == 56 || keyCode == 60 ||  // Shift
               keyCode == 55 || keyCode == 54 ||  // Command
               keyCode == 58 || keyCode == 61 ||  // Option
               keyCode == 59 || keyCode == 62 ||  // Control
               keyCode == 57                       // Caps Lock
    }

    deinit {
        stopRecording()
    }
}
