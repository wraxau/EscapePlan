import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
}

// MARK: - Onboarding View

struct OnboardingView: View {

    let onFinish: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "suitcase.fill",
            title: "Планируй\nпутешествия",
            subtitle: "Создавай маршруты, добавляй места и\nделись поездками с друзьями",
            accent: Color.primaryAccent
        ),
        OnboardingPage(
            icon: "creditcard.fill",
            title: "Контролируй\nрасходы",
            subtitle: "Отслеживай траты и честно делите\nсчёт между всеми участниками",
            accent: Color.primaryAccent
        ),
        OnboardingPage(
            icon: "camera.fill",
            title: "Сохраняй\nвоспоминания",
            subtitle: "Фотографируй лучшие моменты и\nприкрепляй их к местам на карте",
            accent: Color.primaryAccent
        )
    ]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Пропустить") {
                            withAnimation(AppAnimation.standard) {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(AppFont.body)
                        .foregroundColor(.primaryAccent.opacity(0.7))
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                    }
                }
                .frame(height: 56)
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { idx in
                        pageView(pages[idx])
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppAnimation.standard, value: currentPage)
                HStack(spacing: Spacing.sm) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx == currentPage
                                  ? Color.primaryAccent
                                  : Color.primaryAccent.opacity(0.25))
                            .frame(width: idx == currentPage ? 24 : 8, height: 8)
                            .animation(AppAnimation.quick, value: currentPage)
                    }
                }
                .padding(.bottom, Spacing.lg)
                actionButton
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.bottom, Spacing.xxl)
            }
        }
    }

    // MARK: - Page

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.primaryAccent.opacity(0.12))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.primaryAccent.opacity(0.07))
                    .frame(width: 110, height: 110)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(page.accent)
            }

            // Текст
            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(AppFont.display(32))
                    .foregroundColor(.primaryAccent)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(page.subtitle)
                    .font(AppFont.body)
                    .foregroundColor(.primaryAccent.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation(AppAnimation.standard) {
                    currentPage += 1
                }
            } else {
                onFinish()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(currentPage < pages.count - 1 ? "Далее" : "Начать")
                    .font(AppFont.display(17))
                Image(systemName: currentPage < pages.count - 1
                      ? "arrow.right" : "mappin.and.ellipse")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.primaryAccent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .animation(AppAnimation.quick, value: currentPage)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onFinish: {})
}
