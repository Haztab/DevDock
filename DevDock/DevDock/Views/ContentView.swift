import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentProject == nil {
                NoProjectSelectedView()
            } else {
                // Compact main UI
                VStack(spacing: 0) {
                    // Project header
                    ProjectHeader()

                    Divider()
                        .padding(.horizontal, 12)

                    // Controls
                    ControlsView()

                    Spacer(minLength: 0)

                    // Bottom toolbar
                    BottomToolbar()
                }
            }
        }
        .frame(width: 260)
        .background(Color(NSColor.windowBackgroundColor))
        .environmentObject(appState)
        .handleMenuActions(appState: appState)
        .alert("Error", isPresented: $appState.showingAlert) {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(appState.alertMessage, forType: .string)
            }
            Button("OK") { }
        } message: {
            Text(appState.alertMessage)
        }
        .task {
            await appState.refreshDevices()
        }
    }
}

// MARK: - Project Header

struct ProjectHeader: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button(action: { appState.openProjectPicker() }) {
            HStack(spacing: 8) {
                // Project icon
                Image(systemName: appState.currentProject?.type.iconName ?? "folder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)

                // Project name
                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.currentProject?.name ?? "Select Project")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(appState.processState.statusText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? Color.gray.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var statusColor: Color {
        switch appState.processState {
        case .idle: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .stopping: return .orange
        case .failed: return .red
        }
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            // Error badge
            if appState.logProcessor.errorCount > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("\(appState.logProcessor.errorCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }

            // Warning badge
            if appState.logProcessor.warningCount > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(appState.logProcessor.warningCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Clear logs
            Button(action: { appState.clearLogs() }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Clear logs")

            // Open log viewer
            Button(action: { openLogViewerWindow() }) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text("Logs")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Open log viewer")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func openLogViewerWindow() {
        LogViewerWindowController.shared.showWindow(appState: appState)
    }
}

// MARK: - Log Viewer Window Controller

class LogViewerWindowController {
    static let shared = LogViewerWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func showWindow(appState: AppState) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let logViewerContent = LogViewerWindowContent()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: AnyView(logViewerContent))
        self.hostingController = hostingController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "DevDock Logs"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let mainWindow = NSApplication.shared.windows.first(where: { $0.title != "DevDock Logs" }) {
            let mainFrame = mainWindow.frame
            let logX = mainFrame.maxX + 20
            let logY = mainFrame.midY - 200
            window.setFrameOrigin(NSPoint(x: logX, y: logY))
        } else {
            window.center()
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.close()
    }
}

// MARK: - Log Viewer Window Content

struct LogViewerWindowContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            LogViewerView()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
