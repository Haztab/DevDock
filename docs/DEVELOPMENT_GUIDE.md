# DevDock - Development Guide

**Version:** 1.0
**Last Updated:** 2026-02-06

---

## 1. Getting Started

### 1.1 Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| macOS | 14.0+ (Sonoma) | Development platform |
| Xcode | 15.0+ | IDE and build tools |
| Swift | 5.9+ | Programming language |
| Git | 2.0+ | Version control |

**Optional (for testing):**
| Tool | Purpose |
|------|---------|
| Flutter SDK | Test Flutter project detection/running |
| Android Studio | Android emulator management |
| Node.js + npm | Test React Native support |

### 1.2 Project Setup

```bash
# Clone the repository
git clone https://github.com/yourorg/devdock.git
cd devdock

# Open in Xcode
open DevDock.xcodeproj

# Or create new Xcode project and import files
```

### 1.3 Creating Xcode Project from Source

1. Open Xcode
2. **File → New → Project**
3. Select **macOS → App**
4. Configure:
   - Product Name: `DevDock`
   - Team: Your Development Team
   - Organization Identifier: `com.yourorg`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Delete auto-generated files (`ContentView.swift`, `DevDockApp.swift`)
6. Drag the `DevDock/` source folder into the project
7. Set deployment target: **macOS 14.0**

---

## 2. Project Structure

```
DevDock/
├── DevDock.xcodeproj          # Xcode project file
├── docs/                      # Documentation
│   ├── PRD.md
│   ├── TECHNICAL_SPEC.md
│   ├── DEVELOPMENT_GUIDE.md
│   └── TASK_TRACKER.md
├── ARCHITECTURE.md            # High-level architecture
└── DevDock/                   # Source code
    ├── App/
    │   └── DevDockApp.swift   # Main entry point
    ├── Models/
    │   ├── ProjectType.swift
    │   ├── Device.swift
    │   ├── LogEntry.swift
    │   └── ProcessState.swift
    ├── Services/
    │   ├── CommandRunner.swift
    │   ├── DeviceManager.swift
    │   ├── ProjectDetector.swift
    │   └── LogProcessor.swift
    ├── ViewModels/
    │   └── AppState.swift
    ├── Views/
    │   ├── ContentView.swift
    │   ├── SettingsView.swift
    │   └── Components/
    │       ├── ControlsView.swift
    │       └── LogViewerView.swift
    └── Extensions/
        ├── Color+Extensions.swift
        └── View+KeyboardShortcuts.swift
```

---

## 3. Build Configuration

### 3.1 Signing & Capabilities

In **Signing & Capabilities** tab:

```
☑ Automatically manage signing
☑ Team: Your Development Team

Capabilities:
☑ App Sandbox (for Mac App Store)
  ☑ User Selected File (Read/Write)
  ☑ Network: Outgoing Connections (for future features)
```

**Note:** For development, you may disable App Sandbox to avoid permission issues.

### 3.2 Build Settings

```
MACOSX_DEPLOYMENT_TARGET = 14.0
SWIFT_VERSION = 5.0
ENABLE_HARDENED_RUNTIME = YES
```

### 3.3 Info.plist Additions

```xml
<!-- Allow terminal command execution -->
<key>NSAppleEventsUsageDescription</key>
<string>DevDock needs to run development tools.</string>

<!-- App category -->
<key>LSApplicationCategoryType</key>
<string>public.app-category.developer-tools</string>
```

---

## 4. Development Workflow

### 4.1 Running the App

1. Select **DevDock** scheme
2. Select **My Mac** as destination
3. Press **⌘R** to build and run

### 4.2 Testing with Sample Projects

Create test projects for each platform:

```bash
# Flutter
flutter create test_flutter_app

# React Native
npx react-native init TestRNApp

# Android (use Android Studio to create)

# iOS (use Xcode to create)
```

### 4.3 Debugging Tips

