import SwiftUI

// MARK: - No Project Selected

struct NoProjectSelectedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon
            Image(systemName: "folder")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))

            // Text
            VStack(spacing: 4) {
                Text("No Project")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text("Open a Flutter or mobile project")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Open button
            Button(action: { appState.openProjectPicker() }) {
                Label("Open Project", systemImage: "folder.badge.plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)

            // Recent projects
            if !appState.recentProjects.isEmpty {
                VStack(spacing: 6) {
                    Text("Recent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    VStack(spacing: 2) {
                        ForEach(appState.recentProjects.prefix(3)) { project in
                            RecentProjectRow(project: project)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RecentProjectRow: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button(action: { appState.selectProject(project) }) {
            HStack(spacing: 8) {
                Image(systemName: project.type.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                    .frame(width: 16)

                Text(project.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)

            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.red.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Previews

#Preview("No Project") {
    NoProjectSelectedView()
        .environmentObject(AppState())
        .frame(width: 260, height: 350)
}

#Preview("Error Banner") {
    ErrorBannerView(message: "Build failed: Could not find target", onDismiss: {})
        .frame(width: 260)
        .padding()
}
