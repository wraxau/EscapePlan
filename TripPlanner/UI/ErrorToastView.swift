import SwiftUI

// MARK: - ErrorToastView
struct ErrorToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(AppFont.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.redAccent)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .appShadow(.elevated)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}

// MARK: - ViewModifier

private struct ErrorToastModifier: ViewModifier {
    @Binding var message: String?

    @State private var isVisible = false
    @State private var task: Task<Void, Never>? = nil

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isVisible, let msg = message {
                    ErrorToastView(message: msg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .onChange(of: message) { newValue in
                guard newValue != nil else { return }
                task?.cancel()
                withAnimation(AppAnimation.quick) { isVisible = true }
                task = Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 сек
                    guard !Task.isCancelled else { return }
                    withAnimation(AppAnimation.quick) { isVisible = false }
                    try? await Task.sleep(nanoseconds: 500_000_000)   // ждём анимацию
                    guard !Task.isCancelled else { return }
                    message = nil
                }
            }
    }
}

extension View {
    func errorToast(message: Binding<String?>) -> some View {
        modifier(ErrorToastModifier(message: message))
    }
}
