import SwiftUI

// MARK: - Log Viewer View

struct LogViewerView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedLevel: LogLevel = .all

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            LogToolbarView(
                searchText: $searchText,
                selectedLevel: $selectedLevel
            )

            Divider()

            // Log content
            LogContentView(searchText: searchText)
        }
    }
}

// MARK: - Log Toolbar

struct LogToolbarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var searchText: String
    @Binding var selectedLevel: LogLevel

    var body: some View {
        HStack(spacing: 8) {
            // Filter
            Picker("", selection: $selectedLevel) {
                ForEach(LogLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .labelsHidden()
            .frame(width: 80)
            .onChange(of: selectedLevel) { _, newValue in
                appState.logProcessor.filter.level = newValue
            }

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .onChange(of: searchText) { _, newValue in
                appState.logProcessor.filter.searchText = newValue
            }

            Spacer()

            // Badges
            HStack(spacing: 4) {
                if appState.logProcessor.errorCount > 0 {
                    CountBadge(count: appState.logProcessor.errorCount, color: .red)
                }
                if appState.logProcessor.warningCount > 0 {
                    CountBadge(count: appState.logProcessor.warningCount, color: .orange)
                }
            }

            // Actions
            HStack(spacing: 2) {
                ToolbarButton(
                    icon: appState.logProcessor.autoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact",
                    isActive: appState.logProcessor.autoScroll,
                    help: "Auto-scroll"
                ) {
                    appState.logProcessor.autoScroll.toggle()
                }

                ToolbarButton(icon: "doc.on.doc", help: "Copy all") {
                    copyAllLogs()
                }

                ToolbarButton(icon: "trash", help: "Clear") {
                    appState.clearLogs()
                }

                ToolbarButton(icon: "square.and.arrow.up", help: "Export") {
                    appState.exportLogs()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func copyAllLogs() {
        let text = appState.logProcessor.filteredEntries
            .map { $0.message }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .foregroundColor(isActive ? .accentColor : .secondary)
        .frame(width: 24, height: 20)
        .help(help)
    }
}

struct CountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Log Content

struct LogContentView: View {
    @EnvironmentObject var appState: AppState
    let searchText: String

    private var isEmpty: Bool {
        appState.logProcessor.filteredEntries.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                EmptyLogState()
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

// MARK: - Selectable Log Text View

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
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let attributed = NSMutableAttributedString()

        for (index, entry) in entries.enumerated() {
            let dotColor: NSColor
            switch entry.level {
            case .error: dotColor = .systemRed
            case .warning: dotColor = .systemOrange
            case .debug: dotColor = .systemGray
            default: dotColor = .labelColor
            }

            // Level dot
            let dot = NSAttributedString(
                string: "● ",
                attributes: [
                    .foregroundColor: dotColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
                ]
            )

            // Message
            let textColor: NSColor = entry.level == .error ? .systemRed : .labelColor
            let message = NSAttributedString(
                string: entry.message + (index < entries.count - 1 ? "\n" : ""),
                attributes: [
                    .foregroundColor: textColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                ]
            )

            attributed.append(dot)
            attributed.append(message)
        }

        textView.textStorage?.setAttributedString(attributed)

        if autoScroll && !entries.isEmpty {
            textView.scrollToEndOfDocument(nil)
        }
    }
}

// MARK: - Empty State

struct EmptyLogState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No logs")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Run your app to see logs")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Keep Badge for backward compatibility
struct Badge: View {
    let count: Int
    let color: Color

    var body: some View {
        CountBadge(count: count, color: color)
    }
}

#Preview {
    LogViewerView()
        .environmentObject(AppState())
        .frame(width: 400, height: 300)
}
