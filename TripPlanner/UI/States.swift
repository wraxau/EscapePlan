
import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.primaryAccent.opacity(0.4))

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(AppFont.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, action: action)
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.top, Spacing.sm)
            }

            Spacer()
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryAccent))
                    .scaleEffect(1.4)
                Text("Загрузка...")
                    .font(AppFont.subheadline)
                    .foregroundColor(.textSecondary)
            }
            .padding(Spacing.xl)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .appShadow(.elevated)
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    EmptyStateView(
        icon: "airplane",
        title: "Нет поездок",
        subtitle: "Создай первую поездку и начни планировать своё путешествие",
        buttonTitle: "Создать поездку"
    ) {}
}

#Preview("Loading") {
    LoadingOverlay()
}
