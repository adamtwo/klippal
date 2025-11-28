import AppKit
import Foundation

extension Notification.Name {
    static let clipboardItemAdded = Notification.Name("clipboardItemAdded")
}

/// Monitors the system clipboard for changes
@MainActor
class ClipboardMonitor: ObservableObject {
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private let storage: StorageEngineProtocol
    private let deduplicator: ClipboardDeduplicator
    private let blobStorage: BlobStorageManager?

    /// Polling interval in seconds (0.5s = 500ms)
    private let pollingInterval: TimeInterval = 0.5

    init(storage: StorageEngineProtocol, blobStorage: BlobStorageManager? = nil) {
        self.storage = storage
        self.deduplicator = ClipboardDeduplicator(storage: storage)
        self.blobStorage = blobStorage
        self.changeCount = pasteboard.changeCount
    }

    /// Start monitoring the clipboard
    func startMonitoring() {
        changeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkClipboard()
            }
        }

        print("📋 Clipboard monitoring started (polling every \(pollingInterval)s)")
    }

    /// Stop monitoring the clipboard
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("📋 Clipboard monitoring stopped")
    }

    /// Check if clipboard has changed and process new content
    private func checkClipboard() async {
        let currentChangeCount = pasteboard.changeCount

        // No change detected
        guard currentChangeCount != changeCount else { return }

        changeCount = currentChangeCount

        // Extract content from pasteboard
        guard let (content, type, imageData) = ClipboardContentExtractor.extract(from: pasteboard) else {
            print("⚠️ Could not extract content from pasteboard")
            return
        }

        // Check for duplicates
        guard let hash = await deduplicator.shouldSave(content: content, imageData: imageData) else {
            print("⏭️ Skipping duplicate clipboard content")
            return
        }

        // Get source application
        let sourceApp = ClipboardContentExtractor.getFrontmostApp()

        // Handle image storage if needed
        var blobPath: String? = nil
        if let imageData = imageData, let blobStorage = blobStorage {
            do {
                blobPath = try await blobStorage.save(imageData: imageData, hash: hash)
            } catch {
                print("⚠️ Failed to save image blob: \(error)")
            }
        }

        // Create clipboard item
        let item = ClipboardItem(
            content: content,
            contentType: type,
            contentHash: hash,
            sourceApp: sourceApp,
            blobPath: blobPath
        )

        // Save to storage
        do {
            try await storage.save(item)
            print("✅ Saved clipboard item: \(type.displayName) from \(sourceApp ?? "unknown")")

            // Notify observers that a new item was saved
            NotificationCenter.default.post(name: .clipboardItemAdded, object: item)
        } catch {
            print("❌ Failed to save clipboard item: \(error)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}
