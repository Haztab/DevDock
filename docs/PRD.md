# DevDock - Product Requirements Document (PRD)

**Version:** 1.0
**Last Updated:** 2026-02-06
**Status:** In Development
**Author:** DevDock Team

---

## 1. Executive Summary

### 1.1 Product Vision
DevDock is a lightweight macOS utility application that enables mobile developers to run, stop, and hot-reload their mobile applications without using the terminal. It provides a minimal, always-visible floating panel that reduces context switching and streamlines the development workflow.

### 1.2 Problem Statement
Mobile developers frequently switch between their IDE, terminal, and emulator/simulator when developing apps. This context switching:
- Breaks concentration and flow state
- Requires memorizing CLI commands
- Makes it harder to monitor logs while coding
- Increases cognitive load for simple operations

### 1.3 Solution
DevDock provides a persistent, minimal GUI that:
- Floats alongside the IDE
- Auto-detects project types
- Shows available devices/emulators
- Provides one-click run/stop/reload
- Displays real-time, filterable logs

---

## 2. Target Users

### 2.1 Primary Personas

#### Persona 1: Flutter Developer - "Alex"
- **Role:** Mobile developer at startup
- **Experience:** 2-3 years
- **Pain Points:**
  - Forgets Flutter CLI commands
  - Struggles to find the right device ID
  - Loses log output when terminal scrolls
- **Goals:**
  - Quick iteration with hot reload
  - Easy switching between iOS and Android
  - Readable error logs

#### Persona 2: React Native Developer - "Jordan"
- **Role:** Frontend developer transitioning to mobile
- **Experience:** 1 year in mobile
- **Pain Points:**
  - Complex Metro bundler commands
  - Different commands for iOS vs Android
  - Difficulty parsing RN error messages
- **Goals:**
  - Unified interface for both platforms
  - Clear error highlighting
  - Fast project switching

#### Persona 3: Native Mobile Developer - "Sam"
- **Role:** Senior iOS/Android developer
- **Experience:** 5+ years
- **Pain Points:**
  - Xcode build times
  - Gradle configuration issues
  - Managing multiple simulators
- **Goals:**
  - Quick simulator management
  - Build status visibility
  - Log filtering by severity

### 2.2 User Demographics
- **Platform:** macOS users only
- **Development Tools:** VS Code, Android Studio, Xcode, IntelliJ
- **Frameworks:** Flutter (primary), React Native, Native iOS/Android
- **Experience Level:** Junior to Senior developers

---

## 3. Product Requirements

### 3.1 Functional Requirements

#### FR-001: Project Management
| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-001.1 | Select project folder via file picker | P0 | ✅ Done |
| FR-001.2 | Auto-detect project type (Flutter/RN/Android/iOS) | P0 | ✅ Done |
| FR-001.3 | Store and display recent projects (max 10) | P1 | ✅ Done |
| FR-001.4 | Remove project from recent list | P2 | ✅ Done |
| FR-001.5 | Pin favorite projects | P3 | ⬜ Planned |

#### FR-002: Device Management
| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-002.1 | Detect Android devices via `adb devices` | P0 | ✅ Done |
| FR-002.2 | Detect iOS simulators via `simctl` | P0 | ✅ Done |
| FR-002.3 | Refresh device list on demand | P0 | ✅ Done |
| FR-002.4 | Display device type (physical/emulator) | P1 | ✅ Done |
| FR-002.5 | Boot/shutdown iOS simulators | P2 | ✅ Done |
| FR-002.6 | Launch Android emulator | P3 | ⬜ Planned |
| FR-002.7 | Detect physical iOS devices | P3 | ⬜ Planned |

#### FR-003: App Execution
| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-003.1 | Run Flutter apps with `flutter run` | P0 | ✅ Done |
| FR-003.2 | Stop running process gracefully | P0 | ✅ Done |
| FR-003.3 | Hot reload Flutter apps (send 'r') | P0 | ✅ Done |
| FR-003.4 | Hot restart Flutter apps (send 'R') | P0 | ✅ Done |
| FR-003.5 | Run React Native apps | P1 | ✅ Done |
| FR-003.6 | Prevent multiple simultaneous runs | P0 | ✅ Done |
| FR-003.7 | Run native Android apps (Gradle) | P2 | 🔄 Basic |
| FR-003.8 | Run native iOS apps (xcodebuild) | P2 | 🔄 Basic |
| FR-003.9 | Custom run arguments | P3 | ⬜ Planned |

