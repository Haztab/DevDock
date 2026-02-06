import XCTest
import Combine
@testable import DevDock

/// Unit tests for CommandRunner and related types
@MainActor
final class CommandRunnerTests: XCTestCase {

    // MARK: - Properties

    private var commandRunner: CommandRunner!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        commandRunner = CommandRunner()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        // Stop any running process
        await commandRunner.stop()
        cancellables = nil
        commandRunner = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        XCTAssertEqual(commandRunner.state, .idle)
        XCTAssertFalse(commandRunner.isProcessRunning)
    }

    // MARK: - Publisher Tests

    func testOutputPublisherExists() {
        // Then: Publisher should be accessible
        XCTAssertNotNil(commandRunner.outputPublisher)
    }

    func testErrorPublisherExists() {
        // Then: Publisher should be accessible
        XCTAssertNotNil(commandRunner.errorPublisher)
    }

    func testStatePublisherExists() {
        // Then: Publisher should be accessible
        XCTAssertNotNil(commandRunner.statePublisher)
    }

    // MARK: - Hot Reload Tests (Without Running Process)

    func testHotReloadThrowsWhenNotRunning() async {
        // Given: No process running

        // When/Then: Hot reload should throw
        do {
            try await commandRunner.hotReload()
            XCTFail("Should have thrown ProcessError.processNotRunning")
        } catch {
            // Expected
        }
    }

    func testHotRestartThrowsWhenNotRunning() async {
        // Given: No process running

        // When/Then: Hot restart should throw
        do {
            try await commandRunner.hotRestart()
            XCTFail("Should have thrown ProcessError.processNotRunning")
        } catch {
            // Expected
        }
    }

    func testSendInputThrowsWhenNotRunning() async {
        // Given: No process running

        // When/Then: Send input should throw
        do {
            try await commandRunner.sendInput("test")
            XCTFail("Should have thrown ProcessError.processNotRunning")
        } catch let error as ProcessError {
            XCTAssertEqual(error, .processNotRunning)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Stop Tests

    func testStopWhenIdleDoesNothing() async {
        // Given: Idle state
        XCTAssertEqual(commandRunner.state, .idle)

        // When: Stopping
        await commandRunner.stop()

        // Then: State remains idle
        XCTAssertEqual(commandRunner.state, .idle)
    }
}

// MARK: - ProcessState Tests

final class ProcessStateTests: XCTestCase {

    func testIdleIsNotRunning() {
        XCTAssertFalse(ProcessState.idle.isRunning)
    }

    func testStartingIsRunning() {
        XCTAssertTrue(ProcessState.starting.isRunning)
    }

    func testRunningIsRunning() {
        XCTAssertTrue(ProcessState.running.isRunning)
    }

    func testStoppingIsNotRunning() {
        XCTAssertFalse(ProcessState.stopping.isRunning)
    }

    func testFailedIsNotRunning() {
        XCTAssertFalse(ProcessState.failed(ProcessError.unknown).isRunning)
    }

    func testIdleCanStart() {
        XCTAssertTrue(ProcessState.idle.canStart)
    }

    func testRunningCannotStart() {
        XCTAssertFalse(ProcessState.running.canStart)
    }

    func testStatusText() {
        XCTAssertEqual(ProcessState.idle.statusText, "Ready")
        XCTAssertEqual(ProcessState.starting.statusText, "Starting...")
        XCTAssertEqual(ProcessState.running.statusText, "Running")
        XCTAssertEqual(ProcessState.stopping.statusText, "Stopping...")
    }

    func testStatusColor() {
        XCTAssertEqual(ProcessState.idle.statusColor, "secondary")
        XCTAssertEqual(ProcessState.starting.statusColor, "yellow")
        XCTAssertEqual(ProcessState.running.statusColor, "green")
        XCTAssertEqual(ProcessState.stopping.statusColor, "orange")
        XCTAssertEqual(ProcessState.failed(ProcessError.unknown).statusColor, "red")
    }

    func testEquality() {
        XCTAssertEqual(ProcessState.idle, ProcessState.idle)
        XCTAssertEqual(ProcessState.running, ProcessState.running)
        XCTAssertNotEqual(ProcessState.idle, ProcessState.running)
        XCTAssertEqual(
            ProcessState.failed(ProcessError.unknown),
            ProcessState.failed(ProcessError.processNotRunning)
        )
    }
}

// MARK: - ProcessError Tests

final class ProcessErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(
            ProcessError.unknown.errorDescription,
            "An unknown error occurred"
        )

        XCTAssertEqual(
            ProcessError.processNotRunning.errorDescription,
            "No process is currently running"
        )

        XCTAssertEqual(
            ProcessError.commandNotFound("flutter").errorDescription,
            "Command not found: flutter"
        )

        XCTAssertEqual(
            ProcessError.executionFailed("timeout").errorDescription,
            "Execution failed: timeout"
        )

        XCTAssertEqual(
            ProcessError.deviceNotConnected.errorDescription,
            "No device connected"
        )

        XCTAssertEqual(
            ProcessError.projectNotDetected.errorDescription,
            "Could not detect project type"
        )
    }

    func testProcessErrorEquality() {
        XCTAssertEqual(ProcessError.unknown, ProcessError.unknown)
        XCTAssertEqual(ProcessError.processNotRunning, ProcessError.processNotRunning)
        XCTAssertEqual(
            ProcessError.commandNotFound("flutter"),
            ProcessError.commandNotFound("flutter")
        )
        XCTAssertNotEqual(
            ProcessError.commandNotFound("flutter"),
            ProcessError.commandNotFound("npm")
        )
    }
}

