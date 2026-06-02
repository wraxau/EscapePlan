import SwiftUI

// MARK: - App Card (базовый контейнер)

struct AppCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .appShadow(.card)
    }
}

// MARK: - Trip Card

struct TripCard: View {
    let name: String
    let dateRange: String
    let participantsCount: Int
    let totalExpenses: String
    var coverImage: UIImage? = nil

    var body: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {

                // Обложка
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let img = coverImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [.primaryAccent, .secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 160)
                    .clipped()

                    Text(dateRange)
                        .font(AppFont.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .padding(Spacing.md)
                }

                // Информация
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        CardTitle(text: name)

                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                            Text("\(participantsCount) чел.")
                                .font(AppFont.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        Text("Расходы")
                            .font(AppFont.tiny)
                            .foregroundColor(.textSecondary)
                        Text(totalExpenses)
                            .font(AppFont.headline)
                            .foregroundColor(.primaryAccent)
                    }
                }
                .padding(Spacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
    }
}

// MARK: - Day Plan Card

struct DayPlanCard: View {
    let dayNumber: Int
    let date: Date
    let placesCount: Int

    private var formattedDate: String {
        date.formattedDate()
    }

    var body: some View {
        AppCard {
            HStack(spacing: Spacing.md) {
                VStack(spacing: 2) {
                    Text("День")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)
                    Text("\(dayNumber)")
                        .font(AppFont.title)
                        .foregroundColor(.primaryAccent)
                }
                .frame(width: 50)

                Divider().frame(height: 44)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(formattedDate)
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)
                    Label("\(placesCount) мест", systemImage: "mappin.circle")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            TripCard(
                name: "Барселона 2026",
                dateRange: "15 июл — 22 июл",
                participantsCount: 3,
                totalExpenses: "€ 1 240"
            )
            DayPlanCard(dayNumber: 1, date: Date(), placesCount: 4)
            DayPlanCard(dayNumber: 2, date: Date().addingTimeInterval(86400), placesCount: 2)
        }
        .padding(Spacing.md)
    }
}
