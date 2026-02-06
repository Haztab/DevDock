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
        commandRunner.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Forward log processor changes to trigger UI updates
        logProcessor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
