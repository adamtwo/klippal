# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Rules

**IMPORTANT - Follow these rules for all feature development:**

1. **Tests First**: Always write tests before implementing features
   - Write unit tests for business logic
   - Write integration tests involving UI where applicable
   - Run tests to verify they fail first, then implement

2. **No Auto-Commit**: Do NOT commit and push unless explicitly told to do so

## Project Overview

**KlipPal** is a native macOS clipboard manager built with Swift and SwiftUI. It monitors the system clipboard, stores history locally (no cloud sync), and provides instant search/access through a global hotkey overlay.

**Key Design Principles:**
- Local-only: All data stored on device, no network access
- Native: Swift + SwiftUI + AppKit for macOS integration
- Simple: Focus on core clipboard management, no feature bloat
- Fast: <100ms overlay open, <50ms search latency

**Architecture Pattern:** Modular monolith with 6 core components (Monitor, Storage, Search, UI, Paste, Preferences)

## Essential Commands

### Building and Running

```bash
# Open in Xcode
open KlipPal.xcodeproj

# Build from command line
xcodebuild -scheme KlipPal -configuration Debug

# Run from Xcode: Cmd+R

# Clean build
xcodebuild clean -scheme KlipPal
```

### Testing

```bash
# Run all tests
xcodebuild test -scheme KlipPal

# Run specific test
xcodebuild test -scheme KlipPal -only-testing:KlipPalTests/StorageEngineTests

# Run tests with code coverage
xcodebuild test -scheme KlipPal -enableCodeCoverage YES
```

### Development Workflow

**IMPORTANT: Accessibility Permissions Required**
- This app needs Accessibility permissions to monitor clipboard and simulate paste
- Each rebuild requires re-granting permissions (macOS treats debug builds as new apps)
- Manual: System Settings > Privacy & Security > Accessibility > Add KlipPal binary
- Binary location: `DerivedData/.../Debug/KlipPal.app`

## Architecture Overview

### Component Breakdown

#### 1. Clipboard Monitor (`Core/Clipboard/`)
- **Purpose:** Detect clipboard changes and extract content
- **Implementation:** Timer-based polling (500ms) of `NSPasteboard.changeCount`
- **Key files:**
  - `ClipboardMonitor.swift` - Main polling loop
  - `ClipboardContentExtractor.swift` - Extract typed content (text/image/URL/file)
  - `ClipboardDeduplicator.swift` - SHA256 hashing to prevent duplicates
- **Why polling?** NSPasteboard has no reliable change notification API

#### 2. Storage Engine (`Core/Storage/`)
- **Purpose:** Persist clipboard history to disk
- **Implementation:** SQLite with separate blob storage for images
- **Key files:**
  - `SQLiteStorageEngine.swift` - Actor-based thread-safe storage (async/await)
  - `DatabaseSchema.swift` - Schema v1 (items table + indexes)
  - `BlobStorageManager.swift` - Image storage in `~/Library/Application Support/KlipPal/blobs/`
- **Thread safety:** All storage methods are `async` and run on a SQLite actor
- **Limits:** 500 items default, 30-day auto-cleanup

#### 3. Search Engine (`Core/Search/`)
- **Purpose:** Fast fuzzy search across clipboard content
- **Implementation:** In-memory trie/prefix index, rebuilt on launch
- **Key files:**
  - `SearchEngine.swift` - Query execution with relevance scoring
  - `SearchIndex.swift` - Index builder from storage
  - `FuzzyMatcher.swift` - Levenshtein distance with threshold
- **Performance target:** <50ms search latency (p95)

#### 4. Overlay UI (`UI/Overlay/`)
- **Purpose:** Global hotkey-activated search/paste interface
- **Implementation:** NSPanel wrapper around SwiftUI view
- **Key files:**
  - `OverlayWindowController.swift` - NSPanel configuration (HUD style, floating)
  - `OverlayView.swift` - SwiftUI content (search bar + results list)
  - `ClipboardItemRow.swift` - Individual item display with preview
- **Hotkey:** Cmd+Shift+V (customizable via preferences)
- **Behavior:** Appears at cursor, dismisses on Esc/click outside

#### 5. Paste Manager (`Core/Paste/`)
- **Purpose:** Restore clipboard content and simulate Cmd+V
- **Implementation:** NSPasteboard write + CGEvent Cmd+V simulation
- **Key files:**
  - `PasteManager.swift` - Restore to clipboard and paste
  - `CGEventSimulator.swift` - Virtual key event generation
  - `ActiveApplicationDetector.swift` - Find frontmost app for paste target
- **Flow:** User selects item → Restore to NSPasteboard → Simulate Cmd+V → Dismiss overlay

#### 6. Preferences Manager (`Core/Preferences/`)
- **Purpose:** Store user settings
- **Implementation:** UserDefaults wrapper with Combine publishers
- **Settings:** History limit, retention days, hotkey, launch at login

### Data Flow