// MARK: - RunConfiguration Tests

final class RunConfigurationTests: XCTestCase {

    private func makeTestProject(type: ProjectType) -> Project {
        return Project(
            path: URL(fileURLWithPath: "/test/project"),
            type: type
        )
    }

    private func makeTestDevice() -> Device {
        return Device(
            id: "emulator-5554",
            name: "Pixel 6 API 34",
            platform: .android,
            type: .emulator,
            isOnline: true
        )
    }

    func testFlutterCommandGeneration() {
        // Given: A Flutter configuration
        let config = RunConfiguration(
            project: makeTestProject(type: .flutter),
            platform: .android,
            device: makeTestDevice()
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should generate flutter run command
        XCTAssertNotNil(command)
        XCTAssertEqual(command?.executable, "flutter")
        XCTAssertEqual(command?.arguments.first, "run")
        XCTAssertTrue(command?.arguments.contains("-d") == true)
        XCTAssertTrue(command?.arguments.contains("emulator-5554") == true)
    }

    func testFlutterCommandWithAdditionalArgs() {
        // Given: A Flutter configuration with additional args
        let config = RunConfiguration(
            project: makeTestProject(type: .flutter),
            platform: .android,
            device: makeTestDevice(),
            additionalArgs: ["--verbose", "--debug"]
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should include additional args
        XCTAssertTrue(command?.arguments.contains("--verbose") == true)
        XCTAssertTrue(command?.arguments.contains("--debug") == true)
    }

    func testReactNativeAndroidCommand() {
        // Given: A React Native Android configuration
        let device = Device(
            id: "emulator-5554",
            name: "Pixel 6",
            platform: .android,
            type: .emulator,
            isOnline: true
        )
        let config = RunConfiguration(
            project: makeTestProject(type: .reactNative),
            platform: .android,
            device: device
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should generate npx react-native command
        XCTAssertEqual(command?.executable, "npx")
        XCTAssertTrue(command?.arguments.contains("react-native") == true)
        XCTAssertTrue(command?.arguments.contains("run-android") == true)
    }

    func testReactNativeIOSCommand() {
        // Given: A React Native iOS configuration
        let device = Device(
            id: "ABC-123",
            name: "iPhone 15 Pro",
            platform: .iOS,
            type: .emulator,
            isOnline: true
        )
        let config = RunConfiguration(
            project: makeTestProject(type: .reactNative),
            platform: .iOS,
            device: device
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should generate npx react-native run-ios command
        XCTAssertEqual(command?.executable, "npx")
        XCTAssertTrue(command?.arguments.contains("react-native") == true)
        XCTAssertTrue(command?.arguments.contains("run-ios") == true)
        XCTAssertTrue(command?.arguments.contains("--simulator") == true)
    }

    func testAndroidCommand() {
        // Given: An Android configuration
        let config = RunConfiguration(
            project: makeTestProject(type: .android),
            platform: .android,
            device: makeTestDevice()
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should generate gradle command
        XCTAssertEqual(command?.executable, "./gradlew")
        XCTAssertTrue(command?.arguments.contains("installDebug") == true)
    }

    func testIOSCommand() {
        // Given: An iOS configuration
        let device = Device(
            id: "ABC-123",
            name: "iPhone 15",
            platform: .iOS,
            type: .emulator,
            isOnline: true
        )
        let config = RunConfiguration(
            project: makeTestProject(type: .ios),
            platform: .iOS,
            device: device
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should generate xcodebuild command
        XCTAssertEqual(command?.executable, "xcodebuild")
        XCTAssertTrue(command?.arguments.contains("-scheme") == true)
    }

    func testUnknownProjectReturnsNil() {
        // Given: An unknown project type
        let config = RunConfiguration(
            project: makeTestProject(type: .unknown),
            platform: .android,
            device: makeTestDevice()
        )

        // When: Building command
        let command = config.buildCommand()

        // Then: Should return nil
        XCTAssertNil(command)
    }
}

// MARK: - Static Execute Tests

final class CommandRunnerStaticTests: XCTestCase {

    func testExecuteWithInvalidCommandThrows() async {
        // Given: A non-existent command

        // When/Then: Should throw commandNotFound
        do {
            _ = try await CommandRunner.execute(
                "definitely-not-a-real-command-\(UUID().uuidString)"
            )
            XCTFail("Should have thrown")
        } catch let error as ProcessError {
            if case .commandNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testExecuteWithValidCommand() async throws {
        // Given: A valid command (echo)

        // When: Executing
        let output = try await CommandRunner.execute("echo", arguments: ["hello"])

        // Then: Should return output
        XCTAssertTrue(output.contains("hello"))
    }
}
