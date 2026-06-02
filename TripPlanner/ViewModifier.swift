import SwiftUI

// MARK: - Screen Background

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appBackground.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}

struct NavigationAppearance {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.shadowColor = .clear

        if let delagoFont = UIFont(name: "Delago", size: 22) {
            appearance.largeTitleTextAttributes = [
                .font: delagoFont,
                .foregroundColor: UIColor(Color.textPrimary)
            ]
            let inlineTitleFont = UIFont(name: "Delago", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
            appearance.titleTextAttributes = [
                .font: inlineTitleFont,
                .foregroundColor: UIColor(Color.textPrimary)
            ]
        }

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Navigation Bar Background

extension View {
    func appNavBar() -> some View {
        self.toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - Tab Bar Style

struct TabBarAppearance {
    static func apply() {}
}

// MARK: - Shake Animation (для ошибок ввода)

struct ShakeModifier: ViewModifier, Animatable {
    var shakes: CGFloat = 0

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakes * .pi * 2) * 8)
    }
}

extension View {
    func shake(_ shakes: CGFloat) -> some View {
        modifier(ShakeModifier(shakes: shakes))
    }
}

// MARK: - Conditional Redacted (skeleton loading)

struct RedactedModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmering(active: isLoading)
    }
}
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var active: Bool = true

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3))
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(content)
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    func skeletonLoading(_ isLoading: Bool) -> some View {
        modifier(RedactedModifier(isLoading: isLoading))
    }
}

// MARK: - Keyboard Dismiss on Tap

private final class KeyboardDismissGestureRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

private struct KeyboardDismissViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            let alreadyInstalled = window.gestureRecognizers?
                .contains { $0 is KeyboardDismissGestureRecognizer } ?? false
            guard !alreadyInstalled else { return }
            window.addGestureRecognizer(KeyboardDismissGestureRecognizer())
        }
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        background(KeyboardDismissViewRepresentable())
    }
}

// MARK: - Press Animation

struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
    }
}

extension View {
    func pressAnimation() -> some View {
        modifier(PressAnimationModifier())
    }
}
