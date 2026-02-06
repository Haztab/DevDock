import SwiftUI

// MARK: - Empty State Views

/// Empty state displayed when no project is selected
struct NoProjectSelectedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)

            Text("No Project Selected")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Select a Flutter, React Native, or native mobile project to get started.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { appState.openProjectPicker() }) {
                Label("Open Project", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !appState.recentProjects.isEmpty {
                Divider()
                    .padding(.vertical, 8)

                Text("Recent Projects")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    ForEach(appState.recentProjects.prefix(3)) { project in
                        RecentProjectRow(project: project)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row displaying a recent project
struct RecentProjectRow: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button(action: { appState.selectProject(project) }) {
            HStack(spacing: 8) {
                Image(systemName: project.type.iconName)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                Text(project.name)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - No Devices View

/// Empty state displayed when no devices are available
struct NoDevicesView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No \(appState.selectedPlatform.rawValue) Devices")
                .font(.subheadline)
                .fontWeight(.medium)

            Text(helpText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: refreshDevices) {
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var deviceIcon: String {
        switch appState.selectedPlatform {
        case .android:
            return "phone.and.waveform"
        case .iOS:
            return "iphone.slash"
        }
    }

    private var helpText: String {
        switch appState.selectedPlatform {
        case .android:
            return "Connect a device or start an emulator.\nEnsure ADB is running."
        case .iOS:
            return "Start a simulator from Xcode or\nuse 'xcrun simctl boot <device>'"
        }
    }

    private func refreshDevices() {
        isRefreshing = true
        Task {
            await appState.refreshDevices()
            isRefreshing = false
        }
    }
}

// MARK: - Empty Logs View

/// Empty state displayed when log viewer has no entries
struct EmptyLogsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No Logs Yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Run your app to see logs here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error State Views

/// Error state displayed when a process fails
struct ProcessErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)

            Text("Process Failed")
                .font(.headline)
                .foregroundColor(.primary)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 12) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)

                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Error banner displayed at top of log viewer
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()

            // Copy button
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy error message")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

/// Command not found error with installation help
struct CommandNotFoundView: View {
    let command: String
    let platform: Platform

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("'\(command)' Not Found")
                .font(.headline)

            Text(installInstructions)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let url = installURL {
                Link(destination: url) {
                    Label("Installation Guide", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private var installInstructions: String {
        switch command {
        case "flutter":
            return "Flutter SDK is not installed or not in PATH.\nInstall from flutter.dev"
        case "adb":
            return "Android SDK is not installed.\nInstall Android Studio or standalone SDK."
        case "xcrun":
            return "Xcode Command Line Tools not installed.\nRun: xcode-select --install"
        case "npx", "npm", "node":
            return "Node.js is not installed.\nInstall from nodejs.org"
        default:
            return "The required tool is not installed or not in your PATH."
        }
    }

    private var installURL: URL? {
        switch command {
        case "flutter":
            return URL(string: "https://docs.flutter.dev/get-started/install/macos")
        case "adb":
            return URL(string: "https://developer.android.com/studio")
        case "npx", "npm", "node":
            return URL(string: "https://nodejs.org")
        default:
            return nil
        }
    }
}

// MARK: - Loading State

/// Loading indicator with optional message
struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Inline loading indicator for buttons
struct InlineLoadingView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(0.6)
            .frame(width: 16, height: 16)
    }
}

// MARK: - Previews

#Preview("No Project") {
    NoProjectSelectedView()
        .environmentObject(AppState())
        .frame(width: 320, height: 400)
}

#Preview("No Devices") {
    NoDevicesView()
        .environmentObject(AppState())
        .frame(width: 320)
        .padding()
}

#Preview("Empty Logs") {
    EmptyLogsView()
        .frame(width: 320, height: 200)
}

#Preview("Error Banner") {
    ErrorBannerView(message: "Connection lost to device", onDismiss: {})
        .frame(width: 320)
        .padding()
}

#Preview("Command Not Found") {
    CommandNotFoundView(command: "flutter", platform: .android)
        .frame(width: 320)
        .padding()
}
