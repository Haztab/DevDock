import SwiftUI

// MARK: - Main Content View

/// Main content view for the floating panel.
///
/// Displays different states based on app state:
/// - No project selected: Shows `NoProjectSelectedView`
/// - Project selected: Shows compact controls
/// - Log viewer opens in separate window
struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        VStack(spacing: 0) {
            // Header with project info
            HeaderView()

            Divider()

            // Main content area - adapts based on state
            mainContent
        }
        .frame(width: 280)
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

    /// Adaptive main content based on current state
    @ViewBuilder
    private var mainContent: some View {
        if appState.currentProject == nil {
            // No project selected - show onboarding
            NoProjectSelectedView()
                .transition(.opacity)
        } else {
            // Project selected - show compact UI
            VStack(spacing: 0) {
                // Controls section
                ControlsView()

                // Error banner if process failed
                if case .failed(let error) = appState.processState {
                    ErrorBannerView(
                        message: error.localizedDescription,
                        onDismiss: {
                            Task { await appState.stop() }
                        }
                    )
                    .padding(8)
                    .transition(.move(edge: .top))
                }

                Divider()

                // Toolbar for log viewer window
                LogViewerToolbar()
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Log Viewer Toolbar

/// Toolbar to open log viewer in separate window
struct LogViewerToolbar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Log count badges
            if appState.logProcessor.errorCount > 0 {
                Badge(count: appState.logProcessor.errorCount, color: .red)
            }
            if appState.logProcessor.warningCount > 0 {
                Badge(count: appState.logProcessor.warningCount, color: .orange)
            }

            Text("\(appState.logProcessor.entries.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Clear logs button
            Button(action: { appState.clearLogs() }) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Clear Logs (Cmd+K)")

            // Open log viewer button
            Button(action: { openLogViewerWindow() }) {
                Label("Logs", systemImage: "text.alignleft")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Open Log Viewer (Cmd+L)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

        // Position to the right of main window
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

extension ContentView {
    /// Animate content transitions
    private func withContentAnimation<T>(_ action: () -> T) -> T {
        withAnimation(.easeInOut(duration: 0.35)) {
            action()
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            // Project selector
            HStack {
                if let project = appState.currentProject {
                    Image(systemName: project.type.iconName)
                        .foregroundColor(.accentColor)
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { appState.openProjectPicker() }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button(action: { appState.openProjectPicker() }) {
                        Label("Select Project", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }

            // Recent projects dropdown (if no project selected)
            if appState.currentProject == nil && !appState.recentProjects.isEmpty {
                Menu {
                    ForEach(appState.recentProjects) { project in
                        Button(action: { appState.selectProject(project) }) {
                            Label(project.name, systemImage: project.type.iconName)
                        }
                    }
                } label: {
                    Label("Recent Projects", systemImage: "clock")
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
            }

            // Status indicator
            StatusIndicatorView()
        }
        .padding(12)
    }
}

// MARK: - Status Indicator

struct StatusIndicatorView: View {
    @EnvironmentObject var appState: AppState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            // Animated status dot with pulse ring
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Pulse ring for active states
                if shouldPulse {
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 2.5 : 1.0)
                        .opacity(isPulsing ? 0 : 0.8)
                }
            }

            Text(appState.processState.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .contentTransition(.numericText())

            Spacer()

            if appState.commandRunner.state.isRunning {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            }
        }
        .animation(.smooth, value: appState.processState.statusText)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: appState.processState) { _, _ in
            startPulseIfNeeded()
        }
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

    private var shouldPulse: Bool {
        appState.processState == .running || appState.processState == .starting
    }

    private func startPulseIfNeeded() {
        guard shouldPulse else {
            withAnimation { isPulsing = false }
            return
        }
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

#Preview {
    ContentView()
}
