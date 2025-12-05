# KlipPal - Architecture Document

**Version:** 2.0
**Platform:** macOS 13.0+ (Ventura and later)
**Status:** Implemented

---

## Overview

KlipPal is a native macOS clipboard manager built with Swift and SwiftUI. The architecture follows a modular monolith pattern with clear component boundaries.

### Key Architectural Decisions

- **Modular monolith**: Single app bundle with clear component boundaries
- **SwiftUI + AppKit hybrid**: SwiftUI for UI, AppKit for system integration
- **SQLite for persistence**: Actor-based async storage with separate blob storage for images
- **Polling-based clipboard monitoring**: 500ms timer-based NSPasteboard.changeCount checks
- **In-memory search**: Fuzzy matching with relevance scoring
- **Zero network access**: Completely local, no telemetry

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         KlipPal App                             │
│                    (Native macOS Bundle)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────────┐   ┌──────────────┐
│   macOS      │    │   AppDelegate    │   │  StatusBar   │
│   System     │◄───┤                  │──►│  Controller  │
│              │    │ - Lifecycle      │   │              │
│ - Pasteboard │    │ - Permissions    │   │ - NSStatusBar│
│ - Events     │    │ - Coordinator    │   │ - Menu Items │
└──────────────┘    └──────────────────┘   └──────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────────┐   ┌──────────────┐
│  Clipboard   │    │   Storage        │   │   Overlay    │
│  Monitor     │───►│   Engine         │◄──│   UI         │
│              │    │                  │   │              │
│ - Timer Loop │    │ - SQLite Actor   │   │ - SwiftUI    │
│ - Extractor  │    │ - CRUD Ops       │   │ - Search Bar │
│ - Dedup      │    │ - Blob Storage   │   │ - List View  │
└──────────────┘    └──────────────────┘   └──────────────┘
        │                     │                     │
        │                     ▼                     │
        │            ┌──────────────────┐           │
        │            │   Search         │           │
        │            │   Engine         │◄──────────┘
        │            │                  │
        │            │ - In-Memory      │
        │            │ - Fuzzy Match    │
        │            └──────────────────┘
        │                     │
        ▼                     ▼
┌──────────────┐    ┌──────────────────┐
│   Paste      │    │  Preferences     │
│   Manager    │    │  Manager         │
│              │    │                  │
│ - Write PB   │    │ - UserDefaults   │
│ - Cmd+V Sim  │    │ - @Published     │
└──────────────┘    └──────────────────┘
```

---

## Project Structure

```
Sources/KlipPal/
├── main.swift                           # App entry point
├── AppDelegate.swift                    # App lifecycle, component setup
│
├── Core/
│   ├── Clipboard/
│   │   ├── ClipboardMonitor.swift       # 500ms polling, change detection
│   │   ├── ClipboardContentExtractor.swift  # Type detection, content extraction
│   │   └── ClipboardDeduplicator.swift  # SHA256-based duplicate detection
│   │
│   ├── Storage/
│   │   ├── StorageEngineProtocol.swift  # Async protocol definition
│   │   ├── SQLiteStorageEngine.swift    # Actor-based SQLite implementation
│   │   ├── DatabaseSchema.swift         # Schema definition, migrations
│   │   └── BlobStorageManager.swift     # Image/large content file storage
│   │
│   ├── Search/
│   │   ├── SearchEngine.swift           # Query execution, relevance scoring
│   │   └── FuzzyMatcher.swift           # Substring + word matching
│   │
│   ├── Paste/
│   │   └── PasteManager.swift           # Clipboard write + Cmd+V simulation
│   │
│   └── Preferences/
│       └── PreferencesManager.swift     # UserDefaults wrapper, @Published
│
├── Models/
│   ├── ClipboardItem.swift              # Core data model (id, content, type, hash, timestamp)
│   ├── ClipboardContentType.swift       # Enum: text, url, image, fileURL
│   └── KeyboardShortcut.swift           # Shortcut model with modifiers + keyCode
│
├── UI/
│   ├── Overlay/
│   │   ├── OverlayWindowController.swift    # NSPanel wrapper
│   │   ├── OverlayPanel.swift               # Custom NSPanel subclass
│   │   ├── OverlayView.swift                # Main SwiftUI view
│   │   ├── OverlayViewModel.swift           # View state, item loading, paste actions
│   │   ├── ClipboardItemRowView.swift       # Individual item display
│   │   └── HighlightedText.swift            # Search match highlighting
│   │
│   ├── Preferences/
│   │   ├── PreferencesWindowController.swift  # NSWindow wrapper
│   │   ├── PreferencesView.swift              # TabView with General/Storage/About
│   │   └── KeyboardShortcutPicker.swift       # Custom shortcut recording UI
│   │
│   └── StatusBar/
│       └── StatusBarController.swift    # Menu bar icon ("Kᵖ"), menu items
│
└── Utilities/
    ├── GlobalHotKeyManager.swift        # CGEvent tap for global shortcuts
    ├── SHA256Hasher.swift               # CryptoKit wrapper for deduplication
    ├── ThumbnailGenerator.swift         # Image thumbnail creation
    ├── URLMetadataExtractor.swift       # URL domain extraction
    ├── FileMetadataExtractor.swift      # File path metadata
    ├── KeyCodeConverter.swift           # Virtual key code to string
    ├── ShortcutValidator.swift          # Shortcut validation rules
    └── FourCharCode.swift               # Carbon key code utilities
