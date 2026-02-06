import SwiftUI

/// Real-time log viewer with filtering
struct LogViewerView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Log toolbar
            LogToolbar(searchText: $searchText)

            Divider()

            // Log list
            LogListView(searchText: searchText)
        }
    }
}

// MARK: - Log Toolbar

struct LogToolbar: View {
    @EnvironmentObject var appState: AppState
    @Binding var searchText: String
    @State private var selectedLevel: LogLevel = .all

    var body: some View {
        HStack(spacing: 8) {
            // Filter picker
            Picker("Level", selection: $selectedLevel) {
                ForEach(LogLevel.allCases) { level in
                    Label(level.rawValue, systemImage: level.iconName)
                        .tag(level)
                }
            }
            .labelsHidden()
            .frame(width: 90)
            .onChange(of: selectedLevel) { _, newValue in
                appState.logProcessor.filter.level = newValue
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Toolbar buttons
            ToolbarButtons()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: searchText) { _, newValue in
            appState.logProcessor.filter.searchText = newValue
        }
    }
}

struct ToolbarButtons: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            // Error/Warning counts
            if appState.logProcessor.errorCount > 0 {
                Badge(count: appState.logProcessor.errorCount, color: .red)
            }
            if appState.logProcessor.warningCount > 0 {
                Badge(count: appState.logProcessor.warningCount, color: .orange)
            }

            // Auto-scroll toggle
            Button(action: {
                appState.logProcessor.autoScroll.toggle()
            }) {
                Image(systemName: appState.logProcessor.autoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact")
            }
            .buttonStyle(.borderless)
            .foregroundColor(appState.logProcessor.autoScroll ? .accentColor : .secondary)
            .help("Auto-scroll \(appState.logProcessor.autoScroll ? "on" : "off")")

            // Clear logs
            Button(action: { appState.clearLogs() }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear logs")

            // Export logs
            Button(action: { appState.exportLogs() }) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export logs")
        }
    }
}

struct Badge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Log List

struct LogListView: View {
    @EnvironmentObject var appState: AppState
    let searchText: String

    /// Whether the log list is empty (considering filters)
    private var isEmpty: Bool {
        appState.logProcessor.filteredEntries.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                // Empty state
                EmptyLogView()
            } else {
                // Log entries
                logScrollView
            }
        }
        .frame(minHeight: 200)
        .background(Color(NSColor.textBackgroundColor))
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(appState.logProcessor.filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: appState.logProcessor.entries.count) { _, _ in
                if appState.logProcessor.autoScroll,
                   let lastEntry = appState.logProcessor.filteredEntries.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Level indicator
            Circle()
                .fill(entry.level.color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            // Message
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.level == .error ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyLogView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No logs yet")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Run your app to see logs here")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LogViewerView()
        .environmentObject(AppState())
        .frame(width: 320, height: 300)
}
