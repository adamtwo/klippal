# KlipPal

A clipboard manager for macOS that remembers everything you copy.

## Why KlipPal?

Ever copied something, then copied something else, and lost the first thing? KlipPal solves that. It quietly saves your clipboard history so you can go back and find anything you've copied.

**Your data stays on your Mac.** No cloud sync, no accounts, no tracking. Just a simple tool that does one thing well.

## Features

### Instant Access
Press **Cmd+Shift+V** from any app to see your clipboard history. Find what you need, press Enter, and it's pasted instantly.

### Smart Search
Type to filter through your history. KlipPal searches the content of everything you've copied, so you can find that URL, code snippet, or quote in seconds.

### Works with Everything
- Text and code snippets
- URLs (with domain preview)
- Images and screenshots
- File paths

### Stays Out of Your Way
- Lives in your menu bar as a small "Kᵖ" icon
- No dock icon cluttering your screen
- Uses minimal system resources
- Launches automatically at login (optional)

### Configurable
- Customize the keyboard shortcut
- Set how many items to keep (100-2000)
- Auto-delete old items after a set time

## Installation

### Homebrew (Recommended)

```bash
brew install --cask adamtwo/klippal/klippal
```

### Manual Installation

1. Download KlipPal from the releases page
2. Move to Applications
3. Launch and grant Accessibility permission when prompted
4. Start copying things - they'll appear when you press Cmd+Shift+V

### Accessibility Permission

KlipPal needs Accessibility permission to:
- Respond to the global keyboard shortcut
- Paste items into your apps

When you first launch KlipPal, macOS will prompt you to grant this permission in System Settings.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open clipboard history | Cmd+Shift+V (customizable) |
| Navigate items | ↑ / ↓ |
| Paste selected item | Enter |
| Close | Esc |

## Requirements

- macOS 13.0 (Ventura) or later

## Privacy

KlipPal is completely local. Your clipboard history is stored only on your Mac and is never sent anywhere. There's no analytics, no telemetry, and no network access.

## License

MIT
