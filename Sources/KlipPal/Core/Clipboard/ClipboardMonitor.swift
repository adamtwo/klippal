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
    private let excludedAppsManager: ExcludedAppsManager?

    /// Polling interval in seconds (0.5s = 500ms)
    private let pollingInterval: TimeInterval = 0.5

    /// Maximum image size to store (10MB)
    private let maxImageSize: Int = 10 * 1024 * 1024

    init(storage: StorageEngineProtocol, excludedAppsManager: ExcludedAppsManager? = nil) {
        self.storage = storage
        self.deduplicator = ClipboardDeduplicator(storage: storage)
        self.excludedAppsManager = excludedAppsManager
        self.changeCount = pasteboard.changeCount
    }

    /// Start monitoring the clipboard
    func startMonitoring() {
        changeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
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

        // Get source application first to check exclusion
        let sourceApp = ClipboardContentExtractor.getFrontmostApp()

        // Check if app is excluded (use shared instance if not provided)
        let manager = excludedAppsManager ?? ExcludedAppsManager.shared
        if manager.shouldExclude(appName: sourceApp) {
            print("⏭️ Skipping clipboard from excluded app: \(sourceApp ?? "unknown")")
            return
        }

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

        // Store content as blob - for images use imageData, for text use UTF-8 encoded content
        var blobContent: Data? = nil
        if let imageData = imageData {
            if imageData.count <= maxImageSize {
                blobContent = imageData
            } else {
                print("⚠️ Image too large (\(imageData.count) bytes), skipping blob storage")
            }
        } else {
            // Store text content as UTF-8 data
            blobContent = content.data(using: .utf8)
        }

        // Create clipboard item (truncate text content to 100 chars for preview)
        let truncatedContent = type == .image ? content : String(content.prefix(100))
        let item = ClipboardItem(
            content: truncatedContent,
            contentType: type,
            contentHash: hash,
            sourceApp: sourceApp,
            blobContent: blobContent
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