```
User copies (Cmd+C) in any app
    ↓
ClipboardMonitor detects changeCount difference (500ms polling)
    ↓
ClipboardContentExtractor reads NSPasteboard (type detection)
    ↓
ClipboardDeduplicator checks SHA256 hash (skip if duplicate)
    ↓
SQLiteStorageEngine saves (async actor, main DB + blob storage)
    ↓
SearchIndex rebuilds in-memory (triggered by storage event)

User presses Cmd+Shift+V
    ↓
OverlayWindowController shows NSPanel at cursor
    ↓
User types search query
    ↓
SearchEngine fuzzy matches (in-memory, <50ms)
    ↓
OverlayView displays results (SwiftUI list)
    ↓
User selects item (Enter or click)
    ↓
PasteManager restores to NSPasteboard
    ↓
CGEventSimulator sends Cmd+V to frontmost app
    ↓
Overlay dismisses
```

### Data Models

**ClipboardItem** (`Models/ClipboardItem.swift`)
```swift
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String              // Text content or file path
    let contentType: ClipboardContentType  // .text, .url, .image, .fileURL
    let contentHash: String          // SHA256 for deduplication
    let timestamp: Date
    let sourceApp: String?           // App that was active during copy
    var blobPath: String?            // Path to blob storage (for images)
    var isFavorite: Bool             // Pin to top
}
```

**ClipboardContentType** (`Models/ClipboardContentType.swift`)
```swift
enum ClipboardContentType: String, Codable {
    case text      // Plain text
    case url       // Detected URL (http/https)
    case image     // PNG/JPEG/TIFF
    case fileURL   // File path (file://)
}
```

### Storage Schema

**items table:**
```sql
CREATE TABLE items (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    content_type TEXT NOT NULL,
    content_hash TEXT NOT NULL UNIQUE,
    timestamp INTEGER NOT NULL,
    source_app TEXT,
    blob_path TEXT,
    is_favorite INTEGER DEFAULT 0
);

CREATE INDEX idx_timestamp ON items(timestamp DESC);
CREATE INDEX idx_content_hash ON items(content_hash);
CREATE INDEX idx_favorite ON items(is_favorite DESC, timestamp DESC);
```

## Key Technical Considerations

### macOS-Specific Implementation Details

**Global Hotkey Registration:**
- Use `CGEvent` tap with `kCGEventTapOptionDefault`
- Requires Accessibility permissions
- Register in `AppDelegate.applicationDidFinishLaunching`
- File: `Utilities/GlobalHotKeyManager.swift`

**App Sandbox:**
- **DISABLED** (required for Accessibility permissions)
- Hardened Runtime: **ENABLED**
- Entitlements: No special entitlements beyond default

**NSPasteboard Monitoring:**
- Polling interval: 500ms (balance between responsiveness and CPU)
- Change detection: `NSPasteboard.general.changeCount`
- No observer pattern available in macOS API

**Launch at Login:**
- Use `SMAppService.mainApp.register()` (macOS 13+)
- No longer using deprecated Login Items API
- File: `Utilities/LaunchAtLoginManager.swift`

**Menu Bar App:**
- `NSStatusBar.system.statusItem` for icon
- No dock icon: `LSUIElement = true` in Info.plist
- Status item shows menu + opens overlay on click

### SwiftUI + AppKit Hybrid Pattern

**Why hybrid?**
- SwiftUI: Modern UI, reactive, easy to build
- AppKit: Required for NSPasteboard, NSPanel, NSStatusBar, CGEvent

**Integration pattern:**
```swift
// AppKit NSPanel wrapper for SwiftUI content
class OverlayWindowController: NSWindowController {
    init() {
        let panel = NSPanel(...)
        panel.contentView = NSHostingView(rootView: OverlayView())
        super.init(window: panel)
    }
}
```

**Thread safety:**
- All UI updates must be on `@MainActor`
- Storage operations run on SQLite actor (background)
- Use `@Published` + Combine for reactive updates

### Memory Management

**Image handling:**
- Store thumbnails (80x80) in SQLite for preview
- Store full images in blob storage (separate files)
- Lazy load full images on demand
- Limit: 10MB per image, skip if larger

**History limits:**
- Default: 500 items
- Auto-cleanup: Delete items older than 30 days
- Manual: User can clear all history in preferences

**Target footprint:** <100MB with 500 items (mostly text)

## Common Development Tasks

### Adding a New Content Type

1. Add case to `ClipboardContentType` enum
2. Update `ClipboardContentExtractor.extract()` to detect type
3. Add preview logic in `ClipboardItemRow.swift`
4. Update search indexing if needed in `SearchIndex.swift`

### Modifying Search Algorithm

- Edit `FuzzyMatcher.swift` for matching logic
- Edit `SearchEngine.swift` for ranking/scoring
- Performance target: <50ms for 500 items

### Changing Clipboard Polling Interval

