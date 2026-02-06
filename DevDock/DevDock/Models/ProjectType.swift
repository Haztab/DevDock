import Foundation

/// Represents the type of mobile project detected
enum ProjectType: String, CaseIterable, Identifiable {
    case flutter = "Flutter"
    case reactNative = "React Native"
    case android = "Android"
    case ios = "iOS"
    case unknown = "Unknown"

    var id: String { rawValue }

    /// File markers used to detect project type
    var detectionMarkers: [String] {
        switch self {
        case .flutter:
            return ["pubspec.yaml"]
        case .reactNative:
            return ["package.json"] // Additional check for react-native dependency required
        case .android:
            return ["build.gradle", "build.gradle.kts"]
        case .ios:
            return [".xcodeproj", ".xcworkspace"]
        case .unknown:
            return []
        }
    }

    /// Icon for UI display
    var iconName: String {
        switch self {
        case .flutter: return "bird"
        case .reactNative: return "atom"
        case .android: return "android"
        case .ios: return "apple.logo"
        case .unknown: return "questionmark.folder"
        }
    }

    /// Supported platforms for this project type
    var supportedPlatforms: [Platform] {
        switch self {
        case .flutter, .reactNative:
            return [.android, .iOS]
        case .android:
            return [.android]
        case .ios:
            return [.iOS]
        case .unknown:
            return []
        }
    }
}

/// Target platform for running the app
enum Platform: String, CaseIterable, Identifiable {
    case android = "Android"
    case iOS = "iOS"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .android: return "phone.and.waveform"
        case .iOS: return "iphone"
        }
    }
}
