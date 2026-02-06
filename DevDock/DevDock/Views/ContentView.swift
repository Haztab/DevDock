import SwiftUI

// MARK: - Main Content View

/// Main content view for the floating panel.
///
/// Displays different states based on app state:
/// - No project selected: Shows `NoProjectSelectedView`
/// - Project selected: Shows full controls and log viewer
/// - Error state: Shows error banner with retry option
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
        .frame(width: 320, minHeight: 400, maxHeight: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .environmentObject(appState)
        .handleMenuActions(appState: appState)
        .alert("Error", isPresented: $appState.showingAlert) {
            Button("OK") { }
        } message: {
            Text(appState.alertMessage)
        }
    }

    /// Adaptive main content based on current state
    @ViewBuilder
    private var mainContent: some View {
        if appState.currentProject == nil {
            // No project selected - show onboarding
            NoProjectSelectedView()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            // Project selected - show full UI
            VStack(spacing: 0) {
                // Controls section
                ControlsView()

                Divider()

                // Error banner if process failed
                if case .failed(let error) = appState.processState {
                    ErrorBannerView(
                        message: error.localizedDescription,
                        onDismiss: {
                            Task { await appState.stop() }
                        }
                    )
                    .padding(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Log viewer
                LogViewerView()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
}

extension ContentView {
    /// Animate content transitions
    private func withContentAnimation<T>(_ action: () -> T) -> T {
        withAnimation(.gentle) {
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
