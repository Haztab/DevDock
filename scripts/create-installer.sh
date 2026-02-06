#!/bin/bash

# DevDock Installer Creator
# Creates a distributable DMG installer for DevDock
#
# Requirements:
# - Xcode (not just Command Line Tools)
# - Valid code signing identity (optional, for distribution)
#
# Usage: ./scripts/create-installer.sh [--sign IDENTITY]

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/DevDock/DevDock.xcodeproj"
SCHEME="DevDock"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/DevDock.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_NAME="DevDock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
SIGN_IDENTITY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --help|-h)
            echo "DevDock Installer Creator"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --sign IDENTITY   Sign the app with the specified identity"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Banner
echo -e "${CYAN}"
echo "╔════════════════════════════════════════╗"
echo "║       DevDock Installer Creator        ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check for Xcode
check_xcode() {
    echo -e "${BLUE}[1/6]${NC} Checking Xcode..."

    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}✗ xcodebuild not found${NC}"
        echo "  Please install Xcode from the App Store"
        exit 1
    fi

    # Check if full Xcode is available
    XCODE_PATH=$(xcode-select -p 2>/dev/null)
    if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
        echo -e "${RED}✗ Full Xcode required${NC}"
        echo "  Currently using: $XCODE_PATH"
        echo ""
        echo "  To fix this:"
        echo "  1. Install Xcode from the App Store"
        echo "  2. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Xcode found at: $XCODE_PATH"
}

# Get version from project
get_version() {
    if [ -f "$PROJECT_DIR/DevDock/DevDock/Info.plist" ]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/DevDock/DevDock/Info.plist" 2>/dev/null || echo "1.0.0")
    else
        VERSION="1.0.0"
    fi
    echo "$VERSION"
}

# Clean previous build
clean_build() {
    echo -e "${BLUE}[2/6]${NC} Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    echo -e "${GREEN}✓${NC} Clean complete"
}

# Build archive
build_archive() {
    echo -e "${BLUE}[3/6]${NC} Building archive..."
    echo "      This may take a few minutes..."

    # Determine if we should use xcpretty
    if command -v xcpretty &> /dev/null; then
        xcodebuild \
            -project "$XCODE_PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            archive \
            | xcpretty
    else
        xcodebuild \
            -project "$XCODE_PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            archive \
            | grep -E "(Build|Archive|Compile|Link|error:|warning:)"
    fi

    if [ ! -d "$ARCHIVE_PATH" ]; then
        echo -e "${RED}✗ Archive failed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Archive created"
}

# Export app
export_app() {
    echo -e "${BLUE}[4/6]${NC} Exporting app..."

    # Create export options plist
    EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

    if [ -n "$SIGN_IDENTITY" ]; then
        # Signed export
        cat > "$EXPORT_OPTIONS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGN_IDENTITY</string>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF
    else
        # Unsigned export (for local use)
        cat > "$EXPORT_OPTIONS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
    fi

    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        2>&1 | grep -v "^$"

    if [ ! -d "$EXPORT_PATH/DevDock.app" ]; then
        echo -e "${YELLOW}⚠${NC} Export with signing failed, trying without..."

        # Fallback: copy from archive directly
        mkdir -p "$EXPORT_PATH"
        cp -R "$ARCHIVE_PATH/Products/Applications/DevDock.app" "$EXPORT_PATH/"
    fi

    echo -e "${GREEN}✓${NC} App exported"
}

# Create DMG
create_dmg() {
    echo -e "${BLUE}[5/6]${NC} Creating DMG installer..."

    VERSION=$(get_version)
    APP_PATH="$EXPORT_PATH/DevDock.app"
    DMG_TEMP="$BUILD_DIR/DevDock-temp.dmg"
    DMG_FINAL="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"

    if [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}✗ App not found at $APP_PATH${NC}"
        exit 1
    fi

    # Create staging directory
    STAGING_DIR="$BUILD_DIR/dmg-staging"
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"

    # Copy app
    cp -R "$APP_PATH" "$STAGING_DIR/"

    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"

    # Create temporary DMG
    hdiutil create \
        -volname "$DMG_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDRW \
        "$DMG_TEMP" \
        > /dev/null

    # Mount and customize (optional background image)
    MOUNT_POINT=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep -E '^/dev/' | tail -1 | awk '{print $3}')

    # Set icon positions using AppleScript
    osascript << EOF
tell application "Finder"
    tell disk "$DMG_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "DevDock.app" of container window to {130, 150}
        set position of item "Applications" of container window to {370, 150}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

    # Unmount
    hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1 || true

    # Convert to compressed DMG
    hdiutil convert "$DMG_TEMP" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$DMG_FINAL" \
        > /dev/null

    # Clean up
    rm -f "$DMG_TEMP"
    rm -rf "$STAGING_DIR"

    echo -e "${GREEN}✓${NC} DMG created"
}

# Summary
print_summary() {
    echo -e "${BLUE}[6/6]${NC} Build complete!"
    echo ""
    VERSION=$(get_version)
    DMG_FINAL="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"
    DMG_SIZE=$(du -h "$DMG_FINAL" | cut -f1)

    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           Build Summary                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}Version:${NC}  $VERSION"
    echo -e "  ${GREEN}Size:${NC}     $DMG_SIZE"
    echo -e "  ${GREEN}Output:${NC}   $DMG_FINAL"
    echo ""

    if [ -n "$SIGN_IDENTITY" ]; then
        echo -e "  ${GREEN}Signed:${NC}   Yes ($SIGN_IDENTITY)"
    else
        echo -e "  ${YELLOW}Signed:${NC}   No (unsigned build)"
        echo ""
        echo -e "  ${YELLOW}Note:${NC} Unsigned apps may trigger Gatekeeper warnings."
        echo "        Users can right-click and select 'Open' to bypass."
    fi

    echo ""
    echo -e "${CYAN}To install:${NC}"
    echo "  1. Open $DMG_FINAL"
    echo "  2. Drag DevDock to Applications"
    echo ""
}

# Main
main() {
    check_xcode
    clean_build
    build_archive
    export_app
    create_dmg
    print_summary
}

main "$@"