#### FR-004: Log Viewer
| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-004.1 | Stream logs in real-time | P0 | ✅ Done |
| FR-004.2 | Color-code by log level | P0 | ✅ Done |
| FR-004.3 | Filter by log level | P0 | ✅ Done |
| FR-004.4 | Search/filter by text | P1 | ✅ Done |
| FR-004.5 | Auto-scroll with toggle | P1 | ✅ Done |
| FR-004.6 | Clear logs | P1 | ✅ Done |
| FR-004.7 | Export logs to file | P2 | ✅ Done |
| FR-004.8 | Copy individual log entries | P2 | ✅ Done |
| FR-004.9 | Error/warning count badges | P2 | ✅ Done |
| FR-004.10 | Regex search | P3 | ⬜ Planned |

#### FR-005: Window Behavior
| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-005.1 | Floating panel (always on top) | P0 | ✅ Done |
| FR-005.2 | Minimal window chrome | P0 | ✅ Done |
| FR-005.3 | Position on screen edge | P1 | ✅ Done |
| FR-005.4 | Menu bar status item | P2 | ✅ Done |
| FR-005.5 | Appear on all spaces | P2 | ✅ Done |
| FR-005.6 | Snap to screen edges | P3 | ⬜ Planned |
| FR-005.7 | Resize handle | P3 | ⬜ Planned |

### 3.2 Non-Functional Requirements

#### NFR-001: Performance
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-001.1 | App launch time | < 1 second |
| NFR-001.2 | Memory usage (idle) | < 50 MB |
| NFR-001.3 | Memory usage (running) | < 150 MB |
| NFR-001.4 | Log rendering (5000 entries) | < 16ms frame time |
| NFR-001.5 | Device detection time | < 3 seconds |

#### NFR-002: Compatibility
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-002.1 | macOS version | Sonoma (14.0)+ |
| NFR-002.2 | Apple Silicon | Native support |
| NFR-002.3 | Intel Macs | Supported |
| NFR-002.4 | Flutter versions | 2.0+ |
| NFR-002.5 | React Native versions | 0.60+ |

#### NFR-003: Reliability
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-003.1 | Crash rate | < 0.1% sessions |
| NFR-003.2 | Process cleanup | 100% on stop |
| NFR-003.3 | State persistence | Across restarts |

#### NFR-004: Usability
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-004.1 | Time to first run | < 30 seconds |
| NFR-004.2 | Keyboard shortcuts | All main actions |
| NFR-004.3 | Accessibility | VoiceOver compatible |

---

## 4. User Interface

### 4.1 Main Panel Layout

```
┌─────────────────────────────┐
│ [Icon] MyFlutterApp    [📁] │  ← Header: Project name + folder picker
│ ● Ready                     │  ← Status indicator
├─────────────────────────────┤
│ [Android] [iOS]             │  ← Platform selector tabs
│ ┌─────────────────────┐ [↻] │  ← Device dropdown + refresh
│ │ 📱 Pixel 6 Emulator  ▼│   │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │       ▶ Run             │ │  ← Main action button
│ └─────────────────────────┘ │
│ [🔥 Hot Reload] [↻ Restart] │  ← Secondary actions (Flutter)
├─────────────────────────────┤
│ [All▼] [🔍 Search...] 🔴2 🟡5│  ← Log toolbar
├─────────────────────────────┤
│ ● Building runner...        │  ← Log entries
│ ● Launching lib/main.dart   │
│ ● Syncing files...          │
│ ● Flutter run complete      │
│ ● [ERROR] Null check failed │
│                             │
└─────────────────────────────┘
```

### 4.2 Window Specifications
- **Width:** 320px (fixed)
- **Min Height:** 400px
- **Max Height:** 700px
- **Corner Radius:** 12px
- **Background:** System window background

### 4.3 Color Scheme
| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Background | System | System |
| Error | #FF3B30 | #FF453A |
| Warning | #FF9500 | #FF9F0A |
| Success | #34C759 | #30D158 |
| Info | Primary | Primary |
| Debug | Secondary | Secondary |

---

## 5. Technical Architecture

