import SwiftUI

/// Advanced settings view with excluded apps management
struct AdvancedSettingsView: View {
    @ObservedObject var excludedAppsManager: ExcludedAppsManager
    @ObservedObject private var preferences = PreferencesManager.shared
    @State private var selectedAppId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search settings section - compact
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fuzzy search")
                        .fontWeight(.medium)
                    Text("Match characters in order even if not consecutive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $preferences.fuzzySearchEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Excluded apps toggle - compact
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exclude apps from history")
                        .fontWeight(.medium)
                    Text("Content from excluded apps won't be saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $excludedAppsManager.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Apps list - takes remaining space
            if excludedAppsManager.isEnabled {
                ExcludedAppsListView(
                    excludedAppsManager: excludedAppsManager,
                    selectedAppId: $selectedAppId
                )
                .frame(maxHeight: .infinity)

                // Toolbar
                ExcludedAppsToolbar(
                    excludedAppsManager: excludedAppsManager,
                    selectedAppId: $selectedAppId,
                    onAddApp: {
                        AddExcludedAppWindowController.show(
                            excludedAppsManager: excludedAppsManager,
                            onDismiss: {}
                        )
                    }
                )
            } else {
                VStack {
                    Spacer()
                    Text("Enable the toggle above to manage excluded apps")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Advanced")
    }
}

// MARK: - Excluded Apps List

struct ExcludedAppsListView: View {
    @ObservedObject var excludedAppsManager: ExcludedAppsManager
    @Binding var selectedAppId: UUID?

    var body: some View {
        List(selection: $selectedAppId) {
            ForEach(excludedAppsManager.excludedApps) { app in
                ExcludedAppRow(
                    app: app,
                    isSelected: selectedAppId == app.id,
                    onToggle: {
                        excludedAppsManager.toggleApp(id: app.id)
                    }
                )
                .tag(app.id)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
        }
        .listStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Excluded App Row

struct ExcludedAppRow: View {
    let app: ExcludedApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text(app.name)
                .foregroundColor(app.isEnabled ? .primary : .secondary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { app.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
    }
}

// MARK: - Toolbar

struct ExcludedAppsToolbar: View {
    @ObservedObject var excludedAppsManager: ExcludedAppsManager
    @Binding var selectedAppId: UUID?
    let onAddApp: () -> Void
    @State private var showingResetConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            // Add button
            Button(action: onAddApp) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Add app to exclusion list")

            Divider()
                .frame(height: 16)

            // Remove button
            Button(action: {
                if let id = selectedAppId {
                    excludedAppsManager.removeApp(id: id)
                    selectedAppId = nil
                }
            }) {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedAppId == nil)
            .help("Remove selected app from exclusion list")

            Spacer()

            // Reset to Defaults button
            Button("Reset to Defaults") {
                showingResetConfirmation = true
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)
            .help("Reset to default password manager apps")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
        .alert("Reset to Defaults", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                excludedAppsManager.resetToDefaults()
                selectedAppId = nil
            }
        } message: {
            Text("This will replace your current exclusion list with the default password manager apps.")
        }
    }
}

// MARK: - Preview

#Preview {
    AdvancedSettingsView(excludedAppsManager: ExcludedAppsManager.shared)
        .frame(width: 450, height: 350)
}
