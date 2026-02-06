import SwiftUI

// MARK: - Controls View

struct ControlsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            // Platform tabs
            PlatformTabs()

            // Device selector
            DeviceRow()

            // Action buttons
            ActionButtons()

            // Make commands (collapsible)
            if let project = appState.currentProject, project.hasMakefile {
                MakeCommandsSection()
            }
        }
        .padding(12)
    }
}

// MARK: - Platform Tabs

struct PlatformTabs: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(appState.supportedPlatforms) { platform in
                PlatformTab(
                    platform: platform,
                    isSelected: appState.selectedPlatform == platform
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectPlatform(platform)
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

struct PlatformTab: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: platform.iconName)
                    .font(.system(size: 10))
                Text(platform.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .secondary)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false
    @State private var showEmulatorPicker = false

    private var hasNoDevices: Bool {
        appState.availableDevices.isEmpty
    }

    private var hasAvailableEmulators: Bool {
        switch appState.selectedPlatform {
        case .android:
            return !appState.deviceManager.availableAVDs.isEmpty
        case .iOS:
            return !appState.deviceManager.availableIOSSimulators.isEmpty
        }
    }

    private var isLaunching: Bool {
        appState.deviceManager.launchingEmulator != nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                // Device picker
                Picker("", selection: $appState.selectedDevice) {
                    if hasNoDevices {
                        Text("No devices")
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

                // Launch emulator
                if hasAvailableEmulators {
                    IconButton(
                        icon: isLaunching ? nil : "play.circle",
                        isLoading: isLaunching,
                        action: { showEmulatorPicker.toggle() }
                    )
                    .popover(isPresented: $showEmulatorPicker, arrowEdge: .bottom) {
                        EmulatorPicker(onSelect: { showEmulatorPicker = false })
                    }
                }

                // Refresh
                IconButton(
                    icon: isRefreshing ? nil : "arrow.clockwise",
                    isLoading: isRefreshing,
                    action: {
                        Task {
                            isRefreshing = true
                            await appState.refreshDevices()
                            isRefreshing = false
                        }
                    }
                )
            }

            // Launching status
            if let name = appState.deviceManager.launchingEmulator {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.4)
                        .frame(width: 10, height: 10)
                    Text("Starting \(name)...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String?
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .frame(width: 24, height: 24)
        .disabled(isLoading)
    }
}

// MARK: - Emulator Picker

struct EmulatorPicker: View {
    @EnvironmentObject var appState: AppState
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.selectedPlatform == .android ? "Emulators" : "Simulators")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    if appState.selectedPlatform == .android {
                        ForEach(appState.deviceManager.availableAVDs, id: \.self) { avd in
                            EmulatorRow(
                                name: avd,
                                icon: "iphone.gen3",
                                isRunning: false
                            ) {
                                Task { await appState.deviceManager.launchAndroidEmulator(avd) }
                                onSelect()
                            }
                        }
                    } else {
                        ForEach(appState.deviceManager.availableIOSSimulators) { sim in
                            EmulatorRow(
                                name: sim.name,
                                icon: sim.name.lowercased().contains("ipad") ? "ipad" : "iphone",
                                isRunning: sim.state == .connected
                            ) {
                                Task { await appState.deviceManager.launchIOSSimulator(sim) }
                                onSelect()
                            }
                            .disabled(sim.state == .connected)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 220)
        .frame(maxHeight: 250)
    }
}

struct EmulatorRow: View {
    let name: String
    let icon: String
    let isRunning: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isRunning ? .green : .secondary)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if isRunning {
                    Text("Running")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                        .opacity(isHovered ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Action Buttons

struct ActionButtons: View {
    @EnvironmentObject var appState: AppState
    @State private var isUninstalling = false

    var body: some View {
        VStack(spacing: 6) {
            // Main action row
            HStack(spacing: 6) {
                // Run/Stop button
                if appState.commandRunner.state.isRunning {
                    ActionButton(
                        title: "Stop",
                        icon: "stop.fill",
                        color: .red,
                        action: { Task { await appState.stop() } }
                    )
                } else {
                    ActionButton(
                        title: "Run",
                        icon: "play.fill",
                        color: .accentColor,
                        isDisabled: !appState.canRun,
                        action: { Task { await appState.run() } }
                    )
                }

                // Uninstall
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
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isUninstalling)
                }
            }

            // Hot reload buttons
            if appState.canHotReload {
                HStack(spacing: 6) {
                    SmallButton(title: "Reload", icon: "flame") {
                        Task { await appState.hotReload() }
                    }
                    SmallButton(title: "Restart", icon: "arrow.clockwise") {
                        Task { await appState.hotRestart() }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.canHotReload)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(isDisabled)
    }
}

struct SmallButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Make Commands Section

struct MakeCommandsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
            // Header
            Button(action: { appState.toggleMakeCommands() }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.showMakeCommands ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Text("Make")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(appState.currentProject?.makefileTargets.count ?? 0)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .buttonStyle(.plain)

            // Content
            if appState.showMakeCommands {
                MakefileCommandsView()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: appState.showMakeCommands)
    }
}

#Preview {
    ControlsView()
        .environmentObject(AppState())
        .frame(width: 260)
}
