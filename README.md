# DevDock

<p align="center">
  <img src="docs/assets/logo.png" alt="DevDock Logo" width="128" height="128">
</p>

<p align="center">
  <strong>Run mobile apps without terminal</strong>
</p>

<p align="center">
  A lightweight macOS utility for Flutter, React Native, and native mobile developers.
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#documentation">Documentation</a>
</p>

---

## What is DevDock?

DevDock is a minimal floating panel that lets you **run, stop, and hot-reload** your mobile apps with a single click. No more switching to terminal, remembering CLI commands, or losing your logs.

```
┌─────────────────────────────┐
│ 🐦 MyFlutterApp        [📁] │
│ ● Running                   │
├─────────────────────────────┤
│ [Android] [iOS]             │
│ 📱 Pixel 6 Emulator      ↻  │
│ ┌─────────────────────────┐ │
│ │        ■ Stop           │ │
│ └─────────────────────────┘ │
│ [🔥 Hot Reload] [↻ Restart] │
├─────────────────────────────┤
│ flutter: Building...        │
│ flutter: Syncing files      │
│ flutter: Ready in 2.3s      │
└─────────────────────────────┘
```

## Features

### Core Features

| Feature | Flutter | React Native | Android | iOS |
|---------|:-------:|:------------:|:-------:|:---:|
| Auto-detect project | ✅ | ✅ | ✅ | ✅ |
| Device detection | ✅ | ✅ | ✅ | ✅ |
| Run app | ✅ | ✅ | 🔄 | 🔄 |
| Stop app | ✅ | ✅ | ✅ | ✅ |
| Hot Reload | ✅ | - | - | - |
| Hot Restart | ✅ | - | - | - |
| Real-time logs | ✅ | ✅ | ✅ | ✅ |

### UI Features

- **Floating Panel** - Always visible, never in the way
- **Always on Top** - Stays above your IDE
- **Minimal Design** - 320px width, clean interface
- **Dark Mode** - Automatic system theme support
- **Menu Bar Icon** - Quick access from anywhere

### Log Viewer

- **Real-time streaming** - See logs as they happen
- **Color-coded levels** - Error, Warning, Info, Debug
- **Filter by level** - Focus on what matters
- **Search** - Find specific messages
- **Export** - Save logs to file

## Installation

### Download

Download the latest release from [Releases](https://github.com/yourorg/devdock/releases).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourorg/devdock.git
cd devdock/DevDock

# Open in Xcode
open DevDock.xcodeproj

# Build and run (⌘R)
```

## Usage

### Quick Start

1. **Launch DevDock** - Opens as a floating panel
2. **Select Project** - Click folder icon or use Recent Projects
3. **Choose Platform** - Android or iOS
4. **Select Device** - Pick emulator/simulator
5. **Click Run** - Watch your app launch!

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Run | ⌘R |
| Stop | ⌘. |
| Hot Reload | ⇧⌘R |
| Hot Restart | ⌥⇧⌘R |
| Refresh Devices | ⇧⌘D |
| Clear Logs | ⌘K |

### Flutter Hot Reload

When running a Flutter app:
1. Make changes to your code
2. Save the file
3. Click **Hot Reload** (or press ⇧⌘R)
4. See changes instantly!

## Requirements

### System

- **macOS 14.0** (Sonoma) or later
- **Xcode 15.0** or later (for iOS development)

### For Flutter Development

```bash
# Check Flutter installation
flutter doctor

# Ensure Flutter is in PATH
which flutter
```

### For React Native Development

```bash
# Node.js and npm required
node --version
npm --version

# React Native CLI
npx react-native --version
```

### For Android Development

```bash
# ADB must be accessible
adb devices

# Android SDK should be installed
echo $ANDROID_HOME
```

## Documentation

| Document | Description |
|----------|-------------|
| [PRD](docs/PRD.md) | Product requirements and specifications |
| [Technical Spec](docs/TECHNICAL_SPEC.md) | Architecture and implementation details |
| [Development Guide](docs/DEVELOPMENT_GUIDE.md) | Setup and contributing guide |
| [Task Tracker](docs/TASK_TRACKER.md) | Project progress and task management |
| [Architecture](DevDock/ARCHITECTURE.md) | High-level architecture overview |

## Project Structure

```
DevDock/
├── DevDock.xcodeproj       # Xcode project
├── DevDock/
│   ├── App/                # App entry point
│   ├── Models/             # Data models
│   ├── Services/           # Business logic
│   │   ├── CommandRunner   # Process execution
│   │   ├── DeviceManager   # Device detection
│   │   ├── LogProcessor    # Log parsing
│   │   └── ProjectDetector # Project type detection
│   ├── ViewModels/         # State management
│   ├── Views/              # SwiftUI views
│   └── Extensions/         # Swift extensions
└── docs/                   # Documentation
```

## Troubleshooting

### "Command not found" Error

Ensure development tools are in your PATH:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$PATH:/opt/homebrew/bin"
export PATH="$PATH:$HOME/.pub-cache/bin"
export PATH="$PATH:$HOME/fvm/default/bin"
```

### No Devices Showing

**Android:**
```bash
# Check ADB
adb devices -l

# Restart ADB server
adb kill-server && adb start-server
```

**iOS:**
```bash
# List simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 15 Pro"
```

### Hot Reload Not Working

- Ensure the Flutter process is still running (green status)
- Check that stdin pipe is connected
- Try Hot Restart instead

## Contributing

We welcome contributions! See [DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) for details.

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/devdock.git

# Create feature branch
git checkout -b feature/amazing-feature

# Make changes and test
# ...

# Commit and push
git commit -m "feat: Add amazing feature"
git push origin feature/amazing-feature

# Open Pull Request
```

## Roadmap

- [x] **v1.0** - Flutter support with hot reload
- [x] **v1.0** - React Native basic support
- [ ] **v1.1** - Full React Native with Fast Refresh
- [ ] **v1.2** - Native iOS/Android build support
- [ ] **v2.0** - Multiple project tabs
- [ ] **v2.0** - Custom run configurations

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/swiftui/)
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)
- Inspired by the need to reduce context switching

---

<p align="center">
  Made with ❤️ for mobile developers
</p>
