import Foundation
import MapKit

// MARK: - Transport Type

enum TransportType: String, CaseIterable, Codable {
    case walking = "Пешком"
    case driving = "Машина"
    case transit = "Общественный"

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .walking:
            return .walking
        case .driving:
            return .automobile
        case .transit:
            return .transit
        }
    }

    var icon: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .driving:
            return "car.fill"
        case .transit:
            return "bus.fill"
        }
    }
}

// MARK: - Route Result

struct RouteResult {
    let distance: Double  // в км
    let estimatedTime: Double  // в минутах
    let polyline: MKPolyline
    let steps: [MKRoute.Step]  // Пошаговые инструкции

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
}

// MARK: - Route Service

@MainActor
final class RouteService: NSObject {
    static let shared = RouteService()

    func getRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transportType: TransportType = .walking
    ) async -> RouteResult? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transportType.mkTransportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else {
                return nil
            }

            let distance = route.distance / 1000.0  // метры в км
            let estimatedTime = route.expectedTravelTime / 60.0  // секунды в минуты
            let polyline = route.polyline
            let steps = route.steps

            return RouteResult(
                distance: distance,
                estimatedTime: estimatedTime,
                polyline: polyline,
                steps: steps
            )

        } catch {
            return nil
        }
    }

    func getAllRoutes(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> [TransportType: RouteResult] {
        var results: [TransportType: RouteResult] = [:]

        for transportType in TransportType.allCases {
            if let route = await getRoute(from: from, to: to, transportType: transportType) {
                results[transportType] = route
            }
        }

        return results
    }

    func getFallbackRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> RouteResult {
        let polyline = MKPolyline(coordinates: [from, to], count: 2)

        // Оцениваем расстояние через Haversine
        let distance = calculateDistance(from: from, to: to)

        // Оцениваем время для пешехода (1.4 км/ч)
        let estimatedMinutes = (distance / 1.4) * 60

        return RouteResult(
            distance: distance,
            estimatedTime: estimatedMinutes,
            polyline: polyline,
            steps: []
        )
    }

    // MARK: - Helpers

    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6371.0  // Радиус Земли в км

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLng = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distance = earthRadius * c

        return distance
    }
}
