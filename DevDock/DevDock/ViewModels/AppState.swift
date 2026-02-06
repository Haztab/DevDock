import Foundation
import SwiftUI
import Combine

// MARK: - AppState

/// Central ViewModel that coordinates all application state and user actions.
///
/// `AppState` serves as the main coordinator between UI and services, following the
/// MVVM pattern. It is injected into SwiftUI views via `@EnvironmentObject`.
///
/// ## Responsibilities
/// - **Project Management**: Loading, selecting, and persisting recent projects
/// - **Device Management**: Coordinating device detection and selection
/// - **Process Control**: Run, stop, hot reload, hot restart actions
/// - **Log Management**: Clearing, exporting, and filtering logs
/// - **UI State**: Alerts, dialogs, and view state
///
/// ## Architecture
/// ```
/// SwiftUI Views
///      │
///      ▼ @EnvironmentObject
///  AppState (this class)
///      │
///      ├──▶ CommandRunner (process execution)
///      ├──▶ DeviceManager (device detection)
///      └──▶ LogProcessor (log handling)
/// ```
///
/// ## Thread Safety
/// Marked `@MainActor` to ensure all state updates happen on the main thread.
/// Services handle their own threading internally.
///
/// ## Usage
/// ```swift
/// // In SwiftUI View
/// @EnvironmentObject var appState: AppState
///
/// Button("Run") {
///     Task { await appState.run() }
/// }
/// .disabled(!appState.canRun)
/// ```
@MainActor
final class AppState: ObservableObject {

    // MARK: - Services

    /// Handles CLI process execution and I/O streaming
    let commandRunner: CommandRunner

    /// Detects connected devices and emulators
    let deviceManager: DeviceManager

    /// Processes and filters log output
    let logProcessor: LogProcessor

    // MARK: - Published State (Project)

    /// Currently selected project (nil if none selected)
    @Published var currentProject: Project?

    /// List of recently opened projects (persisted via UserDefaults)
    @Published var recentProjects: [Project] = []

    // MARK: - Published State (Selection)

    /// Currently selected target platform (Android or iOS)
    @Published var selectedPlatform: Platform = .android

    /// Currently selected device/emulator (nil if none available)
    @Published var selectedDevice: Device?

    // MARK: - Published State (UI)

    /// Controls visibility of project picker dialog
    @Published var isShowingProjectPicker: Bool = false

    /// Controls visibility of error alert
    @Published var showingAlert: Bool = false

    /// Message to display in error alert
    @Published var alertMessage: String = ""

    /// Currently running Makefile target (nil if none running)
    @Published var runningMakeTarget: MakefileTarget?

    /// Whether to show Make Commands section (hidden by default)
    @Published var showMakeCommands: Bool = false

    /// Whether log viewer window is visible
    @Published var isLogViewerVisible: Bool = false

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    /// Track previous error count for auto-opening log viewer
    private var previousErrorCount: Int = 0

    // MARK: - Computed Properties

    /// Current process execution state (idle, running, etc.)
    var processState: ProcessState {
        commandRunner.state
    }

    /// Devices available for the currently selected platform
    var availableDevices: [Device] {
        deviceManager.getDevices(for: selectedPlatform)
    }

    /// Whether the Run button should be enabled
    /// Requires: project selected, device selected, not already running
    var canRun: Bool {
        currentProject != nil &&
        selectedDevice != nil &&
        !commandRunner.state.isRunning
    }

    /// Whether hot reload buttons should be visible
    /// Only available for Flutter projects while running
    var canHotReload: Bool {
        commandRunner.state == .running &&
        currentProject?.type == .flutter
    }

    /// Platforms supported by the current project type
    /// Falls back to all platforms if no project selected
    var supportedPlatforms: [Platform] {
        currentProject?.type.supportedPlatforms ?? Platform.allCases
    }

    // MARK: - Initialization

