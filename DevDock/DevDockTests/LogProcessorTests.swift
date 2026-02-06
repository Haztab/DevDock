import XCTest
import Combine
@testable import DevDock

/// Unit tests for LogProcessor service
@MainActor
final class LogProcessorTests: XCTestCase {

    // MARK: - Properties

    private var logProcessor: LogProcessor!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        logProcessor = LogProcessor()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
        logProcessor = nil
        try await super.tearDown()
    }

    // MARK: - Basic Log Entry Tests

    func testAddLogCreatesEntry() {
        // When: Adding a log message
        logProcessor.addLog("Test message")

        // Then: Entry should be added
        XCTAssertEqual(logProcessor.entries.count, 1)
        XCTAssertEqual(logProcessor.entries.first?.message, "Test message")
    }

    func testAddLogWithExplicitLevel() {
        // When: Adding a log with explicit error level
        logProcessor.addLog("Error occurred", level: .error)

        // Then: Entry should have specified level
        XCTAssertEqual(logProcessor.entries.first?.level, .error)
    }

    func testAddSystemMessage() {
        // When: Adding a system message
        logProcessor.addSystemMessage("Process started")

        // Then: Entry should be prefixed and have info level
        XCTAssertEqual(logProcessor.entries.first?.level, .info)
        XCTAssertTrue(logProcessor.entries.first?.message.contains("[DevDock]") == true)
    }

    func testClearLogs() {
        // Given: Some log entries
        logProcessor.addLog("Message 1")
        logProcessor.addLog("Message 2")
        XCTAssertEqual(logProcessor.entries.count, 2)

        // When: Clearing logs
        logProcessor.clearLogs()

        // Then: Entries should be empty
        XCTAssertTrue(logProcessor.entries.isEmpty)
    }

    // MARK: - Log Level Detection Tests

    func testDetectsErrorLevel() {
        // When: Adding logs with error keywords
        logProcessor.addLog("ERROR: Something went wrong")
        logProcessor.addLog("EXCEPTION thrown in main")
        logProcessor.addLog("FATAL crash")
        logProcessor.addLog("FAILURE to connect")

        // Then: All should be detected as error level
        for entry in logProcessor.entries {
            XCTAssertEqual(entry.level, .error, "'\(entry.message)' should be error level")
        }
    }

    func testDetectsWarningLevel() {
        // When: Adding logs with warning keywords
        logProcessor.addLog("WARNING: Low memory")
        logProcessor.addLog("WARN: Deprecated API")

        // Then: Should be detected as warning level
        for entry in logProcessor.entries {
            XCTAssertEqual(entry.level, .warning, "'\(entry.message)' should be warning level")
        }
    }

    func testDetectsDebugLevel() {
        // When: Adding logs with debug keywords
        logProcessor.addLog("DEBUG: Variable value")
        logProcessor.addLog("[DEBUG] Trace info")

        // Then: Should be detected as debug level
        for entry in logProcessor.entries {
            XCTAssertEqual(entry.level, .debug, "'\(entry.message)' should be debug level")
        }
    }

    func testDetectsInfoLevel() {
        // When: Adding logs with info keywords
        logProcessor.addLog("INFO: Server started")

        // Then: Should be detected as info level
        XCTAssertEqual(logProcessor.entries.first?.level, .info)
    }

    func testDefaultsToInfoLevel() {
        // When: Adding a log without level keywords
        logProcessor.addLog("Just a regular message")

        // Then: Should default to info level
        XCTAssertEqual(logProcessor.entries.first?.level, .info)
    }

    // MARK: - Android Logcat Format Tests

    func testDetectsAndroidLogcatErrorFormat() {
        // When: Adding Android E/ format log
        logProcessor.addLog("E/MainActivity: Null pointer")

        // Then: Should detect as error
        XCTAssertEqual(logProcessor.entries.first?.level, .error)
    }

    func testDetectsAndroidLogcatWarningFormat() {
        // When: Adding Android W/ format log
        logProcessor.addLog("W/System: Low battery")

        // Then: Should detect as warning
        XCTAssertEqual(logProcessor.entries.first?.level, .warning)
    }

    func testDetectsAndroidLogcatDebugFormat() {
        // When: Adding Android D/ format log
        logProcessor.addLog("D/FlutterView: View created")

        // Then: Should detect as debug
        XCTAssertEqual(logProcessor.entries.first?.level, .debug)
    }

    func testDetectsAndroidLogcatInfoFormat() {
        // When: Adding Android I/ format log
        logProcessor.addLog("I/Process: Started")

        // Then: Should detect as info
        XCTAssertEqual(logProcessor.entries.first?.level, .info)
    }

    // MARK: - Log Count Tests

    func testErrorCount() {
        // Given: Mixed log levels
        logProcessor.addLog("ERROR: First error")
        logProcessor.addLog("INFO: Normal message")
        logProcessor.addLog("ERROR: Second error")
        logProcessor.addLog("WARNING: A warning")

        // Then: Error count should be correct
        XCTAssertEqual(logProcessor.errorCount, 2)
    }

    func testWarningCount() {
        // Given: Mixed log levels
        logProcessor.addLog("WARNING: First")
        logProcessor.addLog("INFO: Normal")
        logProcessor.addLog("WARNING: Second")
        logProcessor.addLog("WARN: Third")

        // Then: Warning count should be correct
        XCTAssertEqual(logProcessor.warningCount, 3)
    }

    // MARK: - Log Filter Tests

    func testFilterByLevel() {
        // Given: Mixed log levels
        logProcessor.addLog("ERROR: Error message")
        logProcessor.addLog("INFO: Info message")
        logProcessor.addLog("WARNING: Warning message")

        // When: Filtering by error level
        logProcessor.filter.level = .error

        // Then: Only error entries should match
        let filtered = logProcessor.filteredEntries
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.level, .error)
    }

    func testFilterBySearchText() {
        // Given: Logs with different content
        logProcessor.addLog("Flutter app started")
        logProcessor.addLog("Device connected")
        logProcessor.addLog("Flutter hot reload")

        // When: Filtering by search text
        logProcessor.filter.searchText = "flutter"

        // Then: Only matching entries should be returned
        let filtered = logProcessor.filteredEntries
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterBySearchTextCaseInsensitive() {
        // Given: Logs with mixed case
        logProcessor.addLog("FLUTTER started")
        logProcessor.addLog("flutter running")

        // When: Filtering with lowercase search
        logProcessor.filter.searchText = "flutter"

        // Then: Both should match (case insensitive)
        let filtered = logProcessor.filteredEntries
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterAllLevelReturnsAll() {
        // Given: Mixed log levels
        logProcessor.addLog("ERROR: Error")
        logProcessor.addLog("INFO: Info")
        logProcessor.addLog("WARNING: Warning")

        // When: Filter level is .all
        logProcessor.filter.level = .all

        // Then: All entries should be returned
        let filtered = logProcessor.filteredEntries
        XCTAssertEqual(filtered.count, 3)
    }

    func testCombinedFilters() {
        // Given: Various log entries
        logProcessor.addLog("ERROR: Flutter crash")
        logProcessor.addLog("ERROR: React crash")
        logProcessor.addLog("INFO: Flutter started")

        // When: Filtering by level AND search text
        logProcessor.filter.level = .error
        logProcessor.filter.searchText = "Flutter"

        // Then: Only matching entries should be returned
        let filtered = logProcessor.filteredEntries
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.first?.message.contains("Flutter") == true)
    }

    // MARK: - Max Entries Tests

    func testMaxEntriesLimit() {
        // Given: Adding more than max entries (5000)
        // We'll add a smaller number to test the trimming logic
        let processor = LogProcessor()

        // Add entries up to the limit
        for i in 1...5005 {
            processor.addLog("Message \(i)")
        }

        // Then: Should be capped at max entries
        XCTAssertEqual(processor.entries.count, 5000)

        // And oldest entries should be removed (first entry should be "Message 6")
        XCTAssertEqual(processor.entries.first?.message, "Message 6")
    }

    // MARK: - Export Tests

    func testExportLogs() throws {
        // Given: Some log entries
        logProcessor.addLog("First message", level: .info)
        logProcessor.addLog("Error occurred", level: .error)

        // When: Exporting to file
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export.log")
        try logProcessor.exportLogs(to: tempFile)

        // Then: File should contain formatted logs
        let content = try String(contentsOf: tempFile, encoding: .utf8)
        XCTAssertTrue(content.contains("[INFO]"))
        XCTAssertTrue(content.contains("[ERROR]"))
        XCTAssertTrue(content.contains("First message"))
        XCTAssertTrue(content.contains("Error occurred"))

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    // MARK: - Auto Scroll Tests

    func testAutoScrollDefaultsToTrue() {
        // Then: Auto scroll should be enabled by default
        XCTAssertTrue(logProcessor.autoScroll)
    }

    func testAutoScrollCanBeToggled() {
        // When: Toggling auto scroll
        logProcessor.autoScroll = false

        // Then: Should be disabled
        XCTAssertFalse(logProcessor.autoScroll)
    }
}

// MARK: - LogLevel Detection Tests

final class LogLevelDetectionTests: XCTestCase {

    func testDetectErrorFromText() {
        XCTAssertEqual(LogLevel.detect(from: "ERROR: Something failed"), .error)
        XCTAssertEqual(LogLevel.detect(from: "EXCEPTION occurred"), .error)
        XCTAssertEqual(LogLevel.detect(from: "FATAL error"), .error)
        XCTAssertEqual(LogLevel.detect(from: "FAILURE in build"), .error)
        XCTAssertEqual(LogLevel.detect(from: "E/Tag: Android error"), .error)
    }

    func testDetectWarningFromText() {
        XCTAssertEqual(LogLevel.detect(from: "WARNING: Deprecated"), .warning)
        XCTAssertEqual(LogLevel.detect(from: "WARN: Check this"), .warning)
        XCTAssertEqual(LogLevel.detect(from: "W/Tag: Android warning"), .warning)
    }

    func testDetectDebugFromText() {
        XCTAssertEqual(LogLevel.detect(from: "DEBUG: Variable value"), .debug)
        XCTAssertEqual(LogLevel.detect(from: "[DEBUG] Trace"), .debug)
        XCTAssertEqual(LogLevel.detect(from: "D/Tag: Android debug"), .debug)
    }

    func testDetectInfoFromText() {
        XCTAssertEqual(LogLevel.detect(from: "INFO: Server started"), .info)
        XCTAssertEqual(LogLevel.detect(from: "I/Tag: Android info"), .info)
    }

    func testDefaultToInfoForUnknown() {
        XCTAssertEqual(LogLevel.detect(from: "Just a message"), .info)
        XCTAssertEqual(LogLevel.detect(from: "12345"), .info)
    }
}

// MARK: - LogFilter Tests

final class LogFilterTests: XCTestCase {

    func testMatchesAllLevel() {
        let filter = LogFilter(level: .all, searchText: "")
        let entry = LogEntry(rawText: "Any message", level: .error)

        XCTAssertTrue(filter.matches(entry))
    }

    func testMatchesSpecificLevel() {
        let filter = LogFilter(level: .error, searchText: "")
        let errorEntry = LogEntry(rawText: "Error", level: .error)
        let infoEntry = LogEntry(rawText: "Info", level: .info)

        XCTAssertTrue(filter.matches(errorEntry))
        XCTAssertFalse(filter.matches(infoEntry))
    }

    func testMatchesSearchText() {
        let filter = LogFilter(level: .all, searchText: "flutter")
        let matchingEntry = LogEntry(rawText: "Flutter started", level: .info)
        let nonMatchingEntry = LogEntry(rawText: "React started", level: .info)

        XCTAssertTrue(filter.matches(matchingEntry))
        XCTAssertFalse(filter.matches(nonMatchingEntry))
    }

    func testMatchesCombinedFilters() {
        let filter = LogFilter(level: .error, searchText: "crash")
        let match = LogEntry(rawText: "App crash ERROR", level: .error)
        let wrongLevel = LogEntry(rawText: "App crash", level: .info)
        let wrongText = LogEntry(rawText: "Error occurred", level: .error)

        XCTAssertTrue(filter.matches(match))
        XCTAssertFalse(filter.matches(wrongLevel))
        XCTAssertFalse(filter.matches(wrongText))
    }
}
