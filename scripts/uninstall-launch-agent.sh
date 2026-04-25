#!/bin/bash
set -euo pipefail

LABEL="com.klippal.app"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ ! -f "$PLIST_DST" ]; then
    echo "KlipPal LaunchAgent is not installed."
    exit 0
fi

echo "Removing KlipPal LaunchAgent..."

pkill -x KlipPal 2>/dev/null || true
launchctl unload "$PLIST_DST" 2>/dev/null || true
rm -f "$PLIST_DST"

echo "Done. KlipPal will no longer start at login."
