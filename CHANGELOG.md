# Changelog

All notable changes to DevDock will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Fast Refresh support for React Native
- Full xcodebuild integration for native iOS
- Gradle build support for native Android
- Multiple project tabs
- Custom run configurations

---

## [1.0.0] - 2026-02-06

### Added

#### Core Features
- **Project Detection**: Automatic detection of Flutter, React Native, Android, and iOS projects
- **Device Management**: Real-time detection of Android devices/emulators and iOS simulators
- **Process Execution**: Run mobile apps with a single click
- **Hot Reload**: Flutter hot reload (`r`) and hot restart (`R`) support
- **Real-time Logs**: Streaming log viewer with color-coded levels

#### User Interface
- **Floating Panel**: Always-on-top window that sticks to screen edges
- **Minimal Design**: Clean 320px wide interface
- **Dark Mode**: Full support for macOS dark mode
- **Menu Bar Icon**: Quick access from the menu bar
- **Keyboard Shortcuts**: All actions accessible via shortcuts

#### Log Viewer
- Filter by level (Error, Warning, Info, Debug)
- Text search within logs
- Auto-scroll toggle
- Export logs to file
- Error/warning count badges

#### Platform Support
- **Flutter**: Full support including hot reload
- **React Native**: Basic run support for Android and iOS
- **Android**: Device and emulator detection via ADB
- **iOS**: Simulator detection and management via simctl

### Technical
- Built with SwiftUI for native macOS experience
- MVVM architecture with clean separation
- Swift Concurrency (async/await) for process management
- Combine framework for reactive state updates
- Security-scoped bookmarks for project persistence

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for iOS development)
- Flutter SDK (for Flutter projects)
- Android SDK with ADB (for Android development)
- Node.js (for React Native projects)

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 | 2026-02-06 | Initial release with Flutter support |

---

## Upgrade Notes

### 1.0.0
First release - no upgrade notes.

---

## Known Issues

### 1.0.0
- iOS physical device support is limited (requires proper provisioning)
- Some Flutter versions may have different stdin behavior for hot reload
- Large log volumes (>5000 entries) may impact scroll performance

---

[Unreleased]: https://github.com/yourorg/devdock/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourorg/devdock/releases/tag/v1.0.0
