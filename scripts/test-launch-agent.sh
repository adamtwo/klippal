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

# --- Setup: compile a minimal fake binary (must be a real Mach-O so pkill -x KlipPal matches it) ---
# A shell script won't work because the OS shows its name as '/bin/sh', not 'KlipPal'.
# A copied Apple binary goes into uninterruptible UE state due to code-signing checks.
# A self-compiled binary has neither issue.
TMPDIR_TEST="$(mktemp -d)"
FAKE_BIN="$TMPDIR_TEST/KlipPal"
cat > "$TMPDIR_TEST/fake.c" << 'EOF'
#include <unistd.h>
int main(void) { while (1) sleep(1); return 0; }
EOF
cc -o "$FAKE_BIN" "$TMPDIR_TEST/fake.c" 2>/dev/null \
    || { echo "SKIP: cc not available, skipping process-kill tests"; FAKE_BIN=""; }

cleanup() {
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    rm -rf "$TMPDIR_TEST"
    pkill -x KlipPal 2>/dev/null || true
}
trap cleanup EXIT

echo "=== install-launch-agent.sh tests ==="

if [ -z "${FAKE_BIN:-}" ]; then
    echo "  SKIP: cc not available, skipping install tests"
else

# Clean state
rm -f "$PLIST"

# Test: installs plist
"$INSTALL" "$FAKE_BIN" &>/dev/null
assert "plist created in LaunchAgents" test -f "$PLIST"

# Test: plist contains correct binary path
assert "plist contains binary path" grep -q "$FAKE_BIN" "$PLIST"

# Test: placeholders replaced
assert_not "placeholder KLIPPAL_BINARY_PATH not present" grep -q "KLIPPAL_BINARY_PATH" "$PLIST"
assert_not "placeholder KLIPPAL_RUN_AT_LOAD not present" grep -q "KLIPPAL_RUN_AT_LOAD" "$PLIST"
assert "RunAtLoad set to true" grep -q "<true/>" "$PLIST"

# Test: launchctl knows about it
assert "launchctl lists agent" launchctl list "$LABEL"

fi

echo ""
echo "=== uninstall-launch-agent.sh tests ==="

"$UNINSTALL" &>/dev/null
assert_not "plist removed after uninstall" test -f "$PLIST"
assert_not "launchctl no longer lists agent" launchctl list "$LABEL"

# Test: uninstall is idempotent
"$UNINSTALL" &>/dev/null
assert "second uninstall does not error" true

echo ""
echo "=== install kills existing KlipPal instance (duplicate-launch regression) ==="

if [ -z "${FAKE_BIN:-}" ]; then
    echo "  SKIP: cc not available"
else
    # Simulate an already-running KlipPal (upgrade scenario: old instance survived launchctl unload)
    "$FAKE_BIN" &
    STALE_PID=$!
    sleep 0.2  # Let it settle into a killable sleep state

    assert "stale KlipPal is running before install" kill -0 "$STALE_PID"

    "$INSTALL" "$FAKE_BIN" &>/dev/null
    sleep 0.5  # Allow SIGTERM to be delivered

    assert_not "stale KlipPal killed after install" kill -0 "$STALE_PID"

    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
fi

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