```

---

## Component Details

### 1. Clipboard Monitor

**File:** `Core/Clipboard/ClipboardMonitor.swift`

Monitors NSPasteboard using a 500ms polling timer that checks `changeCount`. When a change is detected, it extracts content using `ClipboardContentExtractor` and checks for duplicates using `ClipboardDeduplicator`.

**Key Implementation:**
- Timer-based polling (500ms interval)
- Change detection via `NSPasteboard.general.changeCount`
- Delegates content extraction and deduplication to separate classes
- Publishes new items via callback to storage

### 2. Storage Engine

**Files:** `Core/Storage/SQLiteStorageEngine.swift`, `StorageEngineProtocol.swift`

Actor-based async SQLite implementation that ensures thread-safe database access.

**Protocol:**
```swift
protocol StorageEngineProtocol {
    func save(_ item: ClipboardItem) async throws
    func fetchAll(limit: Int) async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func count() async throws -> Int
    func toggleFavorite(id: UUID) async throws
    func applyRetentionPolicy(days: Int, limit: Int) async throws
}
```

**Database Schema:** (`DatabaseSchema.swift`)
```sql
CREATE TABLE items (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    content_type TEXT NOT NULL,
    content_hash TEXT NOT NULL UNIQUE,
    timestamp REAL NOT NULL,
    source_app TEXT,
    blob_path TEXT,
    is_favorite INTEGER DEFAULT 0
);

CREATE INDEX idx_timestamp ON items(timestamp DESC);
CREATE INDEX idx_content_hash ON items(content_hash);
CREATE INDEX idx_favorite ON items(is_favorite);
```

**Blob Storage:** (`BlobStorageManager.swift`)
- Images stored in `~/Library/Application Support/KlipPal/blobs/`
- Full images + 80x80 thumbnails
- Cleanup on item deletion

### 3. Search Engine

**Files:** `Core/Search/SearchEngine.swift`, `FuzzyMatcher.swift`

In-memory search with fuzzy matching and relevance scoring.

**Matching Algorithm:**
1. Exact substring match (case-insensitive)
2. Word boundary matching (all query words must appear)
3. Relevance scoring based on match position and recency

**Performance:** <50ms for 500 items

### 4. Overlay UI

**Files:** `UI/Overlay/OverlayWindowController.swift`, `OverlayView.swift`, `OverlayViewModel.swift`

SwiftUI-based floating panel for clipboard history display.

**Window Configuration:**
- NSPanel with floating level
- Non-activating (doesn't steal focus from active app)
- Hides on deactivate
- Positioned at screen center

**View Hierarchy:**
```
OverlayView
├── VStack
│   ├── Search bar (TextField + clear button)
│   ├── Divider
│   ├── ScrollView with LazyVStack
│   │   └── ClipboardItemRowView (foreach item)
│   ├── Divider
│   └── Footer (item count + keyboard hints + settings button)
```

**Keyboard Navigation:**
- Arrow Up/Down: Navigate items
- Enter: Paste selected item
- Escape: Close overlay

### 5. Paste Manager

**File:** `Core/Paste/PasteManager.swift`

Handles clipboard restoration and paste simulation.

**Paste Flow:**
1. Write selected item content to NSPasteboard
2. Close overlay window
3. Small delay for window to close
4. Simulate Cmd+V using CGEvent

### 6. Preferences Manager

**File:** `Core/Preferences/PreferencesManager.swift`

UserDefaults-backed settings with Combine publishers.

**Settings:**
- `launchAtLogin`: Bool (uses SMAppService)
- `keyboardShortcut`: KeyboardShortcut (Cmd+Shift+V default)
- `historyLimit`: Int (100-2000, default 500)
- `retentionDays`: Int (0=never, 7, 14, 30, 60, 90)

### 7. Global Hotkey Manager

**File:** `Utilities/GlobalHotKeyManager.swift`

CGEvent tap for global keyboard shortcut registration.

**Requirements:**
- Accessibility permission required
- Registered in AppDelegate on launch
- Triggers overlay toggle

---

## Data Models

### ClipboardItem

```swift
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String           // Text content or description
    let contentType: ClipboardContentType
    let contentHash: String       // SHA256 for deduplication
    let timestamp: Date
    let sourceApp: String?        // Bundle ID of source app
    var blobPath: String?         // Path to blob storage (images)
    var isFavorite: Bool
}
```

### ClipboardContentType

```swift
enum ClipboardContentType: String, Codable, CaseIterable {
    case text
    case url
    case image
    case fileURL
}
```

### KeyboardShortcut

```swift
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt32  // CGEventFlags raw value

    static let defaultShortcut = KeyboardShortcut(
        keyCode: 9,  // 'V' key
        modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
    )
}
```

---

## Data Flow

### Clipboard Capture

```
User copies (Cmd+C)
    ↓
