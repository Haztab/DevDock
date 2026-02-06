# DevDock - Technical Specification

**Version:** 1.0
**Last Updated:** 2026-02-06
**Status:** Implementation Complete (Core Features)

---

## 1. System Overview

### 1.1 Architecture Pattern
DevDock follows **MVVM (Model-View-ViewModel)** combined with **Clean Architecture** principles:

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    SwiftUI Views                         ││
│  │  ContentView, ControlsView, LogViewerView, SettingsView ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ @EnvironmentObject
┌─────────────────────────────────────────────────────────────┐
│                      ViewModel Layer                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                      AppState                            ││
│  │  @Published state, user action handlers, coordination   ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ Dependency Injection
┌─────────────────────────────────────────────────────────────┐
│                       Service Layer                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │CommandRunner │ │DeviceManager │ │    LogProcessor      │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                   ProjectDetector                        ││
│  └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Model Layer                           │
│  Project, Device, LogEntry, ProcessState, RunConfiguration  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow

```
User Interaction
       │
       ▼
   SwiftUI View
       │
       ▼ Action call
   AppState (ViewModel)
       │
       ├──▶ CommandRunner.run()
       │         │
       │         ▼
       │    Process (CLI)
       │         │
       │         ├──▶ stdout ──▶ LogProcessor ──▶ @Published entries
       │         │
       │         └──▶ stderr ──▶ LogProcessor ──▶ @Published entries
       │
       └──▶ DeviceManager.refresh()
                 │
                 ▼
            adb / simctl
                 │
                 ▼
            @Published devices
```

---

## 2. Component Specifications

### 2.1 CommandRunner

**Purpose:** Execute CLI commands with real-time I/O streaming

**File:** `Services/CommandRunner.swift`

**Key Features:**
- Asynchronous process execution using Swift `Process`
- Maintains open stdin pipe for interactive commands
- Streams stdout/stderr via Combine publishers
- Graceful shutdown with process cleanup

**Interface:**
```swift
protocol CommandRunnerProtocol {
    var outputPublisher: AnyPublisher<String, Never> { get }
    var errorPublisher: AnyPublisher<String, Never> { get }
    var statePublisher: AnyPublisher<ProcessState, Never> { get }

    func run(configuration: RunConfiguration) async throws
    func stop() async
    func sendInput(_ input: String) async throws
    func hotReload() async throws
    func hotRestart() async throws
}
```

**Process Lifecycle:**
```
idle ──▶ starting ──▶ running ──▶ stopping ──▶ idle
                         │
                         └──▶ failed
```

**Critical Implementation Details:**

1. **stdin Handling for Hot Reload:**
```swift
func sendInput(_ input: String) async throws {
    guard let stdinPipe = stdinPipe,
          let process = process,
          process.isRunning else {
        throw ProcessError.processNotRunning
    }

    let data = Data((input + "\n").utf8)
    try stdinPipe.fileHandleForWriting.write(contentsOf: data)
}
```

2. **Executable Path Resolution:**
```swift
private func findExecutablePath(_ executable: String) async throws -> String {
    let searchPaths = [
        "/usr/local/bin/\(executable)",
        "/opt/homebrew/bin/\(executable)",  // Apple Silicon Homebrew
        "/usr/bin/\(executable)",
        "\(NSHomeDirectory())/.pub-cache/bin/\(executable)",  // Flutter
        "\(NSHomeDirectory())/fvm/default/bin/\(executable)"  // FVM
    ]
    // ... search logic
}
```

3. **Output Streaming:**
```swift
private func startReadingOutput(from pipe: Pipe, isError: Bool) {
    Task.detached { [weak self] in
        while !Task.isCancelled {
            let data = pipe.fileHandleForReading.availableData
            guard !data.isEmpty else { break }  // EOF

            if let output = String(data: data, encoding: .utf8) {
                await MainActor.run {
                    subject.send(output)
                }
            }
        }
    }
}
```

---

### 2.2 DeviceManager

**Purpose:** Detect and manage connected devices/emulators

**File:** `Services/DeviceManager.swift`

**Detection Methods:**

| Platform | Command | Output Format |
|----------|---------|---------------|
| Android | `adb devices -l` | Text (line-based) |
| iOS | `xcrun simctl list devices --json` | JSON |
| Flutter | `flutter devices --machine` | JSON |

