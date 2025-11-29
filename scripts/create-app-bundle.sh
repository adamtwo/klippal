#!/bin/bash
set -euo pipefail

# Create macOS .app bundle from Swift Package Manager build
# Usage: ./scripts/create-app-bundle.sh [version] [arch]
# arch: arm64 or x86_64 (optional, defaults to native arch)

VERSION="${1:-1.0.0}"
ARCH="${2:-}"
APP_NAME="KlipPal"
BUNDLE_DIR="${APP_NAME}.app"

# Determine build directory based on architecture
if [ -n "$ARCH" ]; then
    BUILD_DIR=".build/${ARCH}-apple-macosx/release"
else
    BUILD_DIR=".build/release"
fi

echo "Creating ${APP_NAME}.app bundle (version ${VERSION}, arch: ${ARCH:-native})..."

# Ensure release build exists
if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo "Error: Release binary not found at ${BUILD_DIR}/${APP_NAME}"
    echo "Run 'swift build -c release --arch ${ARCH:-arm64}' first"
    exit 1
fi

# Clean previous bundle
rm -rf "${BUNDLE_DIR}"

# Create bundle structure
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/Contents/MacOS/"
chmod +x "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist and update version
cp "Sources/${APP_NAME}/Info.plist" "${BUNDLE_DIR}/Contents/Info.plist"

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${BUNDLE_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${BUNDLE_DIR}/Contents/Info.plist"

# Create PkgInfo (required for app bundles)
echo -n "APPL????" > "${BUNDLE_DIR}/Contents/PkgInfo"

# Copy app icon if it exists
if [ -f "Sources/${APP_NAME}/Resources/AppIcon.icns" ]; then
    cp "Sources/${APP_NAME}/Resources/AppIcon.icns" "${BUNDLE_DIR}/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${BUNDLE_DIR}/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${BUNDLE_DIR}/Contents/Info.plist"
fi

echo "Created ${BUNDLE_DIR}"
echo "  Version: ${VERSION}"
echo "  Architecture: ${ARCH:-native}"
echo "  Size: $(du -sh "${BUNDLE_DIR}" | cut -f1)"

# Verify bundle structure
echo ""
echo "Bundle contents:"
ls -la "${BUNDLE_DIR}/Contents/"
ls -la "${BUNDLE_DIR}/Contents/MacOS/"

# Show binary architecture
echo ""
echo "Binary architecture:"
file "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"