    init() {
        self.commandRunner = CommandRunner()
        self.deviceManager = DeviceManager()
        self.logProcessor = LogProcessor()

        // Connect log processor to command runner
        logProcessor.subscribe(to: commandRunner)

        // Forward device manager changes to trigger UI updates
        deviceManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Forward command runner changes to trigger UI updates
        // Also auto-open log viewer when process fails
        commandRunner.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.objectWillChange.send()

                // Auto-open log viewer when process fails
                if case .failed = self.commandRunner.state {
                    self.autoOpenLogViewerForError()
                }
            }
            .store(in: &cancellables)

        // Forward log processor changes to trigger UI updates
        // Also auto-open log viewer when new errors are detected
        logProcessor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.objectWillChange.send()

                // Check if error count increased - auto open log viewer
                let currentErrorCount = self.logProcessor.errorCount
                if currentErrorCount > self.previousErrorCount {
                    self.autoOpenLogViewerForError()
                }
                self.previousErrorCount = currentErrorCount
            }
            .store(in: &cancellables)

        // Load recent projects
        recentProjects = ProjectDetector.getRecentProjects()

        // Auto-refresh devices on launch
        Task {
            await deviceManager.refreshDevices()
        }
    }

    // MARK: - Project Actions

    func selectProject(_ project: Project) {
        currentProject = project
        ProjectDetector.saveRecentProject(project)
        recentProjects = ProjectDetector.getRecentProjects()

        // Update selected platform if not supported
        if !project.type.supportedPlatforms.contains(selectedPlatform),
           let firstPlatform = project.type.supportedPlatforms.first {
            selectedPlatform = firstPlatform
        }

        // Auto-select first available device
        if selectedDevice == nil || selectedDevice?.platform != selectedPlatform {
            selectedDevice = availableDevices.first
        }

        logProcessor.addSystemMessage("Selected project: \(project.name) (\(project.type.rawValue))")
    }

    func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let project = ProjectDetector.createProject(at: url)
            selectProject(project)
        }
    }

    func removeRecentProject(_ project: Project) {
        ProjectDetector.removeRecentProject(project)
        recentProjects = ProjectDetector.getRecentProjects()
    }

    // MARK: - Device Actions

    func refreshDevices() async {
        try? "AppState.refreshDevices called\n".append(toFile: "/tmp/devdock_trace.txt")
        await deviceManager.refreshDevices()
        try? "deviceManager.refreshDevices done, devices: \(availableDevices.count)\n".append(toFile: "/tmp/devdock_trace.txt")
        // Re-select device if current one is no longer available
        if let current = selectedDevice,
           !availableDevices.contains(where: { $0.id == current.id }) {
            selectedDevice = availableDevices.first
        }
    }

    private func appendToTrace(_ text: String) {
        let path = "/tmp/devdock_trace.txt"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(text.data(using: .utf8)!)
            handle.closeFile()
        }
    }

    func selectPlatform(_ platform: Platform) {
        selectedPlatform = platform
        // Auto-select first device for new platform
        selectedDevice = deviceManager.getDevices(for: platform).first
    }

    // MARK: - Run Actions

    func run() async {
        guard let project = currentProject,
              let device = selectedDevice else {
            showAlert("Please select a project and device")
            return
        }

        logProcessor.clearLogs()
        logProcessor.addSystemMessage("Starting \(project.name) on \(device.name)...")

        let config = RunConfiguration(
            project: project,
            platform: selectedPlatform,
            device: device
        )

        do {
            try await commandRunner.run(configuration: config)
        } catch {
            logProcessor.addSystemMessage("Failed to start: \(error.localizedDescription)")
            showAlert(error.localizedDescription)
        }
    }

    func stop() async {
        logProcessor.addSystemMessage("Stopping...")
        await commandRunner.stop()
        logProcessor.addSystemMessage("Stopped")
    }

    func hotReload() async {
        do {
            try await commandRunner.hotReload()
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    func hotRestart() async {
        do {
            try await commandRunner.hotRestart()
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    /// Uninstall the app from the selected device
    func uninstallApp() async {
        guard let project = currentProject,
              let device = selectedDevice else {
            showAlert("Please select a project and device")
            return
        }

        logProcessor.addSystemMessage("Uninstalling app from \(device.name)...")

        do {
            let packageName = try getPackageName(for: project)

            switch selectedPlatform {
            case .android:
                _ = try await CommandRunner.execute(
                    "adb",
                    arguments: ["-s", device.id, "uninstall", packageName]
                )
            case .iOS:
                _ = try await CommandRunner.execute(
                    "xcrun",
                    arguments: ["simctl", "uninstall", device.id, packageName]
                )
            }

            logProcessor.addSystemMessage("App uninstalled successfully")
        } catch {
            logProcessor.addSystemMessage("Uninstall failed: \(error.localizedDescription)")
            showAlert(error.localizedDescription)
        }
    }

    /// Get package/bundle ID from project files
    private func getPackageName(for project: Project) throws -> String {
        // Try to read from Android build.gradle (works for Flutter, React Native, Android)
        let buildGradlePath = project.path.appendingPathComponent("android/app/build.gradle")
        if let content = try? String(contentsOf: buildGradlePath, encoding: .utf8) {
            // Look for applicationId line
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if trimmed.contains("applicationId") {
                    // Extract the package name from quotes
                    if let startQuote = trimmed.firstIndex(of: "\"") ?? trimmed.firstIndex(of: "'") {
                        let afterQuote = trimmed.index(after: startQuote)
                        if let endQuote = trimmed[afterQuote...].firstIndex(of: "\"") ?? trimmed[afterQuote...].firstIndex(of: "'") {
                            let packageId = String(trimmed[afterQuote..<endQuote])
                            if !packageId.isEmpty {
                                return packageId
                            }
                        }
                    }
                }
            }
        }

        // Fallback for Flutter: try pubspec.yaml name
        if project.type == .flutter {
            let pubspecPath = project.path.appendingPathComponent("pubspec.yaml")
            if let content = try? String(contentsOf: pubspecPath, encoding: .utf8) {
                for line in content.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                    if trimmed.hasPrefix("name:") {
                        let name = trimmed.replacingOccurrences(of: "name:", with: "")
                            .trimmingCharacters(in: CharacterSet.whitespaces)
                        if !name.isEmpty {
                            return "com.example.\(name)"
                        }
                    }
                }
            }
        }

        throw ProcessError.executionFailed("Could not determine package name")
    }

    // MARK: - Makefile Actions

    /// Execute a Makefile target
    func runMakeTarget(_ target: MakefileTarget) async {
        guard let project = currentProject else {
            showAlert("No project selected")
            return
        }

        runningMakeTarget = target
        logProcessor.addSystemMessage("Running 'make \(target.name)'...")

        do {
            try await commandRunner.runSimpleCommand(
                "make",
                args: [target.name],
                workingDirectory: project.path
            )
            logProcessor.addSystemMessage("'make \(target.name)' completed")
        } catch {
            logProcessor.addSystemMessage("'make \(target.name)' failed: \(error.localizedDescription)")
            showAlert(error.localizedDescription)
        }

        runningMakeTarget = nil
    }

    // MARK: - View Toggle Actions

    func toggleMakeCommands() {
        showMakeCommands.toggle()
    }

    func toggleLogViewer() {
        isLogViewerVisible.toggle()
    }

    /// Auto-open log viewer when an error is detected
    func autoOpenLogViewerForError() {
        LogViewerWindowController.shared.showWindow(appState: self)
    }

    // MARK: - Log Actions

    func clearLogs() {
        logProcessor.clearLogs()
        objectWillChange.send()
    }

    func exportLogs() {
        let panel = NSSavePanel()
        panel.title = "Export Logs"
        panel.nameFieldStringValue = "devdock-logs.txt"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try logProcessor.exportLogs(to: url)
            } catch {
                showAlert("Failed to export logs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// Debug helper
extension String {
    func append(toFile path: String) throws {
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(self.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try self.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
