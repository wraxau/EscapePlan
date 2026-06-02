import SwiftUI
import MapKit
import CoreData

struct DayScheduleView: View {

    let trip: Trip
    @ObservedObject var dayPlanVM: DayPlanViewModel
    let context: NSManagedObjectContext

    @State private var selectedDayIndex: Int = 0
    @State private var showCreateActivity = false
    @State private var activityVM: ActivityViewModel? = nil
    @State private var selectedActivityToEdit: Activity? = nil
    @State private var showFullRouteSheet = false
    @State private var selectedTransportType: TransportType = .walking
    @State private var isLoadingRoute = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0, longitude: 28.97),
        span:   MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @State private var tripPlaces: [Place] = []
    @State private var routePolylines: [MKPolyline] = []  // Несколько линий между точками
    @State private var routeSegments: [RouteSegment] = []  // Информация о каждом сегменте
    @State private var routeSteps: [[MKRoute.Step]] = []
    @State private var showRoute = false

    // MARK: - Route Segment Model
    struct RouteSegment {
        let fromActivity: Activity
        let toActivity: Activity
        let distance: Double  // в км
        let estimatedTime: Double  // в минутах

        var formattedDistance: String {
            String(format: "%.1f км", distance)
        }

        var formattedTime: String {
            let mins = Int(estimatedTime)
            if mins < 60 {
                return "\(mins) мин"
            } else {
                let hours = mins / 60
                let remainingMins = mins % 60
                return "\(hours)ч \(remainingMins)м"
            }
        }

        var summary: String {
            "\(formattedDistance), \(formattedTime)"
        }
    }

    private var sortedDays: [DayPlan] {
        dayPlanVM.dayPlans.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var selectedDay: DayPlan? {
        guard selectedDayIndex < sortedDays.count else { return nil }
        return sortedDays[selectedDayIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if !sortedDays.isEmpty {
                dayTabsScroll
            }
            if let day = selectedDay {
                dayContent(day)
            } else {
                emptyPlaceholder
            }
        }
        .onChange(of: selectedDayIndex) { _ in
            refreshActivityVM()
            resetRouteState()
        }
        .onAppear {
            refreshActivityVM()
            loadTripPlaces()

            Task {
                for day in dayPlanVM.dayPlans {
                    await SyncService.shared.fetchActivities(for: day, trip: trip, context: context)
                }
                // Обновляем UI после синхронизации
                DispatchQueue.main.async {
                    activityVM?.fetch()
                }
            }
        }
        .sheet(isPresented: $showCreateActivity, onDismiss: { activityVM?.fetch() }) {
            if let vm = activityVM, let day = selectedDay {
                ActivityFormView(vm: vm, mode: .create(dayDate: day.date ?? Date()), tripName: trip.name)
                    .presentationDetents([.large])
            }
        }

        .sheet(item: $selectedActivityToEdit, onDismiss: { activityVM?.fetch() }) { activity in
            if let vm = activityVM {
                ActivityFormView(vm: vm, mode: .edit(activity: activity), tripName: trip.name)
                    .presentationDetents([.large])
            }
        }

        .sheet(isPresented: $showFullRouteSheet) {
            if let day = selectedDay {
                FullRouteDetailView(
                    trip: trip,
                    day: day,
                    activities: activitiesWithCoords,
                    routeSegments: routeSegments,
                    routePolylines: routePolylines,
                    transportType: selectedTransportType,
                    allRouteSteps: routeSteps
                )
            }
        }
    }

    // MARK: - Day Tabs

    private var dayTabsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(sortedDays.indices, id: \.self) { i in
                    let dayNumber = dayPlanVM.dayNumber(for: sortedDays[i])
                    FilterChip(label: "День \(dayNumber)", isSelected: selectedDayIndex == i) {
                        withAnimation(AppAnimation.quick) { selectedDayIndex = i }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color.appBackground)
    }

    // MARK: - Day Content

    @ViewBuilder
    private func dayContent(_ day: DayPlan) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Большая дата
                    dateHeader(day)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)

                    // Таймлайн активностей
                    if let vm = activityVM {
                        activitiesTimeline(vm: vm)
                    }

                    // Мини-карта
                    miniMapSection
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABButton(icon: "plus") {
                        showCreateActivity = true
                    }
                    .padding(.trailing, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
        }
    }

    // MARK: - Date Header

    private func dateHeader(_ day: DayPlan) -> some View {
        let formatted = formattedDate(day.date)
        return Text(formatted)
            .font(AppFont.title)
            .foregroundColor(.primaryAccent)
    }

    // MARK: - Activities Timeline

    @ViewBuilder
    private func activitiesTimeline(vm: ActivityViewModel) -> some View {
        if vm.activities.isEmpty {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "Нет активностей",
                subtitle: "Нажми + чтобы добавить событие"
            )
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(vm.activities, id: \.id) { act in
                    activityRow(act, vm: vm)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func activityRow(_ act: Activity, vm: ActivityViewModel) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {

            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.formattedTime(act.startTime))
                    .font(AppFont.caption.weight(.semibold))
                    .foregroundColor(.textPrimary)
                Text(vm.formattedTime(act.endTime))
                    .font(AppFont.tiny)
                    .foregroundColor(.textSecondary)
            }
            .frame(width: 52)
            
            VStack(spacing: 0) {
                vm.color(for: act)
                    .frame(width: 12, height: 12)
                    .clipShape(Circle())
                    .padding(.top, 3)
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(act.title ?? "")
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)

                if let cat = act.categoryName, !cat.isEmpty {
                    Text(cat)
                        .font(AppFont.caption)
                        .foregroundColor(vm.color(for: act))
                }

                if let note = act.note, !note.isEmpty {
                    Text(note)
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
        }
        .padding(.vertical, Spacing.xs)
        .onTapGesture {
            selectedActivityToEdit = act
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                vm.deleteActivity(act)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    // MARK: - Mini Map

    private var miniMapSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Карта мест")
                        .font(AppFont.headline)
                        .foregroundColor(.primaryAccent)

                    Spacer()

                    if activitiesWithCoords.count >= 2 {
                        // Open full route map
                        Button {
                            showFullRouteSheet = true
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primaryAccent)
                        }
                        .padding(.trailing, Spacing.sm)

                        Button {
                            withAnimation(AppAnimation.quick) { showRoute.toggle() }
                            if showRoute { buildRoute() }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: showRoute ? "map.fill" : "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(showRoute ? "Скрыть маршрут" : "Маршрут")
                                    .font(AppFont.caption)
                            }
                            .foregroundColor(.primaryAccent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.primaryAccent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }

                if showRoute && activitiesWithCoords.count >= 2 {
                    HStack(spacing: Spacing.sm) {
                        ForEach(TransportType.allCases, id: \.self) { type in
                            Button {
                                selectedTransportType = type
                                buildRoute()
                            } label: {
                                VStack(spacing: Spacing.xs) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(type.rawValue)
                                        .font(AppFont.tiny)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.sm)
                                .foregroundColor(selectedTransportType == type ? .white : .primaryAccent)
                                .background(selectedTransportType == type ? Color.primaryAccent : Color.primaryAccent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .disabled(isLoadingRoute)
                        }
                    }
                }
            }

            if activitiesWithCoords.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 28))
                            .foregroundColor(.primaryAccent.opacity(0.3))
                        Text("Добавь места с координатами")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.vertical, Spacing.lg)
                    Spacer()
                }
                .background(Color.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            } else {
                MapWithRoute(
                    region: $mapRegion,
                    activities: activitiesWithCoords,
                    polylines: routePolylines,
                    showRoute: showRoute
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                .onAppear { centerMapOnActivities() }
                .onChange(of: activitiesWithCoords.count) { _ in centerMapOnActivities() }
            }

            if !activitiesWithCoords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(activitiesWithCoords, id: \.id) { activity in
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(hex: activity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                                Text(activity.title ?? "Активность")
                                    .font(AppFont.tiny)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.primaryAccent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.primaryAccent.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }

            if showRoute {
                if isLoadingRoute {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                            .tint(.primaryAccent)

                        Text("Загрузка маршрута...")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(Color.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                } else if !routeSegments.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Маршрут")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        Spacer()
                        let totalDistance = routeSegments.reduce(0) { $0 + $1.distance }
                        let totalTime = routeSegments.reduce(0) { $0 + $1.estimatedTime }

                        HStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 12))
                                Text(String(format: "%.1f км", totalDistance))
                                    .font(AppFont.tiny)
                                    .fontWeight(.semibold)
                            }

                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                Text("\(Int(totalTime)) мин")
                                    .font(AppFont.tiny)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.primaryAccent)
                    }
                    .padding(.bottom, Spacing.xs)

                    Divider()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(routeSegments.indices, id: \.self) { idx in
                                let segment = routeSegments[idx]

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    HStack(spacing: Spacing.sm) {
                                        // Номер этапа
                                        Circle()
                                            .fill(Color(hex: segment.fromActivity.categoryColor ?? "#FF4B8B") ?? .primaryAccent)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Text("\(idx + 1)")
                                                    .font(AppFont.caption.weight(.semibold))
                                                    .foregroundColor(.white)
                                            )

                                        // Информация о сегменте
                                        VStack(alignment: .leading, spacing: Spacing.xs) {
                                            Text(segment.fromActivity.title ?? "Активность")
                                                .font(AppFont.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.textPrimary)
                                                .lineLimit(1)

                                            HStack(spacing: Spacing.xs) {
                                                Image(systemName: "arrow.right")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.textSecondary)
                                                Text(segment.toActivity.title ?? "Активность")
                                                    .font(AppFont.tiny)
                                                    .foregroundColor(.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        // Расстояние и время
                                        VStack(alignment: .trailing, spacing: 2) {
                                            HStack(spacing: Spacing.xs) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 10))
                                                Text(segment.formattedDistance)
                                                    .font(AppFont.tiny)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.primaryAccent)

                                            HStack(spacing: Spacing.xs) {
                                                Image(systemName: "clock.fill")
                                                    .font(.system(size: 10))
                                                Text(segment.formattedTime)
                                                    .font(AppFont.tiny)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.primaryAccent)
                                        }
                                    }
                                    .padding(Spacing.sm)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                                    if idx < routeSegments.count - 1 {
                                        HStack(spacing: Spacing.sm) {
                                            Spacer()
                                                .frame(width: 14)
                                            VStack(spacing: 2) {
                                                ForEach(0..<3, id: \.self) { _ in
                                                    Circle()
                                                        .fill(Color.primaryAccent.opacity(0.2))
                                                        .frame(width: 2, height: 2)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(height: 12)
                                    }
                                }
                            }
                        }
                    }

                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 100)
                    }
                    .frame(maxHeight: 250)
                }
                    .padding(Spacing.md)
                    .background(Color.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                } else {
                    // Нет сегментов или ошибка загрузки
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.primaryAccent.opacity(0.5))

                        Text("Не удалось загрузить маршрут")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        Text("Проверьте, что у всех активностей есть координаты")
                            .font(AppFont.tiny)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(Color.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
            }
        }
    }

    private var activitiesWithCoords: [Activity] {
        (activityVM?.activities ?? []).filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    private var placesWithCoords: [Place] {
        tripPlaces.filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    private func placeIcon(_ type: String) -> String {
        switch type {
        case "hotel":      return "bed.double.fill"
        case "restaurant": return "fork.knife"
        case "museum":     return "building.columns.fill"
        case "park":       return "leaf.fill"
        default:           return "star.fill"
        }
    }

    private func centerMapOnActivities() {
        let coords = activitiesWithCoords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard !coords.isEmpty else { return }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)

        // Безопасно получаем min/max значения
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLng = lngs.min(),
              let maxLng = lngs.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            mapRegion = MKCoordinateRegion(center: center, span: span)
        }
    }

    // Build route using RouteService
    private func buildRoute() {
        Task {
            await buildRouteAsync()
        }
    }

    private func buildRouteAsync() async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        let activities = activityVM?.activities ?? []
        guard activities.count >= 2 else { return }

        var polylines: [MKPolyline] = []
        var segments: [RouteSegment] = []
        var steps: [[MKRoute.Step]] = []

        // Для каждой пары соседних активностей
        for i in 0..<(activities.count - 1) {
            let fromActivity = activities[i]
            let toActivity = activities[i + 1]

            // Проверяем что есть координаты
            guard (fromActivity.latitude != 0 || fromActivity.longitude != 0),
                  (toActivity.latitude != 0 || toActivity.longitude != 0) else {
                continue
            }

            // Координаты
            let fromCoord = CLLocationCoordinate2D(
                latitude: fromActivity.latitude, longitude: fromActivity.longitude)
            let toCoord = CLLocationCoordinate2D(
                latitude: toActivity.latitude, longitude: toActivity.longitude)

            if let routeResult = await RouteService.shared.getRoute(
                from: fromCoord,
                to: toCoord,
                transportType: selectedTransportType
            ) {
                polylines.append(routeResult.polyline)

                let segment = RouteSegment(
                    fromActivity: fromActivity,
                    toActivity: toActivity,
                    distance: routeResult.distance,
                    estimatedTime: routeResult.estimatedTime
                )
                segments.append(segment)
                steps.append(routeResult.steps)

            } else {

                let fallbackRoute = RouteService.shared.getFallbackRoute(
                    from: fromCoord,
                    to: toCoord
                )
                polylines.append(fallbackRoute.polyline)

                let fallbackSegment = RouteSegment(
                    fromActivity: fromActivity,
                    toActivity: toActivity,
                    distance: fallbackRoute.distance,
                    estimatedTime: fallbackRoute.estimatedTime
                )
                segments.append(fallbackSegment)
                steps.append([])
            }
        }

        self.routePolylines = polylines
        self.routeSegments = segments
        self.routeSteps = steps
    }


    private func loadTripPlaces() {
        let req: NSFetchRequest<Place> = Place.fetchRequest()
        req.predicate = NSPredicate(format: "trip == %@", trip)
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        tripPlaces = (try? context.fetch(req)) ?? []
    }

    // MARK: - Empty Placeholder

    private var emptyPlaceholder: some View {
        EmptyStateView(
            icon: "calendar",
            title: "Выбери день",
            subtitle: "Добавь дни через вкладку «Дни» в деталях поездки"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func refreshActivityVM() {
        guard let day = selectedDay else { activityVM = nil; return }
        activityVM = ActivityViewModel(dayPlan: day, context: context)
    }

    private func resetRouteState() {
        showRoute = false
        routePolylines = []
        routeSegments = []
        routeSteps = []
        isLoadingRoute = false
        selectedTransportType = .walking
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Дата не указана" }
        return date.formattedDate()
    }
}
