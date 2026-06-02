import SwiftUI
import MapKit
import CoreData

struct MapWithRoute: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let activities: [Activity]
    let polylines: [MKPolyline]
    let showRoute: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Обновляем регион
        mapView.setRegion(region, animated: true)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.removeOverlays(mapView.overlays)
        for activity in activities {
            let annotation = ActivityAnnotation(activity: activity)
            mapView.addAnnotation(annotation)
        }

        if showRoute {
            for polyline in polylines {
                mapView.addOverlay(polyline)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? ActivityAnnotation else { return nil }

            let identifier = "ActivityAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor(named: "PrimaryAccentColor") ?? .systemBlue
                markerView.glyphText = ""
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(named: "PrimaryAccentColor")
                renderer.lineWidth = 3.0
                renderer.alpha = 0.8
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Annotation Model
class ActivityAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let activity: Activity

    init(activity: Activity) {
        self.activity = activity
        self.coordinate = CLLocationCoordinate2D(latitude: activity.latitude, longitude: activity.longitude)
        self.title = activity.title
        self.subtitle = activity.categoryName
    }
}
