import Foundation
import SwiftUI

/// Represents a single log entry with parsed metadata
struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let rawText: String

    init(rawText: String, level: LogLevel? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.rawText = rawText
        self.message = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.level = level ?? LogLevel.detect(from: rawText)
    }
}

/// Log severity levels
enum LogLevel: String, CaseIterable, Identifiable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case all = "All"

    var id: String { rawValue }

    /// Color for UI display
    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .all: return .primary
        }
    }

    /// SF Symbol for log level
    var iconName: String {
        switch self {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .all: return "list.bullet"
        }
    }

    /// Detect log level from raw text
    static func detect(from text: String) -> LogLevel {
        let uppercased = text.uppercased()

        // Error patterns
        if uppercased.contains("ERROR") ||
           uppercased.contains("EXCEPTION") ||
           uppercased.contains("FATAL") ||
           uppercased.contains("FAILURE") ||
           text.contains("E/") { // Android logcat format
            return .error
        }

        // Warning patterns
        if uppercased.contains("WARN") ||
           uppercased.contains("WARNING") ||
           text.contains("W/") { // Android logcat format
            return .warning
        }

        // Debug patterns
        if uppercased.contains("DEBUG") ||
           uppercased.contains("[DEBUG]") ||
           text.contains("D/") { // Android logcat format
            return .debug
        }

        // Info patterns (or default)
        if uppercased.contains("INFO") ||
           text.contains("I/") { // Android logcat format
            return .info
        }

        return .info
    }
}

/// Filter options for log viewer
struct LogFilter {
    var level: LogLevel = .all
    var searchText: String = ""

    func matches(_ entry: LogEntry) -> Bool {
        let levelMatch = level == .all || entry.level == level
        let textMatch = searchText.isEmpty ||
            entry.message.localizedCaseInsensitiveContains(searchText)
        return levelMatch && textMatch
    }
}
