import Foundation
import Combine

/// Protocol for device management
protocol DeviceManagerProtocol {
    func refreshDevices() async
    func getDevices(for platform: Platform) -> [Device]
}

/// Manages detection of Android devices/emulators and iOS simulators
@MainActor
final class DeviceManager: ObservableObject, DeviceManagerProtocol {
    // MARK: - Published State

    @Published private(set) var androidDevices: [Device] = []
    @Published private(set) var iosSimulators: [Device] = []
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastError: Error?

    // MARK: - Public Methods

    /// Refresh all device lists
    func refreshDevices() async {
        isRefreshing = true
        lastError = nil

        // Fetch both platforms in parallel
        async let androidTask: () = refreshAndroidDevices()
        async let iosTask: () = refreshIOSSimulators()

        await androidTask
        await iosTask

        isRefreshing = false
    }

    /// Get devices for a specific platform
    func getDevices(for platform: Platform) -> [Device] {
        switch platform {
        case .android:
            return androidDevices
        case .iOS:
            return iosSimulators
        }
    }

    // MARK: - Android Devices (via adb)

    private func refreshAndroidDevices() async {
        do {
            let output = try await CommandRunner.execute("adb", arguments: ["devices", "-l"])
            androidDevices = parseAdbOutput(output)
        } catch {
            // ADB might not be installed
            androidDevices = []
            if case ProcessError.commandNotFound = error {
                // Silently ignore - user might not have Android SDK
            } else {
                lastError = error
            }
        }
    }

    /// Parse output from `adb devices -l`
    /// Example output:
    /// ```
    /// List of devices attached
    /// emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
    /// 1234567890ABCDEF       device usb:1234567X product:walleye model:Pixel_2 device:walleye transport_id:2
    /// ```
    private func parseAdbOutput(_ output: String) -> [Device] {
        var devices: [Device] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip header and empty lines
            guard !trimmed.isEmpty,
                  !trimmed.starts(with: "List of devices"),
                  !trimmed.starts(with: "*") else {
                continue
            }

            // Parse device line
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }

            let deviceId = components[0]
            let statusString = components[1]

            // Determine device state
            let state: DeviceState
            switch statusString {
            case "device":
                state = .connected
            case "offline":
                state = .offline
            case "unauthorized":
                state = .unknown
            default:
                state = .unknown
            }

            // Determine if emulator or physical
            let isEmulator = deviceId.starts(with: "emulator-")

            // Extract model name if available
            var modelName = deviceId
            for component in components where component.starts(with: "model:") {
                modelName = String(component.dropFirst(6)).replacingOccurrences(of: "_", with: " ")
                break
            }

            let device = Device(
                id: deviceId,
                name: modelName,
                platform: .android,
                type: isEmulator ? .emulator : .physical,
                state: state
            )
            devices.append(device)
        }

        return devices
    }

    // MARK: - iOS Simulators (via simctl)

    private func refreshIOSSimulators() async {
        do {
            let output = try await CommandRunner.execute(
                "xcrun",
                arguments: ["simctl", "list", "devices", "--json"]
            )
            iosSimulators = parseSimctlOutput(output)
        } catch {
            iosSimulators = []
            if case ProcessError.commandNotFound = error {
                // Xcode not installed
            } else {
                lastError = error
            }
        }
    }

    /// Parse JSON output from `xcrun simctl list devices --json`
    private func parseSimctlOutput(_ output: String) -> [Device] {
        var devices: [Device] = []

        guard let data = output.data(using: .utf8) else { return devices }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let devicesDict = json?["devices"] as? [String: [[String: Any]]] else {
                return devices
            }

            for (runtime, deviceList) in devicesDict {
                // Filter to recent iOS versions (iOS 15+)
                guard runtime.contains("iOS") else { continue }

                for deviceInfo in deviceList {
                    guard let name = deviceInfo["name"] as? String,
                          let udid = deviceInfo["udid"] as? String,
                          let stateString = deviceInfo["state"] as? String,
                          let isAvailable = deviceInfo["isAvailable"] as? Bool,
                          isAvailable else {
                        continue
                    }

                    let state: DeviceState
                    switch stateString {
                    case "Booted":
                        state = .connected
                    case "Shutdown":
                        state = .offline
                    case "Booting":
                        state = .booting
                    default:
                        state = .unknown
                    }

                    // Extract iOS version from runtime
                    let runtimeVersion = extractIOSVersion(from: runtime)
                    let displayName = "\(name) (\(runtimeVersion))"

                    let device = Device(
                        id: udid,
                        name: displayName,
                        platform: .iOS,
                        type: .emulator,
                        state: state
                    )
                    devices.append(device)
                }
            }
        } catch {
            lastError = error
        }

        // Sort: booted first, then by name
        return devices.sorted { d1, d2 in
            if d1.state == .connected && d2.state != .connected {
                return true
            }
            if d1.state != .connected && d2.state == .connected {
                return false
            }
            return d1.name < d2.name
        }
    }

    /// Extract iOS version from runtime string
    /// e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-0" -> "iOS 17.0"
    private func extractIOSVersion(from runtime: String) -> String {
        // Try to extract version number
        if let range = runtime.range(of: "iOS-") {
            let version = runtime[range.upperBound...]
                .replacingOccurrences(of: "-", with: ".")
            return "iOS \(version)"
        }
        return "iOS"
    }

    // MARK: - Simulator Control

    /// Boot an iOS simulator
    func bootSimulator(_ device: Device) async throws {
        guard device.platform == .iOS else { return }
        _ = try await CommandRunner.execute("xcrun", arguments: ["simctl", "boot", device.id])
        await refreshIOSSimulators()
    }

    /// Shutdown an iOS simulator
    func shutdownSimulator(_ device: Device) async throws {
        guard device.platform == .iOS else { return }
        _ = try await CommandRunner.execute("xcrun", arguments: ["simctl", "shutdown", device.id])
        await refreshIOSSimulators()
    }
}

// MARK: - Flutter Device Detection (Alternative)

extension DeviceManager {
    /// Use Flutter's own device detection for more accurate results
    func refreshFlutterDevices() async -> [Device] {
        do {
            let output = try await CommandRunner.execute("flutter", arguments: ["devices", "--machine"])

            guard let data = output.data(using: .utf8),
                  let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            return devices.compactMap { deviceInfo -> Device? in
                guard let id = deviceInfo["id"] as? String,
                      let name = deviceInfo["name"] as? String,
                      let platformStr = deviceInfo["targetPlatform"] as? String else {
                    return nil
                }

                let platform: Platform
                let type: DeviceType

                if platformStr.contains("android") {
                    platform = .android
                    type = platformStr.contains("emulator") || id.starts(with: "emulator") ? .emulator : .physical
                } else if platformStr.contains("ios") {
                    platform = .iOS
                    type = deviceInfo["emulator"] as? Bool == true ? .emulator : .physical
                } else {
                    return nil // Skip desktop/web devices
                }

                return Device(
                    id: id,
                    name: name,
                    platform: platform,
                    type: type,
                    state: .connected
                )
            }
        } catch {
            return []
        }
    }
}