**View Process Output:**
```swift
// Add to CommandRunner for debugging
print("[DEBUG] stdout: \(output)")
print("[DEBUG] stderr: \(error)")
```

**Check Device Detection:**
```bash
# Verify adb works
adb devices -l

# Verify simctl works
xcrun simctl list devices --json
```

**SwiftUI Preview:**
```swift
#Preview {
    ContentView()
}
```

---

## 5. Code Style Guide

### 5.1 File Organization

Each Swift file should follow this structure:

```swift
import Foundation
import SwiftUI  // If needed
import Combine  // If needed

// MARK: - Main Type

/// Documentation for the type
struct/class/enum TypeName {
    // MARK: - Properties

    // MARK: - Initialization

    // MARK: - Public Methods

    // MARK: - Private Methods
}

// MARK: - Extensions

extension TypeName {
    // Additional functionality
}

// MARK: - Preview (Views only)

#Preview {
    TypeName()
}
```

### 5.2 Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `CommandRunner` |
| Properties | camelCase | `selectedDevice` |
| Methods | camelCase | `refreshDevices()` |
| Constants | camelCase | `maxLogEntries` |
| Enums | PascalCase + camelCase | `ProcessState.running` |

### 5.3 SwiftUI Best Practices

```swift
// ✅ Good: Small, focused views
struct DeviceSelector: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Picker("Device", selection: $appState.selectedDevice) {
            // ...
        }
    }
}

// ❌ Bad: Massive view with all logic inline
struct ContentView: View {
    var body: some View {
        VStack {
            // 500 lines of code...
        }
    }
}
```

### 5.4 Async/Await Guidelines

```swift
// ✅ Good: Proper async handling
func run() async {
    do {
        try await commandRunner.run(configuration: config)
    } catch {
        await MainActor.run {
            showAlert(error.localizedDescription)
        }
    }
}

// ❌ Bad: Blocking the main thread
func run() {
    Task {
        try? await commandRunner.run(configuration: config)
    }
    // No error handling, potential race conditions
}
```

---

## 6. Adding New Features

### 6.1 Adding a New Project Type

1. **Update `ProjectType` enum:**
```swift
enum ProjectType: String, CaseIterable {
    // ... existing cases
    case kotlin = "Kotlin Multiplatform"

    var detectionMarkers: [String] {
        switch self {
        // ... existing cases
        case .kotlin:
            return ["build.gradle.kts"] // with KMP plugin
        }
    }
}
```

2. **Update `ProjectDetector`:**
```swift
static func detectProjectType(at url: URL) -> ProjectType {
    // Add detection logic
    if isKotlinMultiplatform(at: url) {
        return .kotlin
    }
    // ... existing logic
}
```

3. **Update `RunConfiguration`:**
```swift
func buildCommand() -> (executable: String, arguments: [String])? {
    switch project.type {
    // ... existing cases
    case .kotlin:
        return buildKotlinCommand()
    }
}
```

### 6.2 Adding a New Log Parser

```swift
// In LogProcessor.swift
private func parseKotlinLog(_ line: String) -> LogEntry? {
    // Kotlin/Gradle specific patterns
    if line.contains("BUILD SUCCESSFUL") {
        return LogEntry(rawText: line, level: .info)
    }
    if line.contains("BUILD FAILED") {
        return LogEntry(rawText: line, level: .error)
    }
    return nil
}
```

### 6.3 Adding a New UI Component

1. Create new file in `Views/Components/`
2. Follow existing component patterns
3. Use `@EnvironmentObject` for AppState access
4. Add preview at bottom of file

```swift
import SwiftUI

struct NewComponent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // Your UI here
    }
}

#Preview {
    NewComponent()
        .environmentObject(AppState())
}
```

---

## 7. Testing

### 7.1 Unit Test Structure

```swift
import XCTest
@testable import DevDock

final class ProjectDetectorTests: XCTestCase {

    func testDetectsFlutterProject() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: tempDir.appendingPathComponent("pubspec.yaml").path,
            contents: nil
        )

        // When
        let type = ProjectDetector.detectProjectType(at: tempDir)

        // Then
        XCTAssertEqual(type, .flutter)

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }
}
```

