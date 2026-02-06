# DevDock Build Guide

This guide explains how to build DevDock and create a distributable installer.

---

## Prerequisites

### Required
- **macOS 14.0 (Sonoma)** or later
- **Xcode 15.0** or later (full version, not just Command Line Tools)

### Optional (Recommended)
- **xcpretty** - Prettier build output: `brew install xcpretty`
- **swift-format** - Code formatting: `brew install swift-format`
- **swiftlint** - Code linting: `brew install swiftlint`

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourorg/devdock.git
cd devdock

# Create installer DMG
make installer
```

The installer will be created at `build/DevDock-1.0.0.dmg`.

---

## Build Commands

| Command | Description |
|---------|-------------|
| `make build` | Build debug configuration |
| `make release` | Build release configuration |
| `make installer` | Create DMG installer (recommended) |
| `make test` | Run unit tests |
| `make clean` | Clean build artifacts |
| `make open` | Open project in Xcode |

---

## Creating the Installer

### Method 1: Using Make (Recommended)

```bash
make installer
```

This will:
1. Check Xcode is properly configured
2. Clean previous build artifacts
3. Build a release archive
4. Export the app
5. Create a DMG with Applications symlink

### Method 2: Using the Script Directly

```bash
./scripts/create-installer.sh
```

With code signing:

```bash
./scripts/create-installer.sh --sign "Developer ID Application: Your Name"
```

### Method 3: Using Xcode

1. Open `DevDock/DevDock.xcodeproj` in Xcode
2. Select **Product → Archive**
3. In Organizer, click **Distribute App**
4. Choose **Copy App** or **Developer ID** (for notarization)

---

## Build Output

After a successful build, you'll find:

```
build/
├── DevDock.xcarchive/     # Xcode archive
├── export/
│   └── DevDock.app        # Exported application
└── DevDock-1.0.0.dmg      # Installer DMG
```

---

## Code Signing

### For Personal Use (Unsigned)

By default, the app is built without code signing. Users will need to:
1. Right-click on DevDock.app
2. Select "Open"
3. Click "Open" in the dialog

### For Distribution (Signed)

To sign the app for distribution:

```bash
# List available signing identities
security find-identity -v -p codesigning

# Build with signing
./scripts/create-installer.sh --sign "Developer ID Application: Your Name (TEAMID)"
```

### Notarization (Optional)

For full Gatekeeper approval:

```bash
# Submit for notarization
xcrun notarytool submit build/DevDock-1.0.0.dmg \
    --apple-id "your@email.com" \
    --team-id "YOURTEAMID" \
    --password "app-specific-password" \
    --wait

# Staple the ticket
xcrun stapler staple build/DevDock-1.0.0.dmg
```

---

## Troubleshooting

### "xcodebuild requires Xcode"

```
xcode-select: error: tool 'xcodebuild' requires Xcode
```

**Solution:** Install Xcode from the App Store and run:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### "No signing certificate"

**Solution:** For development, the app works fine unsigned. For distribution:
1. Join the Apple Developer Program
2. Create a Developer ID certificate in Xcode

### Build Fails with Module Errors

**Solution:** Clean and rebuild:

```bash
make clean
make installer
```

### DMG Won't Open on Other Macs

**Cause:** Gatekeeper blocking unsigned apps.

**Solutions:**
- Sign the app with a Developer ID
- Instruct users to right-click → Open
- Notarize the app for seamless experience

---

## Version Management

```bash
# Show current version
make version

# Bump version before release
make bump-patch  # 1.0.0 → 1.0.1
make bump-minor  # 1.0.0 → 1.1.0
make bump-major  # 1.0.0 → 2.0.0

# Then create installer
make installer
```

---

## Continuous Integration

Example GitHub Actions workflow:

```yaml
name: Build Installer

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Build Installer
        run: make installer

      - name: Upload DMG
        uses: actions/upload-artifact@v4
        with:
          name: DevDock-Installer
          path: build/*.dmg
```

---

## Development Workflow

```bash
# Initial setup
make setup          # Install dev dependencies
make open           # Open in Xcode

# Development cycle
make build          # Quick debug build
make test           # Run tests

# Before release
make lint           # Check code style
make bump-patch     # Update version
make installer      # Create DMG
```

---

## File Structure

```
DevDock/
├── DevDock/
│   ├── DevDock.xcodeproj/   # Xcode project
│   ├── DevDock/             # Source code
│   │   ├── App/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   └── Extensions/
│   └── DevDockTests/        # Unit tests
├── scripts/
│   ├── build.sh             # Build script
│   ├── create-installer.sh  # Installer creator
│   └── version.sh           # Version management
├── docs/                    # Documentation
├── build/                   # Build output (gitignored)
└── Makefile                 # Build commands
```