**Android Device Parsing:**
```
Input: "emulator-5554 device product:sdk_gphone64_arm64 model:Pixel_6"

Output: Device(
    id: "emulator-5554",
    name: "Pixel 6",
    platform: .android,
    type: .emulator,
    state: .connected
)
```

**iOS Simulator Parsing:**
```json
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
      {
        "name": "iPhone 15 Pro",
        "udid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        "state": "Booted",
        "isAvailable": true
      }
    ]
  }
}
```

---

### 2.3 LogProcessor

**Purpose:** Parse, categorize, and filter log output

**File:** `Services/LogProcessor.swift`

**Log Level Detection:**
```swift
static func detect(from text: String) -> LogLevel {
    let uppercased = text.uppercased()

    // Error patterns
    if uppercased.contains("ERROR") ||
       uppercased.contains("EXCEPTION") ||
       text.contains("E/") {  // Android logcat
        return .error
    }

    // Warning patterns
    if uppercased.contains("WARN") ||
       text.contains("W/") {
        return .warning
    }

    // Debug patterns
    if uppercased.contains("DEBUG") ||
       text.contains("D/") {
        return .debug
    }

    return .info
}
```

**Platform-Specific Parsing:**

| Platform | Pattern | Example |
|----------|---------|---------|
| Flutter | `flutter: <message>` | `flutter: Building widgets...` |
| Android | `D/Tag(PID): message` | `I/flutter(12345): Hello` |
| React Native | `LOG/WARN/ERROR <message>` | `ERROR TypeError: ...` |

**Memory Management:**
- Maximum entries: 5,000 (configurable)
- FIFO eviction when limit exceeded
- Entries stored as lightweight structs

---

### 2.4 ProjectDetector

**Purpose:** Auto-detect mobile project types

**File:** `Services/ProjectDetector.swift`

**Detection Priority:**
1. **Flutter:** Check for `pubspec.yaml`
2. **React Native:** Check `package.json` for `react-native` dependency
3. **Android:** Check for `build.gradle` or `build.gradle.kts`
4. **iOS:** Check for `.xcodeproj` or `.xcworkspace`

**Security-Scoped Bookmarks:**
```swift
// Save project with security-scoped bookmark
let bookmark = try project.path.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Restore project
var isStale = false
let url = try URL(
    resolvingBookmarkData: bookmark,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
_ = url.startAccessingSecurityScopedResource()
defer { url.stopAccessingSecurityScopedResource() }
```

---

### 2.5 AppState (ViewModel)

**Purpose:** Central coordinator for all app state

**File:** `ViewModels/AppState.swift`

**State Properties:**
```swift
@MainActor
final class AppState: ObservableObject {
    // Services
    let commandRunner: CommandRunner
    let deviceManager: DeviceManager
    let logProcessor: LogProcessor

    // Project state
    @Published var currentProject: Project?
    @Published var recentProjects: [Project] = []

    // Selection state
    @Published var selectedPlatform: Platform = .android
    @Published var selectedDevice: Device?

    // UI state
    @Published var isShowingProjectPicker: Bool = false
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""
}
```

**Computed Properties:**
```swift
var canRun: Bool {
    currentProject != nil &&
    selectedDevice != nil &&
    !commandRunner.state.isRunning
}

var canHotReload: Bool {
    commandRunner.state == .running &&
    currentProject?.type == .flutter
}
```

---

## 3. Data Models

### 3.1 Project
```swift
struct Project: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let name: String       // Derived from path.lastPathComponent
    let type: ProjectType
}

enum ProjectType: String, CaseIterable {
    case flutter = "Flutter"
    case reactNative = "React Native"
    case android = "Android"
    case ios = "iOS"
    case unknown = "Unknown"
}
```

### 3.2 Device
```swift
struct Device: Identifiable, Hashable {
    let id: String         // ADB ID or Simulator UDID
    let name: String       // Display name
    let platform: Platform
    let type: DeviceType   // physical or emulator
    let state: DeviceState // connected, booting, offline
}

enum Platform: String {
    case android = "Android"
    case iOS = "iOS"
}
```

### 3.3 LogEntry
```swift
struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel    // debug, info, warning, error
    let message: String    // Cleaned message
    let rawText: String    // Original text
}
```

### 3.4 ProcessState
```swift
enum ProcessState: Equatable {
    case idle
    case starting
    case running
    case stopping
    case failed(Error)
}
```

