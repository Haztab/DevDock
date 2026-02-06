import Foundation
import Combine

// MARK: - CommandRunner Protocol

/// Protocol defining the interface for command execution services.
///
/// Implementations of this protocol handle:
/// - Running CLI commands for mobile development tools (Flutter, React Native, etc.)
/// - Streaming stdout/stderr output in real-time
/// - Sending input to running processes (for hot reload)
/// - Managing process lifecycle (start, stop, cleanup)
protocol CommandRunnerProtocol {
    /// Publisher that emits stdout lines from the running process
    var outputPublisher: AnyPublisher<String, Never> { get }

    /// Publisher that emits stderr lines from the running process
    var errorPublisher: AnyPublisher<String, Never> { get }

    /// Publisher that emits process state changes
    var statePublisher: AnyPublisher<ProcessState, Never> { get }

    /// Run a mobile app with the given configuration
    /// - Parameter configuration: The run configuration containing project, platform, and device info
    /// - Throws: `ProcessError` if the command cannot be executed
    func run(configuration: RunConfiguration) async throws

    /// Stop the currently running process gracefully
    func stop() async

    /// Send input to the running process stdin
    /// - Parameter input: The string to send (newline is appended automatically)
    /// - Throws: `ProcessError.processNotRunning` if no process is active
    func sendInput(_ input: String) async throws

    /// Trigger Flutter hot reload by sending 'r' to stdin
    /// - Throws: `ProcessError` if not a Flutter project or process not running
    func hotReload() async throws

    /// Trigger Flutter hot restart by sending 'R' to stdin
    /// - Throws: `ProcessError` if not a Flutter project or process not running
    func hotRestart() async throws
}

// MARK: - CommandRunner Implementation

/// Manages CLI process execution with real-time output streaming.
///
/// `CommandRunner` is the core service for executing mobile development CLI commands.
/// It wraps Foundation's `Process` class and provides:
///
/// - **Real-time streaming**: stdout and stderr are streamed via Combine publishers
/// - **Interactive stdin**: The stdin pipe remains open for sending commands (hot reload)
/// - **Graceful shutdown**: For Flutter, sends 'q' before terminating
/// - **Path resolution**: Automatically finds executables in common install locations
///
/// ## Usage Example
/// ```swift
/// let runner = CommandRunner()
///
/// // Subscribe to output
/// runner.outputPublisher.sink { line in
///     print("Output: \(line)")
/// }
///
/// // Run a Flutter app
/// let config = RunConfiguration(project: myProject, platform: .iOS, device: simulator)
/// try await runner.run(configuration: config)
///
/// // Hot reload
/// try await runner.hotReload()
///
/// // Stop
/// await runner.stop()
/// ```
///
/// ## Thread Safety
/// This class is marked `@MainActor` to ensure all state updates happen on the main thread.
/// Output reading happens on detached tasks but publishes back to the main actor.
@MainActor
final class CommandRunner: ObservableObject, CommandRunnerProtocol {
    // MARK: - Published State

    @Published private(set) var state: ProcessState = .idle
    @Published private(set) var isProcessRunning: Bool = false

    // MARK: - Publishers

    private let outputSubject = PassthroughSubject<String, Never>()
    private let errorSubject = PassthroughSubject<String, Never>()
    private let stateSubject = PassthroughSubject<ProcessState, Never>()

