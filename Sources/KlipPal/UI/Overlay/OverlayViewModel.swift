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

    private let storage: SQLiteStorageEngine
    private let blobStorage: BlobStorageManager?
    private let pasteManager: PasteManager
    private let searchEngine = SearchEngine()
    private var notificationObserver: Any?

    /// Callback invoked before pasting (to close window and restore previous app)
    var onBeforePaste: (() -> Void)?

    /// Callback invoked to close the window
    var onCloseWindow: (() -> Void)?

    init(storage: SQLiteStorageEngine? = nil, blobStorage: BlobStorageManager? = nil) {
        // Get shared storage from AppDelegate
        self.storage = storage ?? AppDelegate.shared.storage!
        self.blobStorage = blobStorage ?? AppDelegate.shared.blobStorage
        self.pasteManager = PasteManager()

        // Observe clipboard item additions
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .clipboardItemAdded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.loadItems()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadItems() {
        Task {
            do {
                let limit = PreferencesManager.shared.historyLimit
                items = try await storage.fetchItems(limit: limit, favoriteOnly: false)
                filteredItems = items
                // Load thumbnails for image items
                await loadThumbnails(for: items)
            } catch {
                print("❌ Failed to load items: \(error)")
            }
        }
    }

    /// Load thumbnails for image items
    private func loadThumbnails(for items: [ClipboardItem]) async {
        guard let blobStorage = blobStorage else { return }

        for item in items where item.contentType == .image {
            // Skip if already cached
            if thumbnailCache[item.contentHash] != nil { continue }

            // Try to load thumbnail
            do {
                let thumbnailData = try await blobStorage.loadThumbnail(hash: item.contentHash)
                if let image = NSImage(data: thumbnailData) {
                    thumbnailCache[item.contentHash] = image
                }
            } catch {
                // If thumbnail doesn't exist, try to load from full blob path
                if let blobPath = item.blobPath {
                    do {
                        let imageData = try await blobStorage.load(relativePath: blobPath)
                        if let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80) {
                            thumbnailCache[item.contentHash] = thumbnail
                        }
                    } catch {
                        print("⚠️ Failed to load image for thumbnail: \(error)")
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

        // Load from blob storage
        guard let blobStorage = blobStorage,
              let blobPath = item.blobPath else { return nil }

        do {
            let imageData = try await blobStorage.load(relativePath: blobPath)
            if let image = NSImage(data: imageData) {
                fullImageCache[item.contentHash] = image
                return image
            }
        } catch {
            print("⚠️ Failed to load full image: \(error)")
        }

        return nil
    }

    func search(query: String) {
        // Sync fuzzy search setting from preferences
        searchEngine.fuzzyMatchingEnabled = PreferencesManager.shared.fuzzySearchEnabled
        searchResults = searchEngine.search(query: query, in: items)
        filteredItems = searchResults.map { $0.item }

        // Reset selection to be within bounds
        if filteredItems.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= filteredItems.count {
            selectedIndex = 0
        }
    }

    /// Gets the matched ranges for highlighting at a given index
    func matchedRanges(at index: Int) -> [NSRange] {
        guard index < searchResults.count else { return [] }
        return searchResults[index].matchedRanges
    }

    func pasteItem(_ item: ClipboardItem) {
        print("📋 Pasting item: \(item.content.prefix(50))...")

        // Close window and restore previous app before pasting
        onBeforePaste?()

        Task {
            do {
                // Longer delay to allow window to close and app to switch
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                print("📋 Starting paste simulation...")
                try await pasteManager.paste(item)
            } catch {
                print("❌ Failed to paste: \(error)")
            }
        }
    }

    // MARK: - Keyboard Navigation

    func selectNext() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
        print("⌨️ Selected index: \(selectedIndex)")
        triggerScrollToSelection()
    }

    func selectPrevious() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        print("⌨️ Selected index: \(selectedIndex)")
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

    /// Close the overlay window
    func closeWindow() {
        onCloseWindow?()
    }

    /// Delete an item from history
    func deleteItem(_ item: ClipboardItem) {
        Task {
            do {
                try await storage.delete(item)
                print("🗑️ Deleted item: \(item.content.prefix(50))...")

                // Remove from local arrays
                items.removeAll { $0.id == item.id }
                filteredItems.removeAll { $0.id == item.id }

                // Adjust selected index if needed
                if selectedIndex >= filteredItems.count {
                    selectedIndex = max(0, filteredItems.count - 1)
                }
            } catch {
                print("❌ Failed to delete item: \(error)")
            }
        }
    }
}
