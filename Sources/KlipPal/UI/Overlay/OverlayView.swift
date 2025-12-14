import SwiftUI

/// Main overlay view showing clipboard history with search
struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        pasteSelectedItem()
                    }
                    .accessibilityLabel("Search clipboard history")
                    .accessibilityHint("Type to filter clipboard items")

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Items list
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    // Animated-looking icon with subtle gradient
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text(searchText.isEmpty ? "No Clipboard History" : "No Results Found")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(searchText.isEmpty
                            ? "Copy text, images, or files to see them here"
                            : "Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if searchText.isEmpty {
                        Text("Press ⌘C anywhere to copy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(searchText.isEmpty
                    ? "No clipboard history. Copy text, images, or files to see them here."
                    : "No results found for \(searchText)")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                highlightRanges: viewModel.matchedRanges(at: index),
                                thumbnailImage: viewModel.thumbnail(for: item),
                                onDelete: { viewModel.deleteItem(item) },
                                onSingleClick: {
                                    // Single-click: just select and copy
                                    viewModel.selectedIndex = index
                                    copyToClipboard(item)
                                },
                                onDoubleClick: {
                                    // Double-click: copy, close, and paste
                                    viewModel.selectedIndex = index
                                    pasteItem(item)
                                },
                                onLoadFullImage: {
                                    await viewModel.loadFullImage(for: item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                // Item count with icon
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.filteredItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.filteredItems.count) clipboard items")

                Spacer()

                // Keyboard shortcuts help
                HStack(spacing: 8) {
                    KeyboardHintView(keys: "↑↓", action: "navigate")
                    KeyboardHintView(keys: "↩", action: "paste")
                    KeyboardHintView(keys: "esc", action: "close")
                }
                .accessibilityHidden(true)

                // Settings button
                Button(action: {
                    viewModel.closeWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        PreferencesWindowController.show()
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Preferences")
                .accessibilityLabel("Open Preferences")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            viewModel.loadItems()
            // Focus the search field when the overlay appears
            isSearchFieldFocused = true
            viewModel.isSearchFieldFocused = true
        }
        .onChange(of: searchText) { newValue in
            viewModel.search(query: newValue)
        }
        .onChange(of: isSearchFieldFocused) { newValue in
            print("🔍 Search field focus changed: \(newValue)")
            viewModel.isSearchFieldFocused = newValue
        }
    }

    private func pasteSelectedItem() {
        guard viewModel.selectedIndex < viewModel.filteredItems.count else { return }
        let item = viewModel.filteredItems[viewModel.selectedIndex]
        pasteItem(item)
    }

    private func copyToClipboard(_ item: ClipboardItem) {
        // Just copy to clipboard, don't close window
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        print("📋 Copied to clipboard (window stays open): \(item.content.prefix(50))")
    }

    private func pasteItem(_ item: ClipboardItem) {
        viewModel.pasteItem(item)
    }
}

// MARK: - Keyboard Hint View

/// A small styled badge showing a keyboard shortcut and its action
struct KeyboardHintView: View {
    let keys: String
    let action: String

    var body: some View {
        HStack(spacing: 3) {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(3)

            Text(action)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
