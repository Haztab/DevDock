#!/bin/bash

# DevDock Build Script
# Usage: ./scripts/build.sh [debug|release|archive]

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/DevDock/DevDock.xcodeproj"
SCHEME="DevDock"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/DevDock.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check requirements
check_requirements() {
    print_step "Checking requirements..."

    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi

    if [ ! -d "$XCODE_PROJECT" ]; then
        print_error "Xcode project not found at $XCODE_PROJECT"
        exit 1
    fi

    print_success "All requirements met"
}

# Clean build directory
clean() {
    print_step "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    print_success "Clean complete"
}

# Build for debugging
build_debug() {
    print_step "Building Debug configuration..."

    xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        build \
        | xcpretty || xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        build

    print_success "Debug build complete"
    echo "App location: $BUILD_DIR/DerivedData/Build/Products/Debug/DevDock.app"
}

# Build for release
build_release() {
    print_step "Building Release configuration..."

    xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        build \
        | xcpretty || xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        build

    print_success "Release build complete"
    echo "App location: $BUILD_DIR/DerivedData/Build/Products/Release/DevDock.app"
}

# Create archive for distribution
archive() {
    print_step "Creating archive..."

    xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        archive \
        | xcpretty || xcodebuild \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        archive

    print_success "Archive created at $ARCHIVE_PATH"
}

# Export archive
export_archive() {
    print_step "Exporting archive..."

    if [ ! -d "$ARCHIVE_PATH" ]; then
        print_error "Archive not found. Run 'archive' first."
        exit 1
    fi

    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$PROJECT_DIR/DevDock/ExportOptions.plist"

    print_success "Export complete at $EXPORT_PATH"
}

# Create DMG for distribution
create_dmg() {
    print_step "Creating DMG..."

    APP_PATH="$EXPORT_PATH/DevDock.app"
    DMG_PATH="$BUILD_DIR/DevDock.dmg"
    DMG_TEMP="$BUILD_DIR/DevDock-temp.dmg"

    if [ ! -d "$APP_PATH" ]; then
        print_error "App not found. Run 'archive' and 'export' first."
        exit 1
    fi

    # Create temporary DMG
    hdiutil create \
        -volname "DevDock" \
        -srcfolder "$APP_PATH" \
        -ov \
        -format UDRW \
        "$DMG_TEMP"

    # Mount and customize
    MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep -E '^/dev/' | sed 1q | awk '{print $3}')

    # Add Applications symlink
    ln -s /Applications "$MOUNT_DIR/Applications" 2>/dev/null || true

    # Unmount
    hdiutil detach "$MOUNT_DIR"

    # Convert to compressed DMG
    hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH"
    rm -f "$DMG_TEMP"

    print_success "DMG created at $DMG_PATH"
}

# Notarize app (requires Apple Developer account)
notarize() {
    print_step "Notarizing app..."

    DMG_PATH="$BUILD_DIR/DevDock.dmg"

    if [ ! -f "$DMG_PATH" ]; then
        print_error "DMG not found. Run 'dmg' first."
        exit 1
    fi

    print_warning "Notarization requires:"
    echo "  - Apple Developer account"
    echo "  - App-specific password"
    echo "  - Team ID"
    echo ""
    echo "Run manually:"
    echo "  xcrun notarytool submit $DMG_PATH --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password YOUR_APP_PASSWORD --wait"
}

# Run all steps for full release
full_release() {
    check_requirements
    clean
    archive
    export_archive
    create_dmg
    print_success "Full release build complete!"
    echo ""
    echo "Artifacts:"
    echo "  Archive: $ARCHIVE_PATH"
    echo "  App:     $EXPORT_PATH/DevDock.app"
    echo "  DMG:     $BUILD_DIR/DevDock.dmg"
}

# Show usage
usage() {
    echo "DevDock Build Script"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  debug      Build debug configuration"
    echo "  release    Build release configuration"
    echo "  archive    Create archive for distribution"
    echo "  export     Export archive to app"
    echo "  dmg        Create DMG installer"
    echo "  notarize   Notarize app (requires Apple Developer account)"
    echo "  full       Run full release build (archive + export + dmg)"
    echo "  clean      Clean build directory"
    echo ""
    echo "Examples:"
    echo "  $0 debug       # Quick debug build"
    echo "  $0 full        # Full release with DMG"
}

# Main
case "${1:-}" in
    debug)
        check_requirements
        build_debug
        ;;
    release)
        check_requirements
        build_release
        ;;
    archive)
        check_requirements
        archive
        ;;
    export)
        export_archive
        ;;
    dmg)
        create_dmg
        ;;
    notarize)
        notarize
        ;;
    full)
        full_release
        ;;
    clean)
        clean
        ;;
    *)
        usage
        exit 1
        ;;
esac
