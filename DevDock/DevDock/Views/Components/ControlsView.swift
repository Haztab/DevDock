import SwiftUI

/// Controls section with platform/device selection and action buttons
struct ControlsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Platform selector
            PlatformSelector()

            // Device selector
            DeviceSelector()

            // Action buttons
            ActionButtonsView()

            // Makefile commands (if project has Makefile)
            if let project = appState.currentProject, project.hasMakefile {
                Divider()

                // Collapsible section header
                Button(action: { appState.toggleMakeCommands() }) {
                    HStack {
                        Image(systemName: appState.showMakeCommands ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Image(systemName: "terminal")
                            .font(.caption)
                        Text("Make Commands")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(project.makefileTargets.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Collapsible content
                if appState.showMakeCommands {
                    MakefileCommandsView()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Platform Selector

struct PlatformSelector: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(appState.supportedPlatforms) { platform in
                PlatformButton(
                    platform: platform,
                    isSelected: appState.selectedPlatform == platform
                ) {
                    appState.selectPlatform(platform)
                }
            }
        }
    }
}

struct PlatformButton: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: platform.iconName)
                Text(platform.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .secondary)
    }
}

// MARK: - Device Selector

struct DeviceSelector: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false

    /// Whether device list is empty
    private var hasNoDevices: Bool {
        appState.availableDevices.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            // Device picker row
            HStack(spacing: 8) {
                // Device dropdown
                Picker("Device", selection: $appState.selectedDevice) {
                    if hasNoDevices {
                        Text("No devices found")
                            .tag(nil as Device?)
                    } else {
                        ForEach(appState.availableDevices) { device in
                            Text(device.displayName)
                                .tag(device as Device?)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .disabled(hasNoDevices)

                // Refresh button
                Button(action: {
                    Task {
                        isRefreshing = true
                        await appState.refreshDevices()
                        isRefreshing = false
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
                .help("Refresh devices")
            }

            // Inline help when no devices
            if hasNoDevices && !isRefreshing {
                DeviceHelpText(platform: appState.selectedPlatform)
            }
        }
    }
}

/// Inline help text for missing devices
struct DeviceHelpText: View {
    let platform: Platform

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.caption2)

            Text(helpText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var helpText: String {
        switch platform {
        case .android:
            return "Connect device or start emulator"
        case .iOS:
            return "Start simulator: Xcode → Open Developer Tool → Simulator"
        }
    }
}

// MARK: - Action Buttons

struct ActionButtonsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRunPressed = false
    @State private var isStopPressed = false
    @State private var isUninstalling = false

    var body: some View {
        VStack(spacing: 8) {
            // Main run/stop button row with uninstall
            HStack(spacing: 8) {
                // Run or Stop button
                mainActionButton
                    .animation(.snappy, value: appState.commandRunner.state.isRunning)

                // Uninstall button (visible when project and device selected)
                if appState.currentProject != nil && appState.selectedDevice != nil {
                    Button(action: {
                        Task {
                            isUninstalling = true
                            await appState.uninstallApp()
                            isUninstalling = false
                        }
                    }) {
                        if isUninstalling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isUninstalling)
                    .help("Uninstall app from device")
                }
            }

            // Hot reload buttons (Flutter only) with slide animation
            if appState.canHotReload {
                hotReloadButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: appState.canHotReload)
    }

    @ViewBuilder
    private var mainActionButton: some View {
        if appState.commandRunner.state.isRunning {
            // Stop button
            Button(action: {
                Task { await appState.stop() }
            }) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .scaleEffect(isStopPressed ? 0.96 : 1.0)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.snappy) { isStopPressed = pressing }
            }, perform: {})
        } else {
            // Run button
            Button(action: {
                Task { await appState.run() }
            }) {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.canRun)
            .scaleEffect(isRunPressed ? 0.96 : 1.0)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.snappy) { isRunPressed = pressing }
            }, perform: {})
        }
    }

    private var hotReloadButtons: some View {
        HStack(spacing: 8) {
            HotReloadButton(
                title: "Hot Reload",
                icon: "flame",
                help: "Hot reload (r)",
                action: { Task { await appState.hotReload() } }
            )

            HotReloadButton(
                title: "Restart",
                icon: "arrow.clockwise",
                help: "Hot restart (R)",
                action: { Task { await appState.hotRestart() } }
            )
        }
    }
}

/// Animated hot reload button
struct HotReloadButton: View {
    let title: String
    let icon: String
    let help: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.02 : 1.0))
        .help(help)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.snappy) { isPressed = pressing }
        }, perform: {})
    }
}

#Preview {
    ControlsView()
        .environmentObject(AppState())
        .frame(width: 320)
}
