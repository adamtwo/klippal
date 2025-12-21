import Foundation
import Combine
import AppKit

/// View model for the overlay
@MainActor
class OverlayViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var filteredItems: [ClipboardItem] = []
    @Published var searchResults: [SearchResult] = []
    @Published var selectedIndex: Int = 0
    @Published var isSearchFieldFocused: Bool = false
    /// Triggered when keyboard navigation occurs, to scroll the selected item into view
    @Published var scrollToSelection: UUID?
    @Published var thumbnailCache: [String: NSImage] = [:]
    @Published var fullImageCache: [String: NSImage] = [:]
    /// Shows brief "Copied!" feedback when user copies with Cmd+C
    @Published var showCopiedFeedback: Bool = false
    /// Incremented to trigger scroll to top when window opens
    @Published var scrollToTopTrigger: Int = 0
    /// Whether to show only pinned (favorite) items
    @Published var showingPinnedOnly: Bool = false

    /// Current search query - stored to re-apply after reloading items
    private var currentSearchQuery: String = ""

    private let storage: SQLiteStorageEngine
    private let pasteManager: PasteManager
    private let searchEngine = SearchEngine()
    private var notificationObserver: Any?

    /// Callback invoked before pasting (to close window and restore previous app)
    var onBeforePaste: (() -> Void)?

    /// Callback invoked to close the window
    var onCloseWindow: (() -> Void)?

    init(storage: SQLiteStorageEngine? = nil, preloadedItems: [ClipboardItem] = []) {
        // Get shared storage from AppDelegate
        self.storage = storage ?? AppDelegate.shared.storage!
        self.pasteManager = PasteManager()

        // Use pre-loaded items if provided, otherwise load from storage
        if !preloadedItems.isEmpty {
            self.items = preloadedItems
            self.filteredItems = preloadedItems
            // Load thumbnails for pre-loaded items
            Task { @MainActor [weak self] in
                self?.loadThumbnails(for: preloadedItems)
            }
        } else {
            // Fallback: load from storage if no pre-loaded items
            Task { @MainActor [weak self] in
                self?.loadItemsFromStorage()
            }
        }

        // Observe clipboard item additions - add incrementally instead of reloading
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .clipboardItemAdded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                if let newItem = notification.object as? ClipboardItem {
                    self?.addItemIncrementally(newItem)
                } else {
                    // Fallback to full reload if item not in notification
                    self?.loadItemsFromStorage()
                }
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Called when the overlay window is shown - uses cached items, no database fetch
    func loadItems() {
        // Re-apply current filters (search query and/or pinned-only mode)
        applyFilters()
        // Always reset selection to first item when window appears
        selectedIndex = 0
        // Trigger scroll to top
        scrollToTopTrigger += 1
    }

    /// Loads items from storage - called on init and when full refresh is needed
    func loadItemsFromStorage() {
        Task {
            do {
                let limit = PreferencesManager.shared.historyLimit
                items = try await storage.fetchItems(limit: limit, favoriteOnly: false)
                // Re-apply current filters
                applyFilters()
                // Load thumbnails for image items
                loadThumbnails(for: items)
            } catch {
                print("Failed to load items: \(error)")
            }
        }
    }

    /// Adds a new item to the front of the list without reloading from storage
    private func addItemIncrementally(_ newItem: ClipboardItem) {
        // Insert at the beginning (most recent)
        items.insert(newItem, at: 0)

        // Enforce history limit
        let limit = PreferencesManager.shared.historyLimit
        if items.count > limit {
            items = Array(items.prefix(limit))
        }

        // Re-apply filters to update filteredItems
        applyFilters()

        // Load thumbnail if it's an image
        if newItem.contentType == .image {
            loadThumbnails(for: [newItem])
        }
    }

    /// Load thumbnails for image items from their blob content
    private func loadThumbnails(for items: [ClipboardItem]) {
        for item in items where item.contentType == .image {
            // Skip if already cached
            if thumbnailCache[item.contentHash] != nil { continue }

            // Generate thumbnail from blob content (fetch lazily if needed)
            Task {
                var blobContent = item.blobContent
                if blobContent == nil {
                    blobContent = try? await storage.fetchBlobContent(byHash: item.contentHash)
                }
                if let blobContent = blobContent {
                    if let thumbnail = ThumbnailGenerator.generateThumbnail(from: blobContent, maxSize: 80) {
                        await MainActor.run {
                            thumbnailCache[item.contentHash] = thumbnail
                        }
                    }
                }
            }
        }
    }

    /// Get cached thumbnail for an item
    func thumbnail(for item: ClipboardItem) -> NSImage? {
        return thumbnailCache[item.contentHash]
    }

    /// Load full-size image for an item (for preview popup)
    func loadFullImage(for item: ClipboardItem) async -> NSImage? {
        // Only load images
        guard item.contentType == .image else { return nil }

        // Check cache first
        if let cached = fullImageCache[item.contentHash] {
            return cached
        }

        // Load from blob content (fetch lazily if needed)
        var blobContent = item.blobContent
        if blobContent == nil {
            blobContent = try? await storage.fetchBlobContent(byHash: item.contentHash)
        }

        guard let blobContent = blobContent else { return nil }

        if let image = NSImage(data: blobContent) {
            fullImageCache[item.contentHash] = image
            return image
        }

        return nil
    }

    func search(query: String) {
        // Store the query to re-apply after reloading items
        currentSearchQuery = query
        // Apply filters (handles both search and pinned-only mode)
        applyFilters()
    }

    /// Gets the matched ranges for highlighting at a given index
    func matchedRanges(at index: Int) -> [NSRange] {
        guard index < searchResults.count else { return [] }
        return searchResults[index].matchedRanges
    }

    /// Gets the match type for a result at a given index
    func matchType(at index: Int) -> MatchType? {
        guard index < searchResults.count else { return nil }
        return searchResults[index].matchType
    }

    /// Returns the index where fuzzy results begin, or nil if there are no fuzzy results
    var fuzzyResultsStartIndex: Int? {
        // Find the first fuzzy result
        guard let firstFuzzyIndex = searchResults.firstIndex(where: { $0.matchType == .fuzzy }) else {
            return nil
        }
        // Only show separator if there are also exact matches before it
        guard firstFuzzyIndex > 0 else { return nil }
        return firstFuzzyIndex
    }

    /// Whether the current search has both exact and fuzzy results (for showing separator)
    var hasBothExactAndFuzzyResults: Bool {
        let hasExact = searchResults.contains { $0.matchType == .exact }
        let hasFuzzy = searchResults.contains { $0.matchType == .fuzzy }
        return hasExact && hasFuzzy
    }

    func pasteItem(_ item: ClipboardItem) {
        print("Pasting item: \(item.content.prefix(50))...")

        // Update timestamp to bring item to top of history
        Task {
            do {
                try await storage.updateTimestamp(forHash: item.contentHash)
                print("Updated timestamp for pasted item")
            } catch {
                print("Failed to update timestamp: \(error)")
            }
        }

        // Close window and restore previous app before pasting
        onBeforePaste?()

        Task {
            do {
                // Longer delay to allow window to close and app to switch
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                print("Starting paste simulation...")
                try await pasteManager.paste(item)
            } catch {
                print("Failed to paste: \(error)")
            }
        }
    }

    // MARK: - Keyboard Navigation

    func selectNext() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
        triggerScrollToSelection()
    }

    func selectPrevious() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        triggerScrollToSelection()
    }

    /// Triggers scroll to keep selected item visible (called only for keyboard navigation)
    private func triggerScrollToSelection() {
        guard selectedIndex < filteredItems.count else { return }
        scrollToSelection = filteredItems[selectedIndex].id
    }

    func pasteSelected() {
        guard selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]
        pasteItem(item)
    }

    /// Copy the selected item to the system clipboard (Cmd+C)
    func copySelectedToClipboard() {
        guard selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]

        Task {
            // Fetch blob content if not already loaded
            var blobContent = item.blobContent
            if blobContent == nil {
                blobContent = try? await storage.fetchBlobContent(byHash: item.contentHash)
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch item.contentType {
            case .image:
                if let blobContent = blobContent, let image = NSImage(data: blobContent) {
                    pasteboard.writeObjects([image])
                    print("Copied image to clipboard")
                }

            case .fileURL:
                if let url = URL(string: item.content), url.isFileURL {
                    pasteboard.writeObjects([url as NSURL])
                    print("Copied file URL to clipboard: \(url.path)")
                }

            case .richText:
                if let blobContent = blobContent {
                    if let attributed = NSAttributedString(rtf: blobContent, documentAttributes: nil) {
                        pasteboard.setData(blobContent, forType: .rtf)
                        pasteboard.setString(attributed.string, forType: .string)
                        print("Copied RTF to clipboard")
                    } else if let attributed = NSAttributedString(html: blobContent, documentAttributes: nil) {
                        pasteboard.setData(blobContent, forType: .html)
                        pasteboard.setString(attributed.string, forType: .string)
                        print("Copied HTML to clipboard")
                    } else {
                        pasteboard.setString(item.content, forType: .string)
                    }
                } else {
                    pasteboard.setString(item.content, forType: .string)
                }

            case .text, .url:
                // Use full text from blob if available
                if let blobContent = blobContent,
                   let fullText = String(data: blobContent, encoding: .utf8) {
                    pasteboard.setString(fullText, forType: .string)
                    print("Copied full text to clipboard: \(fullText.prefix(50))...")
                } else {
                    pasteboard.setString(item.content, forType: .string)
                    print("Copied summary to clipboard: \(item.content.prefix(50))...")
                }
            }

            // Update timestamp to bring item to top of history
            do {
                try await storage.updateTimestamp(forHash: item.contentHash)
                print("Updated timestamp for copied item")
            } catch {
                print("Failed to update timestamp: \(error)")
            }

            // Show brief visual feedback
            showCopiedFeedback = true
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showCopiedFeedback = false
        }
    }

    /// Close the overlay window
    func closeWindow() {
        onCloseWindow?()
    }

    /// Delete an item from history
    func deleteItem(_ item: ClipboardItem) {
        Task {
            do {
                try await storage.delete(item)
                print("Deleted item: \(item.content.prefix(50))...")

                // Remove from local arrays
                items.removeAll { $0.id == item.id }
                filteredItems.removeAll { $0.id == item.id }

                // Adjust selected index if needed
                if selectedIndex >= filteredItems.count {
                    selectedIndex = max(0, filteredItems.count - 1)
                }
            } catch {
                print("Failed to delete item: \(error)")
            }
        }
    }

    // MARK: - Pinned Items

    /// Number of pinned (favorite) items
    var pinnedCount: Int {
        items.filter { $0.isFavorite }.count
    }

    /// Toggle the favorite/pinned status of an item
    func toggleFavorite(_ item: ClipboardItem) {
        Task {
            do {
                // Create updated item with toggled favorite status
                var updatedItem = item
                updatedItem.isFavorite = !item.isFavorite

                // Save to storage
                try await storage.save(updatedItem)
                print("Toggled favorite for: \(item.content.prefix(50))... -> \(updatedItem.isFavorite)")

                // Update in local arrays
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index] = updatedItem
                }
                if let index = filteredItems.firstIndex(where: { $0.id == item.id }) {
                    filteredItems[index] = updatedItem
                }

                // If in pinned-only mode and item was unpinned, remove from filtered
                if showingPinnedOnly && !updatedItem.isFavorite {
                    filteredItems.removeAll { $0.id == item.id }
                    // Adjust selected index if needed
                    if selectedIndex >= filteredItems.count {
                        selectedIndex = max(0, filteredItems.count - 1)
                    }
                }
            } catch {
                print("Failed to toggle favorite: \(error)")
            }
        }
    }

    /// Set whether to show only pinned items
    func setShowingPinnedOnly(_ value: Bool) {
        showingPinnedOnly = value
        applyFilters()
    }

    /// Apply current filters (search query and pinned-only mode) to items
    private func applyFilters() {
        // Determine the base items to filter/search
        let baseItems = showingPinnedOnly ? items.filter { $0.isFavorite } : items

        if !currentSearchQuery.isEmpty {
            // Search within the appropriate items (all or pinned only)
            searchEngine.fuzzyMatchingEnabled = PreferencesManager.shared.fuzzySearchEnabled
            searchResults = searchEngine.search(query: currentSearchQuery, in: baseItems)
            filteredItems = searchResults.map { $0.item }
        } else {
            // No search - just show the base items
            filteredItems = baseItems
            searchResults = []
        }

        // Reset selection to be within bounds
        if filteredItems.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= filteredItems.count {
            selectedIndex = 0
        }
    }
}
