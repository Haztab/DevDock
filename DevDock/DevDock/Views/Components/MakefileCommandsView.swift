import SwiftUI

/// Displays Makefile targets as clickable buttons
struct MakefileCommandsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
            // Target buttons grid
            if let project = appState.currentProject, !project.makefileTargets.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(project.makefileTargets) { target in
                        MakeTargetButton(
                            target: target,
                            isRunning: appState.runningMakeTarget?.name == target.name
                        ) {
                            Task { await appState.runMakeTarget(target) }
                        }
                    }
                }
            } else {
                Text("No targets found")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Button for a single Makefile target
struct MakeTargetButton: View {
    let target: MakefileTarget
    let isRunning: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                }
                Text(target.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .disabled(isRunning)
        .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.02 : 1.0))
        .help(target.description ?? "Run 'make \(target.name)'")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.snappy) { isPressed = pressing }
        }, perform: {})
    }
}

#Preview {
    MakefileCommandsView()
        .environmentObject(AppState())
        .frame(width: 320)
        .padding()
}
