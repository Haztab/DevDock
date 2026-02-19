#!/bin/bash

# DevDock Homebrew Cask Updater
# Updates the Cask formula with the correct SHA256 from a local DMG build
# or from a GitHub release.
#
# Usage:
#   ./scripts/update-homebrew.sh                    # From local build
#   ./scripts/update-homebrew.sh --version 1.2.0    # From GitHub release

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CASK_FILE="$PROJECT_DIR/Casks/devdock.rb"
INFO_PLIST="$PROJECT_DIR/DevDock/DevDock/Info.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
VERSION=""
FROM_RELEASE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            FROM_RELEASE=true
            shift 2
            ;;
        --help|-h)
            echo "DevDock Homebrew Cask Updater"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --version, -v VERSION   Update from GitHub release for VERSION"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Without options, updates from a local DMG build in build/"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     DevDock Homebrew Cask Updater      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Get version if not specified
if [ -z "$VERSION" ]; then
    if [ -f "$INFO_PLIST" ]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
    else
        echo -e "${RED}✗ Cannot determine version. Use --version flag.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Version:${NC} $VERSION"

if [ "$FROM_RELEASE" = true ]; then
    # Download DMG from GitHub release and compute SHA256
    RELEASE_URL="https://github.com/Haztab/DevDock/releases/download/v${VERSION}/DevDock-${VERSION}.dmg"
    TEMP_DMG=$(mktemp /tmp/DevDock-XXXXXX.dmg)

    echo -e "${BLUE}Downloading:${NC} $RELEASE_URL"
    if ! curl -fSL -o "$TEMP_DMG" "$RELEASE_URL"; then
        echo -e "${RED}✗ Failed to download DMG from release${NC}"
        rm -f "$TEMP_DMG"
        exit 1
    fi

    SHA256=$(shasum -a 256 "$TEMP_DMG" | awk '{print $1}')
    rm -f "$TEMP_DMG"
else
    # Use local build
    DMG_PATH="$PROJECT_DIR/build/DevDock-${VERSION}.dmg"

    if [ ! -f "$DMG_PATH" ]; then
        echo -e "${RED}✗ DMG not found at $DMG_PATH${NC}"
        echo "  Run 'make installer' first, or use --version to fetch from GitHub."
        exit 1
    fi

    SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
fi

echo -e "${BLUE}SHA256:${NC}  $SHA256"

# Update Cask file
if [ ! -f "$CASK_FILE" ]; then
    echo -e "${RED}✗ Cask file not found at $CASK_FILE${NC}"
    exit 1
fi

sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "$CASK_FILE"
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "$CASK_FILE"

echo ""
echo -e "${GREEN}✓${NC} Updated $CASK_FILE"
echo ""
echo -e "${CYAN}Updated Cask:${NC}"
cat "$CASK_FILE"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Commit: git add Casks/devdock.rb && git commit -m 'chore: update cask to v${VERSION}'"
echo "  2. Push:   git push origin main"