### 5.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI)                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐ │
│  │ ContentView │ │ControlsView│ │  LogViewerView  │ │
│  └─────────────┘ └─────────────┘ └─────────────────┘ │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                 ViewModel Layer                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │                   AppState                       │ │
│  │  - Project selection     - Device selection     │ │
│  │  - Process coordination  - UI state             │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                  Service Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌────────────────┐  │
│  │CommandRunner│ │DeviceManager│ │  LogProcessor  │  │
│  │             │ │             │ │                │  │
│  │ - Process   │ │ - adb       │ │ - Parse logs   │  │
│  │ - stdin/out │ │ - simctl    │ │ - Filter       │  │
│  └─────────────┘ └─────────────┘ └────────────────┘  │
│  ┌─────────────────────────────────────────────────┐ │
│  │               ProjectDetector                    │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                   System Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌────────────────┐  │
│  │   Process   │ │ FileManager │ │  UserDefaults  │  │
│  │  (Foundation)│ │             │ │                │  │
│  └─────────────┘ └─────────────┘ └────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### 5.2 Technology Stack
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Minimum Deployment:** macOS 14.0 (Sonoma)
- **Architecture:** MVVM + Clean Architecture
- **Async:** Swift Concurrency (async/await)
- **Reactive:** Combine

---

## 6. Release Plan

### 6.1 MVP (v1.0) - Target: Q1 2026
**Focus:** Flutter development workflow

| Feature | Status |
|---------|--------|
| Project detection (Flutter) | ✅ |
| Device detection (Android/iOS) | ✅ |
| Run/Stop/Hot Reload | ✅ |
| Real-time logs with filtering | ✅ |
| Floating panel UI | ✅ |

### 6.2 Version 1.1 - Target: Q2 2026
**Focus:** React Native support

| Feature | Status |
|---------|--------|
| React Native project detection | ✅ |
| React Native run commands | ✅ |
| Metro bundler integration | ⬜ |
| Fast Refresh support | ⬜ |

### 6.3 Version 1.2 - Target: Q3 2026
**Focus:** Native development

| Feature | Status |
|---------|--------|
| Full xcodebuild support | ⬜ |
| Gradle build integration | ⬜ |
| Build scheme selection | ⬜ |
| Build flavors | ⬜ |

### 6.4 Version 2.0 - Target: Q4 2026
**Focus:** Advanced features

| Feature | Status |
|---------|--------|
| Multiple project tabs | ⬜ |
| Custom run configurations | ⬜ |
| Device screen mirroring | ⬜ |
| Plugin system | ⬜ |

---

## 7. Success Metrics

### 7.1 Key Performance Indicators (KPIs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Daily Active Users | 1,000+ | Analytics |
| Session Duration | 2+ hours | Analytics |
| Run Actions per Session | 10+ | Analytics |
| Crash-free Sessions | 99.9% | Crash reporting |
| App Store Rating | 4.5+ | App Store |

### 7.2 User Satisfaction
- Time saved vs terminal: 30%+
- Context switches reduced: 50%+
- Error discovery time: 40% faster

---

## 8. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Flutter CLI changes | High | Medium | Version detection, graceful fallback |
| macOS API deprecation | Medium | Low | Target latest macOS, follow deprecation notices |
| Performance with large logs | Medium | Medium | Virtual scrolling, log limits |
| Process zombie handling | High | Low | Watchdog timer, force kill fallback |

---

## 9. Dependencies

### 9.1 External Tools
| Tool | Required For | Fallback |
|------|--------------|----------|
| Flutter SDK | Flutter projects | Show error message |
| Android SDK (adb) | Android devices | Disable Android platform |
| Xcode CLI Tools | iOS simulators | Disable iOS platform |
| Node.js + npm | React Native | Show error message |

### 9.2 System Requirements
- macOS 14.0 (Sonoma) or later
- 4GB RAM minimum
- 100MB disk space

---

## 10. Appendix

### 10.1 Glossary
| Term | Definition |
|------|------------|
| Hot Reload | Flutter feature that injects updated code without restart |
| Hot Restart | Flutter feature that restarts app with updated code |
| ADB | Android Debug Bridge - CLI tool for Android devices |
| simctl | Xcode tool for managing iOS simulators |
| Metro | React Native JavaScript bundler |

### 10.2 References
- [Flutter CLI Documentation](https://docs.flutter.dev/reference/flutter-cli)
- [React Native CLI](https://reactnative.dev/docs/environment-setup)
- [Apple simctl](https://developer.apple.com/documentation/xcode/simctl)
- [Android ADB](https://developer.android.com/studio/command-line/adb)

---

**Document History**
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-06 | DevDock Team | Initial PRD |
