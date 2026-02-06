import Foundation

/// Represents the current state of the running process
enum ProcessState: Equatable {
    case idle
    case starting
    case running
    case stopping
    case failed(Error)

    var isRunning: Bool {
        switch self {
        case .running, .starting:
            return true
        default:
            return false
        }
    }

    var canStart: Bool {
        self == .idle || self == .failed(ProcessError.unknown)
    }

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .stopping: return "Stopping..."
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }

    var statusColor: String {
        switch self {
        case .idle: return "secondary"
        case .starting: return "yellow"
        case .running: return "green"
        case .stopping: return "orange"
        case .failed: return "red"
        }
    }

    static func == (lhs: ProcessState, rhs: ProcessState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.starting, .starting),
             (.running, .running),
             (.stopping, .stopping):
            return true
        case (.failed, .failed):
            return true // Simplified comparison
        default:
            return false
        }
    }
}

/// Errors that can occur during process execution
enum ProcessError: LocalizedError {
    case unknown
    case processNotRunning
    case commandNotFound(String)
    case executionFailed(String)
    case deviceNotConnected
    case projectNotDetected

    var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        case .processNotRunning:
            return "No process is currently running"
        case .commandNotFound(let cmd):
            return "Command not found: \(cmd)"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .deviceNotConnected:
            return "No device connected"
        case .projectNotDetected:
            return "Could not detect project type"
        }
    }
}

/// Configuration for running a project
struct RunConfiguration {
    let project: Project
    let platform: Platform
    let device: Device
    let additionalArgs: [String]

    init(project: Project, platform: Platform, device: Device, additionalArgs: [String] = []) {
        self.project = project
        self.platform = platform
        self.device = device
        self.additionalArgs = additionalArgs
    }

    /// Generate the command and arguments for running
    func buildCommand() -> (executable: String, arguments: [String])? {
        switch project.type {
        case .flutter:
            return buildFlutterCommand()
        case .reactNative:
            return buildReactNativeCommand()
        case .android:
            return buildAndroidCommand()
        case .ios:
            return buildIOSCommand()
        case .unknown:
            return nil
        }
    }

    private func buildFlutterCommand() -> (String, [String]) {
        var args = ["run"]

        // Add device flag
        args.append("-d")
        args.append(device.id)

        // Add additional arguments
        args.append(contentsOf: additionalArgs)

        return ("flutter", args)
    }

    private func buildReactNativeCommand() -> (String, [String]) {
        // Using npx to ensure we use the local react-native CLI
        var args = ["react-native"]

        switch platform {
        case .android:
            args.append("run-android")
            if device.type == .emulator {
                args.append("--deviceId")
                args.append(device.id)
            }
        case .iOS:
            args.append("run-ios")
            if device.type == .emulator {
                args.append("--simulator")
                args.append(device.name)
            } else {
                args.append("--device")
                args.append(device.name)
            }
        }

        args.append(contentsOf: additionalArgs)
        return ("npx", args)
    }

    private func buildAndroidCommand() -> (String, [String]) {
        // Simplified: use gradle wrapper
        return ("./gradlew", ["installDebug"])
    }

    private func buildIOSCommand() -> (String, [String]) {
        // Placeholder for xcodebuild - complex, implement later
        return ("xcodebuild", ["-scheme", project.name, "-destination", "id=\(device.id)"])
    }
}
