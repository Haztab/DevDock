import Foundation
import Combine

/// Processes and stores log entries from running processes
@MainActor
final class LogProcessor: ObservableObject {
    // MARK: - Published State

    @Published private(set) var entries: [LogEntry] = []
    @Published var filter: LogFilter = LogFilter()
    @Published var autoScroll: Bool = true

    // MARK: - Computed Properties

    var filteredEntries: [LogEntry] {
        entries.filter { filter.matches($0) }
    }

    var errorCount: Int {
        entries.filter { $0.level == .error }.count
    }

    var warningCount: Int {
        entries.filter { $0.level == .warning }.count
    }

    // MARK: - Configuration

    /// Maximum number of log entries to keep in memory
    private let maxEntries: Int = 5000

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Subscribe to a CommandRunner's output
    func subscribe(to runner: CommandRunner) {
        // Clear existing subscriptions
        cancellables.removeAll()

        // Subscribe to stdout
        runner.outputPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                self?.processOutput(output, isError: false)
            }
            .store(in: &cancellables)

        // Subscribe to stderr
        runner.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                self?.processOutput(output, isError: true)
            }
            .store(in: &cancellables)
    }

    /// Add a raw log line
    func addLog(_ text: String, level: LogLevel? = nil) {
        let entry = LogEntry(rawText: text, level: level)
        appendEntry(entry)
    }

    /// Add a system message (from DevDock itself)
    func addSystemMessage(_ message: String) {
        let entry = LogEntry(rawText: "[DevDock] \(message)", level: .info)
        appendEntry(entry)
    }

    /// Clear all log entries
    func clearLogs() {
        entries.removeAll()
        objectWillChange.send()
    }

    /// Export logs to a file
    func exportLogs(to url: URL) throws {
        let content = entries
            .map { entry in
                let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
                return "[\(timestamp)] [\(entry.level.rawValue.uppercased())] \(entry.message)"
            }
            .joined(separator: "\n")

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Methods

    private func processOutput(_ output: String, isError: Bool) {
        // Split multiline output
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Apply additional parsing based on content
            let parsedEntry = parseLogLine(trimmed, isStderr: isError)
            appendEntry(parsedEntry)
        }
    }

    private func parseLogLine(_ line: String, isStderr: Bool) -> LogEntry {
        // Flutter-specific parsing
        if let flutterEntry = parseFlutterLog(line) {
            return flutterEntry
        }

        // Android logcat parsing
        if let logcatEntry = parseAndroidLogcat(line) {
            return logcatEntry
        }

        // React Native parsing
        if let rnEntry = parseReactNativeLog(line) {
            return rnEntry
        }

        // Default parsing with stderr hint
        let defaultLevel: LogLevel? = isStderr ? .error : nil
        return LogEntry(rawText: line, level: defaultLevel)
    }

    /// Parse Flutter-specific log format
    private func parseFlutterLog(_ line: String) -> LogEntry? {
        // Flutter debug messages often start with "flutter:"
        if line.starts(with: "flutter:") {
            let message = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            return LogEntry(rawText: message)
        }

        // Flutter build messages
        if line.contains("Launching lib/main.dart") ||
           line.contains("Running Gradle task") ||
           line.contains("Built build/") {
            return LogEntry(rawText: line, level: .info)
        }

        // Flutter hot reload messages
        if line.contains("Reloaded") || line.contains("Hot reload") {
            return LogEntry(rawText: line, level: .info)
        }

        return nil
    }

    /// Parse Android logcat format
    /// Format: "D/Tag(PID): Message" or "2023-01-01 12:00:00.000 PID-TID/package D/Tag: Message"
    private func parseAndroidLogcat(_ line: String) -> LogEntry? {
        // Simple format: "D/Tag: Message"
        let simplePattern = #"^([VDIWEF])/([^(]+)\(\s*\d+\):\s*(.*)$"#
        if let regex = try? NSRegularExpression(pattern: simplePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let levelChar = String(line[Range(match.range(at: 1), in: line)!])
            let message = String(line[Range(match.range(at: 3), in: line)!])

            let level: LogLevel
            switch levelChar {
            case "V", "D": level = .debug
            case "I": level = .info
            case "W": level = .warning
            case "E", "F": level = .error
            default: level = .info
            }

            return LogEntry(rawText: message, level: level)
        }

        return nil
    }

    /// Parse React Native log format
    private func parseReactNativeLog(_ line: String) -> LogEntry? {
        // React Native console logs
        if line.contains("LOG ") {
            let message = line.replacingOccurrences(of: "LOG ", with: "")
            return LogEntry(rawText: message, level: .info)
        }

        if line.contains("WARN ") {
            let message = line.replacingOccurrences(of: "WARN ", with: "")
            return LogEntry(rawText: message, level: .warning)
        }

        if line.contains("ERROR ") {
            let message = line.replacingOccurrences(of: "ERROR ", with: "")
            return LogEntry(rawText: message, level: .error)
        }

        // Metro bundler messages
        if line.contains("BUNDLE ") || line.contains("metro") {
            return LogEntry(rawText: line, level: .info)
        }

        return nil
    }

    private func appendEntry(_ entry: LogEntry) {
        entries.append(entry)

        // Trim old entries if exceeding max
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
