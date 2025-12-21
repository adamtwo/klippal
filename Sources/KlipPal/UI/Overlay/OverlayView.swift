import SwiftUI

/// Main overlay view showing clipboard history with search
struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject private var preferences = PreferencesManager.shared
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    /// Whether to show fuzzy search hint (search active, fuzzy disabled)
    private var shouldShowFuzzySearchHint: Bool {
        !searchText.isEmpty && !preferences.fuzzySearchEnabled
    }

    /// Icon for empty state based on current view mode
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else if viewModel.showingPinnedOnly {
            return "pin"
        } else {
            return "doc.on.clipboard"
        }
    }

    /// Title for empty state based on current view mode
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results Found"
        } else if viewModel.showingPinnedOnly {
            return "No Pinned Items"
        } else {
            return "No Clipboard History"
        }
    }

    /// Subtitle for empty state based on current view mode
    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "Try a different search term"
        } else if viewModel.showingPinnedOnly {
            return "Pin items to keep them from being deleted"
        } else {
            return "Copy text, images, or files to see them here"
        }
    }

    /// Accessibility label for empty state
    private var emptyStateAccessibilityLabel: String {
        if !searchText.isEmpty {
            return "No results found for \(searchText)"
        } else if viewModel.showingPinnedOnly {
            return "No pinned items. Pin items to keep them from being deleted."
        } else {
            return "No clipboard history. Copy text, images, or files to see them here."
        }
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

            // Toggle bar for History/Pinned
            ViewToggleBar(
                showingPinnedOnly: $viewModel.showingPinnedOnly,
                pinnedCount: viewModel.pinnedCount,
                onToggle: { viewModel.setShowingPinnedOnly($0) },
                onSettings: {
                    viewModel.closeWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        PreferencesWindowController.show()
                    }
                }
            )

            // Items list
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    // Animated-looking icon with subtle gradient
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: emptyStateIcon)
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text(emptyStateTitle)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(emptyStateSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if searchText.isEmpty && !viewModel.showingPinnedOnly {
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
                .accessibilityLabel(emptyStateAccessibilityLabel)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Invisible anchor at top for scroll-to-top
                            Color.clear
                                .frame(height: 0)
                                .id("scroll-top-anchor")

                            ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                                // Show separator before the first fuzzy result
                                if index == viewModel.fuzzyResultsStartIndex {
                                    FuzzyResultsSeparatorView()
                                }

                                ClipboardItemRowView(
                                    item: item,
                                    isSelected: index == viewModel.selectedIndex,
                                    highlightRanges: viewModel.matchedRanges(at: index),
                                    thumbnailImage: viewModel.thumbnailCache[item.contentHash],
                                    onDelete: { viewModel.deleteItem(item) },
                                    onToggleFavorite: { viewModel.toggleFavorite(item) },
                                    onSingleClick: {
                                        viewModel.selectedIndex = index
                                    },
                                    onDoubleClick: {
                                        viewModel.selectedIndex = index
                                        pasteItem(item)
                                    },
                                    onLoadFullImage: {
                                        await viewModel.loadFullImage(for: item)
                                    }
                                )
                                .id(item.id)
                            }

                            // Fuzzy search hint at bottom of results
                            if shouldShowFuzzySearchHint {
                                FuzzySearchHintView(isEnabled: $preferences.fuzzySearchEnabled)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .onChange(of: viewModel.scrollToSelection) { itemId in
                        // Only scroll on keyboard navigation (not mouse clicks)
                        if let itemId = itemId {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(itemId, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: viewModel.scrollToTopTrigger) { _ in
                        // Scroll to top when window opens
                        proxy.scrollTo("scroll-top-anchor", anchor: .top)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(alignment: .top) {
            if viewModel.showCopiedFeedback {
                CopiedToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showCopiedFeedback)
        .onAppear {
            // Sync search query to ViewModel before loading
            // (ViewModel will re-apply search after loading items)
            if !searchText.isEmpty {
                viewModel.search(query: searchText)
            }
            viewModel.loadItems()
            // Focus the search field when the overlay appears
            isSearchFieldFocused = true
            viewModel.isSearchFieldFocused = true
        }
        .onChange(of: searchText) { newValue in
            viewModel.search(query: newValue)
        }
        .onChange(of: preferences.fuzzySearchEnabled) { _ in
            // Re-run search when fuzzy setting changes
            if !searchText.isEmpty {
                viewModel.search(query: searchText)
            }
        }
        .onChange(of: isSearchFieldFocused) { newValue in
            viewModel.isSearchFieldFocused = newValue
        }
    }

    private func pasteSelectedItem() {
        guard viewModel.selectedIndex < viewModel.filteredItems.count else { return }
        let item = viewModel.filteredItems[viewModel.selectedIndex]
        pasteItem(item)
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

// MARK: - Fuzzy Results Separator View

/// Separator shown between exact matches and fuzzy matches
struct FuzzyResultsSeparatorView: View {
    @ObservedObject private var preferences = PreferencesManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text("Fuzzy Search Results")
                .font(.caption)
                .foregroundColor(.secondary)
                .layoutPriority(1)

            Toggle("", isOn: $preferences.fuzzySearchEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityLabel("Fuzzy search results section")
    }
}

// MARK: - Fuzzy Search Hint View

/// Hint shown when fuzzy search is disabled and user is searching
struct FuzzySearchHintView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Enable fuzzy search for more results.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Copied Toast View

/// Brief toast notification shown when user copies with Cmd+C
struct CopiedToastView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Copied!")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .padding(.top, 60)
    }
}

// MARK: - View Toggle Bar

/// Toggle bar for switching between History and Pinned views
struct ViewToggleBar: View {
    @Binding var showingPinnedOnly: Bool
    let pinnedCount: Int
    let onToggle: (Bool) -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // History button
            Button(action: {
                onToggle(false)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("History")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(!showingPinnedOnly ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .foregroundColor(!showingPinnedOnly ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Pinned button
            Button(action: {
                onToggle(true)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                    Text("Pinned")
                        .font(.system(size: 12, weight: .medium))
                    if pinnedCount > 0 {
                        Text("(\(pinnedCount))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(showingPinnedOnly ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .foregroundColor(showingPinnedOnly ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Settings button
            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Preferences")
            .accessibilityLabel("Open Preferences")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}