    var outputPublisher: AnyPublisher<String, Never> {
        outputSubject.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<String, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<ProcessState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var outputTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var currentConfiguration: RunConfiguration?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Run a mobile app with the given configuration
    func run(configuration: RunConfiguration) async throws {
        // Prevent multiple simultaneous runs
        guard !state.isRunning else {
            throw ProcessError.executionFailed("A process is already running")
        }

        guard let command = configuration.buildCommand() else {
            throw ProcessError.projectNotDetected
        }

        currentConfiguration = configuration
        updateState(.starting)

        do {
            try await executeCommand(
                executable: command.executable,
                arguments: command.arguments,
                workingDirectory: configuration.project.path
            )
        } catch {
            updateState(.failed(error))
            throw error
        }
    }

    /// Stop the currently running process
    func stop() async {
        guard let process = process, process.isRunning else {
            updateState(.idle)
            return
        }

        updateState(.stopping)

        // For Flutter, try graceful quit first
        if currentConfiguration?.project.type == .flutter {
            do {
                try await sendInput("q")
                // Wait briefly for graceful shutdown
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            } catch {
                // Ignore errors, will force terminate below
            }
        }

        // Force terminate if still running
        if process.isRunning {
            process.terminate()
        }

        // Cancel output reading tasks
        outputTask?.cancel()
        errorTask?.cancel()

        // Clean up pipes
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.closeFile()
        stderrPipe?.fileHandleForReading.closeFile()

        self.process = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil
        self.currentConfiguration = nil

        updateState(.idle)
    }

    /// Send input to the running process (for hot reload, etc.)
    func sendInput(_ input: String) async throws {
        guard let stdinPipe = stdinPipe,
              let process = process,
              process.isRunning else {
            throw ProcessError.processNotRunning
        }

        let data = Data((input + "\n").utf8)
        let handle = stdinPipe.fileHandleForWriting

        do {
            try handle.write(contentsOf: data)
        } catch {
            throw ProcessError.executionFailed("Failed to send input: \(error.localizedDescription)")
        }
    }

    /// Hot reload (Flutter: 'r')
    func hotReload() async throws {
        guard currentConfiguration?.project.type == .flutter else {
            throw ProcessError.executionFailed("Hot reload is only supported for Flutter projects")
        }
        try await sendInput("r")
        outputSubject.send("[DevDock] Hot reload triggered")
    }

    /// Hot restart (Flutter: 'R')
    func hotRestart() async throws {
        guard currentConfiguration?.project.type == .flutter else {
            throw ProcessError.executionFailed("Hot restart is only supported for Flutter projects")
        }
        try await sendInput("R")
        outputSubject.send("[DevDock] Hot restart triggered")
    }

    /// Run a simple command with streaming output (e.g., make commands)
    /// This runs independently without affecting the main process state
    func runSimpleCommand(
        _ executable: String,
        args: [String],
        workingDirectory: URL
    ) async throws {
        let process = Process()

        // Find executable path
        let executablePath = try await findExecutablePath(executable)
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = args
        process.currentDirectoryURL = workingDirectory

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.pub-cache/bin"
        ]
        if let existingPath = environment["PATH"] {
            environment["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        }
        process.environment = environment

        // Set up pipes
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start reading output in background
        let outputHandle = stdoutPipe.fileHandleForReading
        let errorHandle = stderrPipe.fileHandleForReading

        let readOutputTask = Task.detached { [weak self] in
            while true {
                let data = outputHandle.availableData
                guard !data.isEmpty else { break }
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        await MainActor.run { [weak self] in
                            self?.outputSubject.send(line)
                        }
                    }
                }
            }
        }

        let readErrorTask = Task.detached { [weak self] in
            while true {
                let data = errorHandle.availableData
                guard !data.isEmpty else { break }
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        await MainActor.run { [weak self] in
                            self?.errorSubject.send(line)
                        }
                    }
                }
            }
        }

        // Run the process
        try process.run()
        process.waitUntilExit()

        // Cancel reading tasks
        readOutputTask.cancel()
        readErrorTask.cancel()

        // Check exit status
        if process.terminationStatus != 0 {
            throw ProcessError.executionFailed("Command exited with code \(process.terminationStatus)")
        }
    }

    // MARK: - Private Methods

    private func executeCommand(
        executable: String,
        arguments: [String],
        workingDirectory: URL
    ) async throws {
        let process = Process()

        // Find executable path
        let executablePath = try await findExecutablePath(executable)
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        // Set up environment (inherit current + add common paths)
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.pub-cache/bin",
            "\(NSHomeDirectory())/fvm/default/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin"
        ]
        if let existingPath = environment["PATH"] {
            environment["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        }
        process.environment = environment

        // Set up pipes for I/O
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // Start reading output streams
        startReadingOutput(from: stdoutPipe, isError: false)
        startReadingOutput(from: stderrPipe, isError: true)

        // Set termination handler
        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if terminatedProcess.terminationStatus != 0 && self.state == .running {
                    self.updateState(.failed(ProcessError.executionFailed(
                        "Process exited with code \(terminatedProcess.terminationStatus)"
                    )))
                } else if self.state != .stopping {
                    self.updateState(.idle)
                }
            }
        }

        // Launch the process
        do {
            try process.run()
            updateState(.running)
        } catch {
            throw ProcessError.executionFailed(error.localizedDescription)
        }
    }

    private func findExecutablePath(_ executable: String) async throws -> String {
        // Common paths to search
        let searchPaths = [
            "/usr/local/bin/\(executable)",
            "/opt/homebrew/bin/\(executable)",
            "/usr/bin/\(executable)",
            "\(NSHomeDirectory())/.pub-cache/bin/\(executable)",
            "\(NSHomeDirectory())/fvm/default/bin/\(executable)"
        ]

        // Check direct paths first
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try using 'which' command
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [executable]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // which failed, continue
        }

        throw ProcessError.commandNotFound(executable)
    }

    private func startReadingOutput(from pipe: Pipe, isError: Bool) {
        let handle = pipe.fileHandleForReading
        let subject = isError ? errorSubject : outputSubject

        let task = Task.detached { [weak self] in
            while true {
                guard !Task.isCancelled else { break }

                let data = handle.availableData
                guard !data.isEmpty else {
                    // EOF reached
                    break
                }

                if let output = String(data: data, encoding: .utf8) {
                    // Split by lines and emit each line separately
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        await MainActor.run {
                            subject.send(line)
                        }
                    }
                }
            }
        }

        if isError {
            errorTask = task
        } else {
            outputTask = task
        }
    }

    private func updateState(_ newState: ProcessState) {
        state = newState
        isProcessRunning = newState.isRunning
        stateSubject.send(newState)
    }
}

// MARK: - Simple Command Execution (for device detection, etc.)

extension CommandRunner {
    /// Execute a simple command and return its output (non-streaming)
    static func execute(
        _ executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil
    ) async throws -> String {
        let process = Process()

        // Try to find executable
        let paths = [
            "/usr/local/bin/\(executable)",
            "/opt/homebrew/bin/\(executable)",
            "/usr/bin/\(executable)",
            executable // Try as-is (might be full path)
        ]

        var executablePath: String?
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                executablePath = path
                break
            }
        }

        guard let path = executablePath else {
            throw ProcessError.commandNotFound(executable)
        }

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
