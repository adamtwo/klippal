import SwiftUI

/// Main preferences view with tabs for different settings sections
struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesManager.shared
    @State private var showingClearConfirmation = false
    @State private var itemCount: Int = 0

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            StorageSettingsView(preferences: preferences, showingClearConfirmation: $showingClearConfirmation, itemCount: $itemCount)
                .tabItem {
                    Label("Storage", systemImage: "internaldrive")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
        .alert("Clear Clipboard History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all clipboard history? This action cannot be undone.")
        }
        .onAppear {
            refreshItemCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardItemAdded)) { _ in
            refreshItemCount()
        }
    }

    private func clearHistory() {
        Task {
            if let storage = AppDelegate.shared?.storage {
                try? await storage.deleteAll()
                print("✅ Clipboard history cleared")
                // Update the item count after clearing
                await MainActor.run {
                    itemCount = 0
                }
            }
        }
    }

    private func refreshItemCount() {
        Task {
            if let storage = AppDelegate.shared?.storage {
                let count = try await storage.count()
                await MainActor.run {
                    itemCount = count
                }
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                    .help("Automatically start KlipPal when you log in")
            }

            Section {
                KeyboardShortcutPicker(preferences: preferences)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Storage Settings

struct StorageSettingsView: View {
    @ObservedObject var preferences: PreferencesManager
    @Binding var showingClearConfirmation: Bool
    @Binding var itemCount: Int

    var body: some View {
        Form {
            Section {
                Stepper(value: $preferences.historyLimit, in: 100...2000, step: 100) {
                    HStack {
                        Text("History limit:")
                        Spacer()
                        Text("\(preferences.historyLimit) items")
                            .foregroundColor(.secondary)
                    }
                }
                .help("Maximum number of clipboard items to keep")
            }

            Section {
                Picker("Auto-delete after:", selection: $preferences.retentionDays) {
                    Text("Never").tag(0)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("60 days").tag(60)
                    Text("90 days").tag(90)
                }
                .help("Automatically delete items older than this")
            }

            Section {
                HStack {
                    Text("Current items:")
                    Spacer()
                    Text("\(itemCount)")
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Clear All History", systemImage: "trash")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 16) {
            // App logo - matching menu bar branding
            Text("Kᵖ")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)

            Text("KlipPal")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("A privacy-first clipboard manager - keeping your clipboard history local and secure. No cloud sync, no telemetry.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("Copyright 2025 KlipPal. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Link("Website", destination: URL(string: "https://klippal.app")!)
                    Link("MIT License", destination: URL(string: "https://github.com/adamtwo/klippal/blob/main/LICENSE")!)
                }
                .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
}
