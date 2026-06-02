import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - MapPlacePickerView

struct MapPlacePickerView: View {

    @Environment(\.dismiss) private var dismiss

    // Callback: (lat, lng, name, address)
    let onSelect: (Double, Double, String, String) -> Void
    let tripLocation: String?

    @StateObject private var vm: MapPlacePickerViewModel

    init(tripLocation: String? = nil, onSelect: @escaping (Double, Double, String, String) -> Void) {
        self.onSelect = onSelect
        self.tripLocation = tripLocation
        _vm = StateObject(wrappedValue: MapPlacePickerViewModel(tripLocation: tripLocation))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                VStack {
                    searchBar
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)

                    if !vm.searchResults.isEmpty {
                        searchResults
                            .padding(.horizontal, Spacing.md)
                    }

                    Spacer()
                }
                if let selected = vm.selectedItem {
                    VStack {
                        Spacer()
                        selectedPlaceCard(selected)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.xl)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(AppAnimation.quick, value: vm.selectedItem?.name)
            .navigationTitle("Выбери место")
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        GeometryReader { geometry in
            Map(coordinateRegion: $vm.region,
                annotationItems: vm.annotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(vm.selectedItem?.id == item.id
                                      ? Color.primaryAccent
                                      : Color.primaryAccent.opacity(0.7))
                                .frame(width: vm.selectedItem?.id == item.id ? 36 : 28,
                                       height: vm.selectedItem?.id == item.id ? 36 : 28)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: vm.selectedItem?.id == item.id ? 18 : 14))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(vm.selectedItem?.id == item.id ? 1.1 : 1.0)
                        .animation(AppAnimation.quick, value: vm.selectedItem?.id)
                        .onTapGesture { vm.select(item) }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .onTapGesture(coordinateSpace: .local) { location in
                vm.clearSearch()
                // Конвертируем tap в координаты карты и делаем reverse geocoding
                let coord = vm.mapCoordinate(for: location, in: geometry.size)
                vm.reverseGeocode(at: coord)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(vm.searchText.isEmpty ? Color(.systemGray3) : .primaryAccent)

            TextField("", text: $vm.searchText, prompt: Text("Поиск места или адреса")
                        .foregroundColor(Color(.systemGray3)))
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
                .tint(.primaryAccent)
                .submitLabel(.search)
                .onSubmit { vm.search() }

            if !vm.searchText.isEmpty {
                Button { vm.clearSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray3))
                }
            }
        }
        .padding(Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.searchResults, id: \.id) { result in
                    Button {
                        vm.select(result)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primaryAccent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(AppFont.body)
                                    .foregroundColor(.textPrimary)
                                Text(result.address)
                                    .font(AppFont.caption)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }

                    if result.id != vm.searchResults.last?.id {
                        Divider().padding(.leading, Spacing.xxl + Spacing.md)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .frame(maxHeight: 260)
    }

    // MARK: - Selected Place Card

    @ViewBuilder
    private func selectedPlaceCard(_ item: MapPlaceItem) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.primaryAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primaryAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)
                    Text(item.address)
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack {
                Spacer()
                SendArrowButton(size: 45) {
                    onSelect(item.coordinate.latitude, item.coordinate.longitude, item.name, item.address)
                    dismiss()
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
    }
}

// MARK: - ViewModel

@MainActor
final class MapPlacePickerViewModel: ObservableObject {

    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @Published var annotations: [MapPlaceItem] = []
    @Published var searchResults: [MapPlaceItem] = []
    @Published var selectedItem: MapPlaceItem? = nil
    @Published var searchText: String = ""

    init(tripLocation: String? = nil) {

        if let location = tripLocation, !location.trimmingCharacters(in: .whitespaces).isEmpty {
            searchLocationAndCenterMap(location)
        }
    }

    private func searchLocationAndCenterMap(_ locationName: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationName

        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )

        MKLocalSearch(request: request).start { [weak self] response, _ in
            guard let self, let response, let item = response.mapItems.first else { return }
            Task { @MainActor in
                let coordinate = item.placemark.coordinate
                self.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
                )
            }
        }
    }

    func search() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region

        MKLocalSearch(request: request).start { [weak self] response, _ in
            guard let self, let response else { return }
            Task { @MainActor in
                self.searchResults = response.mapItems.prefix(6).map { item in
                    MapPlaceItem(
                        id: UUID(),
                        name: item.name ?? "",
                        address: item.placemark.title ?? "",
                        coordinate: item.placemark.coordinate
                    )
                }
                if let first = self.searchResults.first {
                    withAnimation(AppAnimation.quick) {
                        self.region = MKCoordinateRegion(
                            center: first.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        self.annotations = self.searchResults
                    }
                }
            }
        }
    }

    func select(_ item: MapPlaceItem) {
        withAnimation(AppAnimation.quick) {
            selectedItem = item
            searchResults = []
            searchText = ""
            region = MKCoordinateRegion(
                center: item.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func clearSearch() {
        withAnimation(AppAnimation.quick) {
            searchText = ""
            searchResults = []
        }
    }

    // MARK: - Tap Map Coordinate

    func mapCoordinate(for point: CGPoint, in size: CGSize) -> CLLocationCoordinate2D {
        let normalizedX = point.x / size.width
        let normalizedY = point.y / size.height
        let lat = region.center.latitude  - (normalizedY - 0.5) * region.span.latitudeDelta
        let lng = region.center.longitude + (normalizedX - 0.5) * region.span.longitudeDelta
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // MARK: - Reverse Geocoding

    func reverseGeocode(at coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location  = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            Task { @MainActor in
                let name = placemark.name
                    ?? placemark.thoroughfare
                    ?? placemark.locality
                    ?? "Место"
                let addressParts = [placemark.thoroughfare, placemark.locality, placemark.country]
                    .compactMap { $0 }
                let address = addressParts.isEmpty ? name : addressParts.joined(separator: ", ")

                let item = MapPlaceItem(
                    id: UUID(),
                    name: name,
                    address: address,
                    coordinate: coordinate
                )
                withAnimation(AppAnimation.quick) {
                    self.searchText    = name
                    self.annotations   = [item]
                    self.selectedItem  = item
                    self.searchResults = []
                    self.region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
}

// MARK: - Model

struct MapPlaceItem: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

#Preview {
    MapPlacePickerView(tripLocation: "Spain") { lat, lng, name, address in
        print("Selected: \(name) at \(lat),\(lng)")
    }
}
