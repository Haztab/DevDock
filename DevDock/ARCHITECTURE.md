# DevDock Architecture

## Overview

DevDock is a lightweight macOS floating utility app that enables mobile developers to run, stop, and hot-reload their apps (Flutter/React Native/Android/iOS) via a minimal GUI instead of terminal commands.

## Technology Stack

- **Platform**: macOS Sonoma+ (14.0+)
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Clean Architecture layers
- **Async**: Swift Concurrency (async/await)
- **Reactive**: Combine framework for event streaming

## Project Structure

```
DevDock/
├── App/
│   └── DevDockApp.swift          # Main entry point & window configuration
├── Models/
│   ├── ProjectType.swift         # Project type enum (Flutter, RN, etc.)
│   ├── Device.swift              # Device/emulator models
│   ├── LogEntry.swift            # Log entry model with level detection
│   └── ProcessState.swift        # Process state & run configuration
├── Services/
│   ├── CommandRunner.swift       # Process execution with stdin streaming
│   ├── DeviceManager.swift       # Device/emulator detection (adb, simctl)
│   ├── ProjectDetector.swift     # Auto-detect project types
│   └── LogProcessor.swift        # Log parsing & filtering
├── ViewModels/
│   └── AppState.swift            # Main app state coordinator
├── Views/
│   ├── ContentView.swift         # Main content & header views
│   ├── SettingsView.swift        # Settings window
│   └── Components/
│       ├── ControlsView.swift    # Platform, device, action buttons
│       └── LogViewerView.swift   # Real-time log viewer
└── Extensions/
    ├── Color+Extensions.swift    # Theme colors
    └── View+KeyboardShortcuts.swift  # Menu action handlers
```

## Core Components

### 1. CommandRunner (Services/CommandRunner.swift)

The heart of process execution. Key features:
- Uses Swift `Process` for CLI command execution
- Keeps `stdin` pipe open for interactive commands (hot reload)
- Streams `stdout`/`stderr` in real-time via Combine publishers
- Handles graceful shutdown (sends `q` for Flutter before terminating)

```swift
// Example: Running a Flutter app
try await commandRunner.run(configuration: config)

// Hot reload (sends 'r' to stdin)
try await commandRunner.hotReload()

// Hot restart (sends 'R' to stdin)
try await commandRunner.hotRestart()
```

### 2. DeviceManager (Services/DeviceManager.swift)

Detects connected devices and emulators:
- **Android**: Parses `adb devices -l` output
- **iOS**: Parses `xcrun simctl list devices --json` output
- Can boot/shutdown iOS simulators

### 3. LogProcessor (Services/LogProcessor.swift)

Processes and categorizes log output:
- Detects log levels (Error, Warning, Info, Debug)
- Parses platform-specific formats (Flutter, Android logcat, React Native)
- Maintains filterable log buffer (max 5000 entries by default)
- Supports export to file

### 4. ProjectDetector (Services/ProjectDetector.swift)

Auto-detects project types:
- **Flutter**: `pubspec.yaml`
- **React Native**: `package.json` with `react-native` dependency
- **Android**: `build.gradle` or `build.gradle.kts`
- **iOS**: `.xcodeproj` or `.xcworkspace`

### 5. AppState (ViewModels/AppState.swift)

Main coordinator that:
- Manages project/device selection state
- Coordinates between services
- Handles user actions (run, stop, reload)
- Persists recent projects via security-scoped bookmarks

## Data Flow

```
User Action → AppState → CommandRunner → Process (CLI)
                              ↓
                        stdout/stderr
                              ↓
                        LogProcessor
                              ↓
                        LogViewerView
```

## Window Configuration

The app uses a floating panel design:
- Always-on-top (`NSWindow.level = .floating`)
- Can join all spaces
- Hidden title bar with transparent background
- Positioned on right edge of screen by default
- Menu bar status item for quick toggle

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Run | ⌘R |
| Stop | ⌘. |
| Hot Reload | ⇧⌘R |
| Hot Restart | ⌥⇧⌘R |
| Refresh Devices | ⇧⌘D |
| Clear Logs | ⌘K |
| Export Logs | ⇧⌘E |
| Toggle Auto-Scroll | ⌥⌘S |

## Platform-Specific Commands

### Flutter
```bash
flutter run -d <device_id>
# Hot reload: send 'r' to stdin
# Hot restart: send 'R' to stdin
# Quit: send 'q' to stdin
```

### React Native
```bash
npx react-native run-android --deviceId <device_id>
npx react-native run-ios --simulator "<simulator_name>"
```

### Native Android
```bash
./gradlew installDebug
```

### Native iOS
```bash
xcodebuild -scheme <scheme> -destination "id=<device_id>"
```

## Security Considerations

- Uses security-scoped bookmarks for file system access
- Inherits user's PATH for tool discovery
- No network communication (fully offline)

## Future Enhancements

1. **Phase 2**: Full xcodebuild support for native iOS
2. **Phase 3**: Custom run configurations per project
3. **Phase 4**: Build flavors/schemes selection
4. **Phase 5**: Log search with regex support
5. **Phase 6**: Device screen mirroring integration

## Assumptions & Limitations

### Assumptions
- Flutter/React Native CLI tools are installed and in PATH
- Android SDK with ADB is installed for Android development
- Xcode with Command Line Tools is installed for iOS development
- macOS Sonoma (14.0) or later

### Current Limitations
1. **No Electron/Web**: Native macOS only
2. **Single process**: One app running at a time
3. **No build configuration**: Uses default debug builds
4. **iOS physical devices**: Basic support (signing handled by tools)
5. **No custom environment variables**: Uses inherited environment

### Known Issues
- First run may need Full Disk Access for some project paths
- Some Flutter versions may have different stdin behavior
