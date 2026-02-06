#!/bin/bash

# DevDock Version Management Script
# Usage: ./scripts/version.sh [get|set|bump] [version]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$PROJECT_DIR/DevDock/DevDock/Info.plist"
PBXPROJ="$PROJECT_DIR/DevDock/DevDock.xcodeproj/project.pbxproj"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current version from Info.plist
get_version() {
    if [ -f "$INFO_PLIST" ]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
        BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")
        echo "Version: $VERSION (Build $BUILD)"
    else
        echo "Info.plist not found"
        exit 1
    fi
}

# Set version in Info.plist
set_version() {
    VERSION=$1
    BUILD=${2:-1}

    if [ -z "$VERSION" ]; then
        echo "Usage: $0 set <version> [build]"
        echo "Example: $0 set 1.0.0 1"
        exit 1
    fi

    if [ -f "$INFO_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$INFO_PLIST"
        echo -e "${GREEN}✓${NC} Set version to $VERSION (Build $BUILD)"
    fi

    # Also update project.pbxproj if it has version info
    if [ -f "$PBXPROJ" ]; then
        sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBXPROJ"
        echo -e "${GREEN}✓${NC} Updated project.pbxproj"
    fi
}

# Bump version
bump_version() {
    TYPE=${1:-patch}

    # Get current version
    if [ -f "$INFO_PLIST" ]; then
        CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
        BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0")
    else
        CURRENT="1.0.0"
        BUILD=0
    fi

    # Parse version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
    MAJOR=${MAJOR:-0}
    MINOR=${MINOR:-0}
    PATCH=${PATCH:-0}

    # Bump based on type
    case "$TYPE" in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
        build)
            BUILD=$((BUILD + 1))
            ;;
        *)
            echo "Usage: $0 bump [major|minor|patch|build]"
            exit 1
            ;;
    esac

    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    NEW_BUILD=$((BUILD + 1))

    echo -e "${BLUE}Bumping version:${NC} $CURRENT -> $NEW_VERSION (Build $NEW_BUILD)"
    set_version "$NEW_VERSION" "$NEW_BUILD"
}

# Create git tag
create_tag() {
    VERSION=$1

    if [ -z "$VERSION" ]; then
        if [ -f "$INFO_PLIST" ]; then
            VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
        else
            echo "Usage: $0 tag [version]"
            exit 1
        fi
    fi

    TAG="v$VERSION"
    echo "Creating tag: $TAG"

    git tag -a "$TAG" -m "Release $VERSION"
    echo -e "${GREEN}✓${NC} Created tag $TAG"
    echo ""
    echo "To push: git push origin $TAG"
}

# Show usage
usage() {
    echo "DevDock Version Management"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  get              Show current version"
    echo "  set <ver> [bld]  Set version and build number"
    echo "  bump <type>      Bump version (major|minor|patch|build)"
    echo "  tag [version]    Create git tag"
    echo ""
    echo "Examples:"
    echo "  $0 get           # Show current version"
    echo "  $0 set 1.1.0     # Set version to 1.1.0"
    echo "  $0 bump patch    # Bump 1.0.0 -> 1.0.1"
    echo "  $0 bump minor    # Bump 1.0.0 -> 1.1.0"
    echo "  $0 bump major    # Bump 1.0.0 -> 2.0.0"
    echo "  $0 tag           # Create tag for current version"
}

# Main
case "${1:-}" in
    get)
        get_version
        ;;
    set)
        set_version "$2" "$3"
        ;;
    bump)
        bump_version "$2"
        ;;
    tag)
        create_tag "$2"
        ;;
    *)
        usage
        ;;
esac
