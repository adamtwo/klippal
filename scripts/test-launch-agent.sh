#!/bin/bash
# Integration tests for install-launch-agent.sh and uninstall-launch-agent.sh
set -euo pipefail

PASS=0; FAIL=0
LABEL="com.klippal.app"

assert() {
    local desc="$1"; shift
    if "$@" &>/dev/null; then
        echo "  PASS: $desc"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
    fi
}

assert_not() {
    local desc="$1"; shift
    if ! "$@" &>/dev/null; then
        echo "  PASS: $desc"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
    fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL="$SCRIPT_DIR/install-launch-agent.sh"
UNINSTALL="$SCRIPT_DIR/uninstall-launch-agent.sh"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

# --- Setup: create a no-op fake binary ---
TMPDIR_TEST="$(mktemp -d)"
FAKE_BIN="$TMPDIR_TEST/KlipPal"
printf '#!/bin/sh\nsleep 3600\n' > "$FAKE_BIN"
chmod +x "$FAKE_BIN"

cleanup() {
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    rm -rf "$TMPDIR_TEST"
    pkill -f "sleep 3600" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== install-launch-agent.sh tests ==="

# Clean state
rm -f "$PLIST"

# Test: installs plist
"$INSTALL" "$FAKE_BIN" &>/dev/null
assert "plist created in LaunchAgents" test -f "$PLIST"

# Test: plist contains correct binary path
assert "plist contains binary path" grep -q "$FAKE_BIN" "$PLIST"

# Test: placeholder replaced
assert_not "placeholder KLIPPAL_BINARY_PATH not present" grep -q "KLIPPAL_BINARY_PATH" "$PLIST"

# Test: launchctl knows about it
assert "launchctl lists agent" launchctl list "$LABEL"

echo ""
echo "=== uninstall-launch-agent.sh tests ==="

"$UNINSTALL" &>/dev/null
assert_not "plist removed after uninstall" test -f "$PLIST"
assert_not "launchctl no longer lists agent" launchctl list "$LABEL"

# Test: uninstall is idempotent
"$UNINSTALL" &>/dev/null
assert "second uninstall does not error" true

echo ""
echo "=== install with no binary argument ==="

# Temporarily put fake binary on PATH to test auto-detection
export PATH="$TMPDIR_TEST:$PATH"
"$INSTALL" &>/dev/null
assert "auto-detected binary installed plist" test -f "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
