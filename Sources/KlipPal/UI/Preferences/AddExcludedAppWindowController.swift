import AppKit
import SwiftUI

/// Window controller for the Add Excluded App window
/// Works alongside PreferencesWindowController which manages the activation policy
class AddExcludedAppWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: AddExcludedAppWindowController?
    private var excludedAppsManager: ExcludedAppsManager?
    private var onDismiss: (() -> Void)?

    static func show(excludedAppsManager: ExcludedAppsManager, onDismiss: @escaping () -> Void) {
        // Close existing window if any
        shared?.close()

        let controller = AddExcludedAppWindowController(excludedAppsManager: excludedAppsManager, onDismiss: onDismiss)
        shared = controller

        guard let window = controller.window else { return }

        // Position relative to preferences window if available
        if let prefsWindow = PreferencesWindowController.shared?.window {
            let prefsFrame = prefsWindow.frame
            let x = prefsFrame.midX - window.frame.width / 2
            let y = prefsFrame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        // Note: Activation policy is already set to .regular by PreferencesWindowController
        // Activate and show
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private init(excludedAppsManager: ExcludedAppsManager, onDismiss: @escaping () -> Void) {
        self.excludedAppsManager = excludedAppsManager
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Add Excluded App"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self

        // Create the SwiftUI view with dismiss callback
        let contentView = AddExcludedAppContent(
            excludedAppsManager: excludedAppsManager,
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        window.contentView = NSHostingView(rootView: contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func close() {
        window?.close()

        // Return focus to the preferences window
        if let prefsWindow = PreferencesWindowController.shared?.window {
            prefsWindow.makeKeyAndOrderFront(nil)
        }

        onDismiss?()
        Self.shared = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Return focus to the preferences window
        if let prefsWindow = PreferencesWindowController.shared?.window {
            prefsWindow.makeKeyAndOrderFront(nil)
        }

        onDismiss?()
        Self.shared = nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// SwiftUI content for the Add Excluded App window
struct AddExcludedAppContent: View {
    @ObservedObject var excludedAppsManager: ExcludedAppsManager
    let onDismiss: () -> Void

    @State private var selectedTab = 0
    @State private var selectedApps: Set<String> = []
    @State private var manualAppName = ""
    @State private var runningApps: [String] = []
    @State private var focusedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Running Apps").tag(0)
                Text("Enter Name").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Tab content
            if selectedTab == 0 {
                RunningAppsContentView(
                    runningApps: runningApps,
                    selectedApps: $selectedApps,
                    focusedIndex: $focusedIndex
                )
            } else {
                ManualEntryContentView(appName: $manualAppName)
            }

            Divider()

            // Bottom buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(addButtonTitle) {
                    addSelectedApps()
                    onDismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
        .onAppear {
            refreshRunningApps()
        }
    }

    private var addButtonTitle: String {
        if selectedTab == 0 {
            if selectedApps.count > 1 {
                return "Add All (\(selectedApps.count))"
            }
            return "Add"
        }
        return "Add"
    }

    private var canAdd: Bool {
        if selectedTab == 0 {
            return !selectedApps.isEmpty
        } else {
            return !manualAppName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func refreshRunningApps() {
        runningApps = excludedAppsManager.getRunningAppsNotExcluded()
    }

    private func addSelectedApps() {
        if selectedTab == 0 {
            excludedAppsManager.addApps(names: Array(selectedApps))
        } else {
            let trimmedName = manualAppName.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty {
                excludedAppsManager.addApp(name: trimmedName)
            }
        }
    }
}

// MARK: - Running Apps Content View

struct RunningAppsContentView: View {
    let runningApps: [String]
    @Binding var selectedApps: Set<String>
    @Binding var focusedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            if runningApps.isEmpty {
                Spacer()
                Text("No apps available to add")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(runningApps.enumerated()), id: \.element) { index, appName in
                            RunningAppRow(
                                appName: appName,
                                isSelected: selectedApps.contains(appName),
                                isFocused: focusedIndex == index,
                                onTap: { modifiers in
                                    handleTap(appName: appName, index: index, modifiers: modifiers)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(NSColor.textBackgroundColor))
            }

            // Helper text
            Text("Click to select. ⌘-click to select multiple.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.vertical, 6)
        }
    }

    private func handleTap(appName: String, index: Int, modifiers: NSEvent.ModifierFlags) {
        focusedIndex = index

        if modifiers.contains(.command) {
            if selectedApps.contains(appName) {
                selectedApps.remove(appName)
            } else {
                selectedApps.insert(appName)
            }
        } else {
            selectedApps = [appName]
        }
    }
}

// MARK: - Manual Entry Content View

struct ManualEntryContentView: View {
    @Binding var appName: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("App Name")
                    .font(.headline)

                AppNameTextField(text: $appName)
                    .frame(height: 22)

                Text("The name should match exactly how it appears in the menu bar or Activity Monitor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

/// NSTextField wrapper for the app name input
struct AppNameTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = "Enter app name"
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .exterior
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)

        // Auto-focus the text field when it appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppNameTextField

        init(_ parent: AppNameTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}
