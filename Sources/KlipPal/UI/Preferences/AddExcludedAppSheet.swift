import SwiftUI
import AppKit

/// Sheet for adding apps to the exclusion list
struct AddExcludedAppSheet: View {
    @ObservedObject var excludedAppsManager: ExcludedAppsManager
    @Environment(\.dismiss) private var dismiss

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
                RunningAppsTabView(
                    runningApps: runningApps,
                    selectedApps: $selectedApps,
                    focusedIndex: $focusedIndex
                )
            } else {
                ManualEntryTabView(appName: $manualAppName)
            }

            Divider()

            // Bottom buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(addButtonTitle) {
                    addSelectedApps()
                    dismiss()
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

// MARK: - Running Apps Tab

struct RunningAppsTabView: View {
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
            // Cmd+click: toggle selection
            if selectedApps.contains(appName) {
                selectedApps.remove(appName)
            } else {
                selectedApps.insert(appName)
            }
        } else {
            // Regular click: single selection
            selectedApps = [appName]
        }
    }
}

// MARK: - Running App Row

struct RunningAppRow: View {
    let appName: String
    let isSelected: Bool
    let isFocused: Bool
    let onTap: (NSEvent.ModifierFlags) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(appName)
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .overlay(focusOverlay)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            // Get current modifier keys
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
            onTap(modifiers)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor)
        }
        return Color.clear
    }

    private var focusOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
            .padding(1)
    }
}

// MARK: - Manual Entry Tab

struct ManualEntryTabView: View {
    @Binding var appName: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("App Name")
                    .font(.headline)

                ManualEntryTextField(text: $appName)

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

/// NSTextField wrapper that properly handles focus in sheets
struct ManualEntryTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = "Enter app name"
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .exterior
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)

        // Request focus after a short delay to ensure the view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = textField.window else { return }

            // For menu bar apps, we need to be very explicit about activation
            // First activate the app
            NSApp.activate(ignoringOtherApps: true)

            // Then make sure the sheet window is key
            window.makeKeyAndOrderFront(nil)

            // Finally set first responder
            window.makeFirstResponder(textField)

            // Double-check activation after a tiny delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if window.firstResponder !== textField {
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeFirstResponder(textField)
                }
            }
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
        var parent: ManualEntryTextField

        init(_ parent: ManualEntryTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        // Handle becoming first responder - ensure app is active
        func controlTextDidBeginEditing(_ notification: Notification) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Preview

#Preview {
    AddExcludedAppSheet(excludedAppsManager: ExcludedAppsManager.shared)
}