NSPasteboard.changeCount increments
    ↓
ClipboardMonitor detects change (500ms poll)
    ↓
ClipboardContentExtractor extracts content + type
    ↓
ClipboardDeduplicator checks SHA256 hash
    ↓ (if unique)
SQLiteStorageEngine.save() (async actor)
    ↓
SearchEngine index updated (via notification)
```

### Paste Action

```
User presses Cmd+Shift+V
    ↓
GlobalHotKeyManager triggers callback
    ↓
StatusBarController.toggleOverlay()
    ↓
OverlayWindowController.showWindow()
    ↓
OverlayViewModel.loadItems() from storage
    ↓
User types search → SearchEngine.search()
    ↓
User selects item (Enter or double-click)
    ↓
PasteManager.pasteItem():
  1. Write to NSPasteboard
  2. Close overlay
  3. Simulate Cmd+V via CGEvent
```

---

## Storage Locations

```
~/Library/Application Support/KlipPal/
├── clipboard.db          # SQLite database
└── blobs/
    └── images/
        ├── {uuid}.png           # Full images
        └── {uuid}_thumb.png     # 80x80 thumbnails
```

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Language | Swift 5.9+ | Native macOS development |
| UI Framework | SwiftUI | Declarative UI |
| System Integration | AppKit | NSPasteboard, NSPanel, NSStatusBar |
| Database | SQLite | Local persistence |
| Concurrency | Swift Actors | Thread-safe storage |
| Hashing | CryptoKit | SHA256 deduplication |
| Hotkeys | CGEvent | Global keyboard shortcuts |

---

## Security & Privacy

- **Local-only**: All data stored on device, zero network access
- **No telemetry**: No analytics or crash reporting
- **Accessibility permission**: Required for global hotkeys and paste simulation
- **App Sandbox**: Disabled (required for Accessibility APIs)

---

## Performance Targets

| Metric | Target | Implementation |
|--------|--------|----------------|
| Overlay open | <100ms | Pre-built NSPanel, lazy loading |
| Search latency | <50ms | In-memory fuzzy search |
| Memory footprint | <100MB | Thumbnail caching, lazy image loading |
| CPU idle | <1% | 500ms polling interval |
| Startup time | <2s | Background initialization |

---

## Testing

**Test Coverage:** 263 tests, 63.79% code coverage

**Test Categories:**
- Unit tests: Storage, Search, Models, Deduplication
- Integration tests: Clipboard capture flow, Paste workflow
- UI component tests: Menu actions, View models

**Test Files Location:** `Tests/KlipPalTests/`

---

## Installation

```bash
# Install via Homebrew (recommended)
brew install --cask adamtwo/klippal/klippal
```

---

## Build & Run (Development)

```bash
# Build
swift build

# Run tests
swift test

# Run app
swift build && .build/debug/KlipPal
```

---

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission for global hotkeys and paste simulation