- Locate `ClipboardMonitor.swift`
- Find `Timer.scheduledTimer(withTimeInterval: 0.5, ...)`
- Adjust interval (lower = more responsive, higher CPU usage)

### Customizing Overlay Appearance

- `OverlayWindowController.swift` - Panel styling (size, position, level)
- `OverlayView.swift` - SwiftUI layout and styling
- `ClipboardItemRow.swift` - Individual item appearance

## Testing Strategy

### Unit Tests (40% coverage target)
- Storage engine (mock SQLite actor)
- Search engine (in-memory index)
- Deduplication logic
- Content type detection

### Integration Tests (30% coverage target)
- Clipboard capture → Storage → Search flow
- Paste workflow (mock CGEvent)
- Cleanup service

### Manual Testing Checklist
- [ ] Accessibility permission flow (clean install)
- [ ] Global hotkey triggers overlay
- [ ] Search results update in real-time
- [ ] Paste to various apps (Terminal, Notes, Xcode, Safari)
- [ ] Image clipboard handling (screenshots, copied images)
- [ ] Launch at login works
- [ ] Menu bar icon shows/hides overlay
- [ ] Preferences save and persist

### Performance Testing
- [ ] Overlay open time <100ms (use Instruments: Time Profiler)
- [ ] Search latency <50ms (log timestamps in debug)
- [ ] Memory footprint <100MB (use Instruments: Allocations)
- [ ] CPU idle <1% (use Activity Monitor)

## Build Configuration

### Debug Build
- Optimization: `-Onone`
- Symbols: Full
- Assertions: Enabled
- Hardened Runtime: Enabled
- Code Signing: Development certificate

### Release Build
- Optimization: `-O` (Swift whole module optimization)
- Symbols: Strip (or dSYM for crash reports)
- Assertions: Disabled
- Hardened Runtime: Enabled
- Distribution: Homebrew cask

## Project Structure (When Implemented)

```
KlipPal/
├── App/
│   ├── KlipPalApp.swift      # @main entry point
│   ├── AppDelegate.swift         # System integration
│   └── AppCoordinator.swift      # Component lifecycle
├── Core/
│   ├── Clipboard/                # Monitoring and extraction
│   ├── Storage/                  # SQLite persistence
│   ├── Search/                   # Fuzzy search engine
│   └── Paste/                    # Clipboard restoration
├── Models/
│   ├── ClipboardItem.swift       # Core data model
│   └── ClipboardContentType.swift
├── UI/
│   ├── Overlay/                  # Main search/paste UI
│   ├── Preferences/              # Settings window
│   └── StatusBar/                # Menu bar integration
├── Utilities/
│   ├── GlobalHotKeyManager.swift
│   ├── PermissionsManager.swift
│   └── Extensions/
└── Resources/
    └── Assets.xcassets
```

## Known Limitations & Gotchas

1. **No clipboard change notifications:** NSPasteboard API doesn't provide KVO or notifications, polling is the only reliable method
2. **Accessibility permissions reset on rebuild:** Debug builds get new code signatures, must re-grant permissions
3. **App Sandbox incompatible:** Cannot be sandboxed due to Accessibility requirement
4. **Image memory usage:** Large images (>10MB) are skipped to prevent memory issues
5. **Paste simulation:** CGEvent Cmd+V may not work in some apps (security restrictions)
6. **CGEvent virtual key codes:** Use Carbon's `kVK_` constants (e.g., `kVK_ANSI_V = 0x09` for 'V' key)
7. **SQLite thread safety:** Always use Swift actors to serialize database access
8. **LSUIElement:** Set to `true` in Info.plist for menu bar-only app (no Dock icon)

## Distribution

### Installation (Users)
```bash
brew install --cask adamtwo/klippal/klippal
```

### Release Checklist (Developers)
- [ ] Run full test suite: `swift test`
- [ ] Test on macOS 13, 14, 15
- [ ] Memory leak detection (Instruments)
- [ ] CPU profiling (ensure <1% idle)
- [ ] Update Homebrew cask formula with new version

## Documentation References

- **README.md** - User-facing documentation
- **ARCHITECTURE.md** - System design and component details

## Quick Start for New Contributors

1. Read README.md (understand what the app does)
2. Read ARCHITECTURE.md (understand how it works)
3. Build and run: `swift build && .build/debug/KlipPal`
4. Grant Accessibility permissions when prompted
5. Test: Copy some text, press Cmd+Shift+V, search and paste

## Current Status

**Project Phase:** Implementation Complete
**Test Coverage:** 263 tests, 63.79% coverage
- When you push something to remote, check if it triggers a pipeline run. If it does, monitor the pipeline execution, check for success. If it fails, analyze why and offer suggestions.
- Never ask me if I'm ok to run this bash command, just run it when needed: pkill -f KlipPal 2>/dev/null; sleep 0.5; .build/debug/KlipPal &
- the website is one directory app in dir called klippal-website
- Never commit and push automatically