### 7.2 Mock Services

```swift
class MockCommandRunner: CommandRunnerProtocol {
    var runCalled = false
    var stopCalled = false
    var lastConfiguration: RunConfiguration?

    func run(configuration: RunConfiguration) async throws {
        runCalled = true
        lastConfiguration = configuration
    }

    func stop() async {
        stopCalled = true
    }

    // ... other protocol requirements
}
```

### 7.3 Running Tests

```bash
# Command line
xcodebuild test -scheme DevDock -destination 'platform=macOS'

# Or use Xcode: ⌘U
```

---

## 8. Debugging

### 8.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Command not found" | Tool not in PATH | Check PATH includes Homebrew, Flutter SDK |
| No devices showing | ADB/simctl not installed | Install Android SDK or Xcode CLI tools |
| Hot reload not working | stdin pipe closed | Check process is still running |
| Logs not appearing | Publisher not connected | Verify `subscribe(to:)` called |
| Window not floating | Level not set | Check `window.level = .floating` |

### 8.2 Logging for Development

Add temporary logging:

```swift
#if DEBUG
print("[DevDock] \(message)")
#endif
```

### 8.3 LLDB Commands

```lldb
# Print AppState
po appState

# Print current process state
po appState.commandRunner.state

# Print device list
po appState.deviceManager.androidDevices
```

---

## 9. Performance Profiling

### 9.1 Instruments Templates

| Template | Use Case |
|----------|----------|
| Time Profiler | CPU usage, slow methods |
| Allocations | Memory leaks |
| Leaks | Retain cycles |
| SwiftUI | View body calls |

### 9.2 Key Metrics to Monitor

```swift
// Log rendering performance
let start = CFAbsoluteTimeGetCurrent()
// ... render logs
let elapsed = CFAbsoluteTimeGetCurrent() - start
print("Log render: \(elapsed * 1000)ms")
```

---

## 10. Release Process

### 10.1 Pre-Release Checklist

- [ ] All tests passing
- [ ] No compiler warnings
- [ ] Version number updated
- [ ] CHANGELOG updated
- [ ] Archive builds successfully
- [ ] Tested on Intel and Apple Silicon
- [ ] Tested on macOS Sonoma and later

### 10.2 Building for Release

```bash
# Archive
xcodebuild archive \
  -scheme DevDock \
  -archivePath build/DevDock.xcarchive

# Export for direct distribution
xcodebuild -exportArchive \
  -archivePath build/DevDock.xcarchive \
  -exportPath build/DevDock \
  -exportOptionsPlist ExportOptions.plist
```

### 10.3 Code Signing

For distribution outside App Store:

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  DevDock.app
```

---

## 11. Contributing

### 11.1 Branch Strategy

```
main          # Stable releases
├── develop   # Integration branch
├── feature/* # New features
├── fix/*     # Bug fixes
└── release/* # Release preparation
```

### 11.2 Pull Request Process

1. Create feature branch from `develop`
2. Implement changes with tests
3. Update documentation if needed
4. Open PR with description
5. Address review feedback
6. Squash and merge

### 11.3 Commit Messages

```
feat: Add Kotlin Multiplatform support
fix: Resolve hot reload stdin issue
docs: Update development guide
refactor: Extract log parsing logic
test: Add ProjectDetector unit tests
```

---

## 12. Resources

### 12.1 Documentation

- [Swift Documentation](https://docs.swift.org)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)

### 12.2 Tools

- [Flutter CLI Reference](https://docs.flutter.dev/reference/flutter-cli)
- [React Native CLI](https://reactnative.dev/docs/environment-setup)
- [ADB Documentation](https://developer.android.com/studio/command-line/adb)
- [simctl Guide](https://nshipster.com/simctl/)

### 12.3 Design References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
