#!/bin/bash

# DevDock DMG Installer Creator
# Creates a distributable DMG file for DevDock

set -e

# Configuration
APP_NAME="DevDock"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
OUTPUT_DIR="$PROJECT_DIR/dist"
VERSION=$(date +%Y%m%d)

echo "========================================="
echo "  DevDock Installer Creator"
echo "========================================="
echo ""

# Clean previous builds
echo "[1/5] Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DMG_DIR"
mkdir -p "$OUTPUT_DIR"

# Build Release version
echo "[2/5] Building Release version..."
cd "$PROJECT_DIR"
xcodebuild -project DevDock.xcodeproj \
    -scheme DevDock \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/DevDock.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -20

# Export from archive
echo "[3/5] Exporting app..."
APP_PATH="$BUILD_DIR/DevDock.xcarchive/Products/Applications/DevDock.app"

if [ ! -d "$APP_PATH" ]; then
    # Fallback to DerivedData if archive doesn't contain app
    APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/DevDock.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find built app"
    exit 1
fi

# Copy app to DMG staging
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
echo "[4/5] Creating DMG..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Create temporary DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDRW \
    "$BUILD_DIR/temp.dmg"

# Convert to compressed DMG
hdiutil convert "$BUILD_DIR/temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
echo "[5/5] Cleaning up..."
rm -rf "$BUILD_DIR"

# Done
echo ""
echo "========================================="
echo "  DMG Created Successfully!"
echo "========================================="
echo ""
echo "  Output: $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  To install:"
echo "  1. Open the DMG file"
echo "  2. Drag DevDock to Applications"
echo ""