### 3.5 RunConfiguration
```swift
struct RunConfiguration {
    let project: Project
    let platform: Platform
    let device: Device
    let additionalArgs: [String]

    func buildCommand() -> (executable: String, arguments: [String])?
}
```

---

## 4. CLI Command Reference

### 4.1 Flutter Commands
```bash
# Run on specific device
flutter run -d <device_id>

# Hot reload (send to stdin)
r\n

# Hot restart (send to stdin)
R\n

# Quit (send to stdin)
q\n
```

### 4.2 React Native Commands
```bash
# Android
npx react-native run-android --deviceId <device_id>

# iOS Simulator
npx react-native run-ios --simulator "<simulator_name>"

# iOS Physical Device
npx react-native run-ios --device "<device_name>"
```

### 4.3 Device Detection Commands
```bash
# Android devices
adb devices -l

# iOS simulators
xcrun simctl list devices --json

# Boot iOS simulator
xcrun simctl boot <udid>

# Shutdown iOS simulator
xcrun simctl shutdown <udid>
```

---

## 5. Window Configuration

### 5.1 NSWindow Settings
```swift
window.level = .floating                    // Always on top
window.collectionBehavior = [
    .canJoinAllSpaces,                      // Visible on all desktops
    .fullScreenAuxiliary                    // Works with full-screen apps
]
window.titlebarAppearsTransparent = true    // Clean look
window.titleVisibility = .hidden            // No title
window.isOpaque = false
window.backgroundColor = .clear
```

### 5.2 Window Dimensions
```swift
.frame(width: 320, minHeight: 400, maxHeight: 700)
```

### 5.3 Positioning
```swift
func positionWindowOnRight(_ window: NSWindow) {
    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.visibleFrame
    let windowFrame = window.frame

    let x = screenFrame.maxX - windowFrame.width - 20  // 20px margin
    let y = screenFrame.midY - (windowFrame.height / 2)

    window.setFrameOrigin(NSPoint(x: x, y: y))
}
```

---

## 6. Error Handling

### 6.1 Error Types
```swift
enum ProcessError: LocalizedError {
    case unknown
    case processNotRunning
    case commandNotFound(String)
    case executionFailed(String)
    case deviceNotConnected
    case projectNotDetected
}
```

### 6.2 Error Recovery
| Error | Recovery Action |
|-------|-----------------|
| Command not found | Show install instructions |
| Device disconnected | Refresh device list |
| Process crash | Reset to idle state |
| Permission denied | Request Full Disk Access |

---

## 7. Testing Strategy

### 7.1 Unit Tests
| Component | Test Coverage |
|-----------|---------------|
| ProjectDetector | Project type detection |
| LogProcessor | Log level parsing |
| RunConfiguration | Command building |
| DeviceManager | Output parsing |

### 7.2 Integration Tests
- CommandRunner with mock Process
- End-to-end run/stop cycle
- Device detection with mock CLI output

### 7.3 UI Tests
- Project selection flow
- Device switching
- Log filtering
- Keyboard shortcuts

---

## 8. Performance Considerations

### 8.1 Log Rendering
- Use `LazyVStack` for virtualized scrolling
- Limit to 5,000 entries in memory
- Debounce rapid log updates (16ms)

### 8.2 Device Detection
- Cache results for 30 seconds
- Background refresh on app activation
- Parallel detection for Android/iOS

### 8.3 Process Management
- Non-blocking I/O with async/await
- Separate tasks for stdout/stderr reading
- Immediate cleanup on stop

---

## 9. Security Considerations

### 9.1 File System Access
- Use security-scoped bookmarks for saved projects
- Request minimal permissions
- No automatic file modifications

### 9.2 Process Execution
- Inherit user's PATH safely
- No shell injection (direct Process execution)
- Sanitize display of command output

### 9.3 Data Storage
- UserDefaults for preferences
- Bookmarks for project paths
- No sensitive data storage

---

## 10. Future Technical Considerations

### 10.1 Plugin System (v2.0)
```swift
protocol DevDockPlugin {
    var id: String { get }
    var supportedProjectTypes: [ProjectType] { get }

    func buildCommand(for config: RunConfiguration) -> (String, [String])
    func parseLog(_ line: String) -> LogEntry?
}
```

### 10.2 Multi-Window Support
- Each window manages its own AppState
- Shared DeviceManager across windows
- Process isolation per project

### 10.3 Remote Development
- SSH tunnel support
- Remote device detection
- Log streaming over network
