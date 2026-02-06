import SwiftUI

// MARK: - Animation Extensions

extension Animation {
    /// Standard animation for UI state changes
    static var smooth: Animation {
        .easeInOut(duration: 0.2)
    }

    /// Quick animation for hover states and toggles
    static var quick: Animation {
        .easeOut(duration: 0.15)
    }

    /// Spring animation for button presses and feedback
    static var snappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }

    /// Slow animation for content transitions
    static var gentle: Animation {
        .easeInOut(duration: 0.35)
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Slide in from bottom with fade
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Scale with fade for dialogs and alerts
    static var popup: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    /// Fade with slight blur effect
    static var softFade: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply hover effect with scale and shadow
    func hoverEffect(isHovered: Bool) -> some View {
        self
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.1 : 0),
                radius: isHovered ? 4 : 0,
                x: 0,
                y: 2
            )
            .animation(.quick, value: isHovered)
    }

    /// Apply press effect for buttons
    func pressEffect(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.snappy, value: isPressed)
    }

    /// Fade in animation on appear
    func fadeInOnAppear(delay: Double = 0) -> some View {
        self.modifier(FadeInModifier(delay: delay))
    }

    /// Pulse animation for status indicators
    func pulseAnimation(isActive: Bool) -> some View {
        self.modifier(PulseModifier(isActive: isActive))
    }

    /// Shimmer loading effect
    func shimmer(isActive: Bool) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Custom Modifiers

/// Fade in on appear with optional delay
struct FadeInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(.gentle.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

/// Subtle pulse animation for active states
struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if !newValue {
                    isPulsing = false
                }
            }
    }
}

/// Shimmer loading effect
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 200
                        }
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Button Styles

/// Animated button style with press feedback
struct AnimatedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.snappy, value: configuration.isPressed)
    }
}

/// Bounce button style for primary actions
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AnimatedButtonStyle {
    static var animated: AnimatedButtonStyle { AnimatedButtonStyle() }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle { BounceButtonStyle() }
}

// MARK: - Status Indicator Animation

/// Animated status dot with different states
struct AnimatedStatusDot: View {
    let state: ProcessState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                if shouldPulse {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var color: Color {
        switch state {
        case .idle: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .stopping: return .orange
        case .failed: return .red
        }
    }

    private var shouldPulse: Bool {
        state == .running || state == .starting
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    init(state: ProcessState) {
        self.state = state
    }
}

// MARK: - Preview

#Preview("Animations") {
    VStack(spacing: 20) {
        Text("Fade In")
            .fadeInOnAppear(delay: 0.2)

        Circle()
            .fill(.green)
            .frame(width: 20, height: 20)
            .pulseAnimation(isActive: true)

        Button("Animated") {}
            .buttonStyle(.animated)

        Button("Bounce") {}
            .buttonStyle(.bounce)
    }
    .padding()
}
