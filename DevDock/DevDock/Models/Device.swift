import Foundation

/// Represents a connected device or emulator/simulator
struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let platform: Platform
    let type: DeviceType
    let state: DeviceState

    var displayName: String {
        let typeIndicator = type == .emulator ? "📱" : "📲"
        return "\(typeIndicator) \(name)"
    }
}

enum DeviceType: String {
    case physical = "Physical"
    case emulator = "Emulator/Simulator"
}

enum DeviceState: String {
    case connected = "Connected"
    case booting = "Booting"
    case offline = "Offline"
    case unknown = "Unknown"
}

/// Represents a project folder
struct Project: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let name: String
    let type: ProjectType

    init(path: URL, type: ProjectType) {
        self.id = UUID()
        self.path = path
        self.name = path.lastPathComponent
        self.type = type
    }
}
