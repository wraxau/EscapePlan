import SwiftUI
import MapKit

struct RouteInstructionsView: View {
    let steps: [MKRoute.Step]
    let transportType: TransportType

    @State private var expandedStepIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Заголовок
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryAccent)

                Text("Направления")
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(steps.count) шагов")
                    .font(AppFont.caption)
                    .foregroundColor(.textSecondary)
            }

            Divider()

            // Список инструкций
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(steps.indices, id: \.self) { index in
                    stepCard(steps[index], index: index)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    @ViewBuilder
    private func stepCard(_ step: MKRoute.Step, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Заголовок шага
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Номер шага
                Circle()
                    .fill(Color.primaryAccent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("\(index + 1)")
                            .font(AppFont.caption.weight(.semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Инструкция
                    Text(step.instructions)
                        .font(AppFont.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    // Расстояние
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.primaryAccent.opacity(0.6))

                        Text(formatDistance(step.distance))
                            .font(AppFont.tiny)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                directionIcon(for: step)
            }
            .padding(Spacing.sm)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func directionIcon(for step: MKRoute.Step) -> some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primaryAccent.opacity(0.4))
            .frame(width: 24)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let meters = distance
        if meters < 1000 {
            return "\(Int(meters))м"
        } else {
            let km = meters / 1000.0
            return String(format: "%.2f км", km)
        }
    }
}

// MARK: - Preview

#Preview {
    EmptyView()
}
