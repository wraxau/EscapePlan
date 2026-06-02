import SwiftUI
import MapKit

struct FullRouteDetailView: View {
    let trip: Trip
    let day: DayPlan
    let activities: [Activity]
    let routeSegments: [DayScheduleView.RouteSegment]
    let routePolylines: [MKPolyline]
    let transportType: TransportType
    let allRouteSteps: [[MKRoute.Step]]

    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0, longitude: 28.97),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @Environment(\.dismiss) var dismiss
    var initialRegion: MKCoordinateRegion {
        let coords = activities.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.0, longitude: 28.97),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLng = lngs.min(),
              let maxLng = lngs.max() else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.0, longitude: 28.97),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Карта на весь размер
                MapWithRoute(
                    region: $mapRegion,
                    activities: activities,
                    polylines: routePolylines,
                    showRoute: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                // MARK: - Нижняя карточка с информацией
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Route summary
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text("Маршрут дня")
                                            .font(AppFont.headline)
                                            .foregroundColor(.textPrimary)

                                        Text(formattedDate(day.date))
                                            .font(AppFont.caption)
                                            .foregroundColor(.textSecondary)
                                    }

                                    Spacer()

                                    // Вид транспорта
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: transportType.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(transportType.rawValue)
                                            .font(AppFont.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.primaryAccent)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(Color.primaryAccent.opacity(0.1))
                                    .clipShape(Capsule())
                                }

                                // Summary data in two columns
                                let totalDistance = routeSegments.reduce(0) { $0 + $1.distance }
                                let totalTime = routeSegments.reduce(0) { $0 + $1.estimatedTime }

                                HStack(spacing: Spacing.md) {
                                    // Расстояние
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("Расстояние")
                                                .font(AppFont.tiny)
                                        }
                                        .foregroundColor(.textSecondary)

                                        Text(String(format: "%.1f км", totalDistance))
                                            .font(AppFont.headline)
                                            .foregroundColor(.primaryAccent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.sm)
                                    .background(Color.primaryAccent.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                                    // Время
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("Время")
                                                .font(AppFont.tiny)
                                        }
                                        .foregroundColor(.textSecondary)

                                        Text("\(Int(totalTime)) мин")
                                            .font(AppFont.headline)
                                            .foregroundColor(.primaryAccent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.sm)
                                    .background(Color.primaryAccent.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                                }
                            }
                            .padding(Spacing.md)
                            .background(Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                            Divider()
                                .padding(.horizontal, Spacing.md)

                            // MARK: - Список сегментов маршрута
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                ForEach(routeSegments.indices, id: \.self) { idx in
                                    routeSegmentCard(routeSegments[idx], index: idx, steps: allRouteSteps.indices.contains(idx) ? allRouteSteps[idx] : [])
                                }
                            }
                            .padding(Spacing.md)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Назад")
                        }
                        .foregroundColor(.primaryAccent)
                    }
                }
            }
            // Initialize map on appear
            .onAppear {
                mapRegion = initialRegion
            }
        }
    }

    // MARK: - Route Segment Card

    @ViewBuilder
    private func routeSegmentCard(
        _ segment: DayScheduleView.RouteSegment,
        index: Int,
        steps: [MKRoute.Step]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Начальная точка
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: segment.fromActivity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(segment.fromActivity.title ?? "Активность")
                            .font(AppFont.headline)
                            .foregroundColor(.textPrimary)

                        if let cat = segment.fromActivity.categoryName, !cat.isEmpty {
                            Text(cat)
                                .font(AppFont.caption)
                                .foregroundColor(Color(hex: segment.fromActivity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                        }
                    }

                    Spacer()
                }

                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primaryAccent.opacity(0.2))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Text(segment.formattedDistance)
                            .font(AppFont.tiny)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Text(segment.formattedTime)
                            .font(AppFont.tiny)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(Color.primaryAccent)
                    )
                }
                .frame(height: 32)

                // Конечная точка
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: segment.toActivity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(segment.toActivity.title ?? "Активность")
                            .font(AppFont.headline)
                            .foregroundColor(.textPrimary)

                        if let cat = segment.toActivity.categoryName, !cat.isEmpty {
                            Text(cat)
                                .font(AppFont.caption)
                                .foregroundColor(Color(hex: segment.toActivity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                        }
                    }

                    Spacer()
                }
            }
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    // MARK: - Helpers

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let meters = distance
        if meters < 1000 {
            return "\(Int(meters))м"
        } else {
            let km = meters / 1000.0
            return String(format: "%.2f км", km)
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Дата не указана" }
        return date.formattedDate()
    }
}

// MARK: - Preview

#Preview {
    EmptyView()
}
