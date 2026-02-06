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

            // Copy all logs
            Button(action: { copyAllLogs() }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy all logs")
            .disabled(appState.logProcessor.entries.isEmpty)

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

    private func copyAllLogs() {
        let allText = appState.logProcessor.filteredEntries
            .map { $0.message }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allText, forType: .string)
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
                EmptyLogView()
            } else {
                SelectableLogTextView(
                    entries: appState.logProcessor.filteredEntries,
                    autoScroll: appState.logProcessor.autoScroll
                )
            }
        }
        .frame(minHeight: 200)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Selectable Log Text View (NSViewRepresentable)

struct SelectableLogTextView: NSViewRepresentable {
    let entries: [LogEntry]
    let autoScroll: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let attributedString = NSMutableAttributedString()

        for (index, entry) in entries.enumerated() {
            let color: NSColor
            switch entry.level {
            case .error:
                color = NSColor.systemRed
            case .warning:
                color = NSColor.systemOrange
            case .debug:
                color = NSColor.systemGray
            default:
                color = NSColor.labelColor
            }

            let levelIndicator = "● "
            let levelAttr = NSAttributedString(
                string: levelIndicator,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
                ]
            )

            let messageAttr = NSAttributedString(
                string: entry.message + (index < entries.count - 1 ? "\n" : ""),
                attributes: [
                    .foregroundColor: entry.level == .error ? NSColor.systemRed : NSColor.labelColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                ]
            )

            attributedString.append(levelAttr)
            attributedString.append(messageAttr)
        }

        textView.textStorage?.setAttributedString(attributedString)

        // Auto-scroll to bottom
        if autoScroll && !entries.isEmpty {
            textView.scrollToEndOfDocument(nil)
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
