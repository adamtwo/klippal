#!/bin/bash
set -euo pipefail

# Install KlipPal LaunchAgent so it starts at login without a terminal window.
# Usage: ./scripts/install-launch-agent.sh [path-to-KlipPal-binary]

LABEL="com.klippal.app"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
PLIST_SRC="$(dirname "$0")/../Sources/KlipPal/Resources/${LABEL}.plist"

# --- Find binary ---
if [ -n "${1:-}" ]; then
    BINARY="$1"
else
    # Search common locations in priority order
    for candidate in \
        "/opt/homebrew/bin/KlipPal" \
        "/usr/local/bin/KlipPal" \
        "$(dirname "$0")/../.build/release/KlipPal" \
        "$(dirname "$0")/../.build/debug/KlipPal"
    do
        if [ -x "$candidate" ]; then
            BINARY="$(realpath "$candidate")"
            break
        fi
    done
fi

if [ -z "${BINARY:-}" ] || [ ! -x "$BINARY" ]; then
    echo "Error: KlipPal binary not found. Pass the path as an argument:"
    echo "  $0 /path/to/KlipPal"
    exit 1
fi

echo "Installing KlipPal LaunchAgent..."
echo "  Binary: $BINARY"
echo "  Plist:  $PLIST_DST"

# --- Unload existing agent if running ---
if launchctl list "$LABEL" &>/dev/null; then
    launchctl unload "$PLIST_DST" 2>/dev/null || true
fi

# --- Write plist with correct binary path ---
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|KLIPPAL_BINARY_PATH|$BINARY|g" \
    -e "s|KLIPPAL_RUN_AT_LOAD|<true/>|g" \
    "$PLIST_SRC" > "$PLIST_DST"

# --- Load and start ---
launchctl load "$PLIST_DST"

echo "Done. KlipPal will now start at login and run in the background."
echo "To stop it: launchctl unload $PLIST_DST"
