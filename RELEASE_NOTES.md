# DevDock v1.0.0

**Run mobile apps without terminal** - A lightweight macOS utility for Flutter, React Native, and native mobile developers.

---

## Highlights

- **One-Click Run**: Launch your mobile app with a single click
- **Hot Reload**: Flutter hot reload and restart at your fingertips
- **Real-Time Logs**: Color-coded, filterable log viewer
- **Always Visible**: Floating panel that stays above your IDE
- **Auto-Detection**: Automatically detects project type and available devices

---

## Features

### Project Support
| Framework | Run | Hot Reload | Logs |
|-----------|:---:|:----------:|:----:|
| Flutter | ✅ | ✅ | ✅ |
| React Native | ✅ | - | ✅ |
| Native Android | 🔄 | - | ✅ |
| Native iOS | 🔄 | - | ✅ |

### Device Support
- Android physical devices and emulators (via ADB)
- iOS simulators (via simctl)
- Automatic device refresh

### UI Features
- Floating, always-on-top panel
- Menu bar status icon
- Dark mode support
- Keyboard shortcuts for all actions

---

## Screenshots

<details>
<summary>Click to expand</summary>

### Main Panel
![Main Panel](docs/assets/screenshot-main.png)

### Running State
![Running](docs/assets/screenshot-running.png)

### Log Viewer
![Logs](docs/assets/screenshot-logs.png)

</details>

---

## Installation

### Download
Download `DevDock.dmg` from the assets below.

### Build from Source
```bash
git clone https://github.com/yourorg/devdock.git
cd devdock/DevDock
open DevDock.xcodeproj
# Build with ⌘B, Run with ⌘R
```

---

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (native) and Intel (supported)

### For Development
- Flutter SDK (for Flutter projects)
- Android SDK with ADB (for Android)
- Xcode 15+ (for iOS simulators)
- Node.js (for React Native)

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Run | ⌘R |
| Stop | ⌘. |
| Hot Reload | ⇧⌘R |
| Hot Restart | ⌥⇧⌘R |
| Refresh Devices | ⇧⌘D |
| Clear Logs | ⌘K |

---

## What's Next

- [ ] React Native Fast Refresh support
- [ ] Native iOS xcodebuild integration
- [ ] Native Android Gradle builds
- [ ] Multiple project tabs
- [ ] Custom run configurations

---

## Feedback

Found a bug or have a feature request? [Open an issue](https://github.com/yourorg/devdock/issues/new)

---

**Full Changelog**: [CHANGELOG.md](CHANGELOG.md)
