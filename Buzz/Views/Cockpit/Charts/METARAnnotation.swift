//
//  METARAnnotation.swift
//  Buzz
//
//  MKAnnotation subclass for METAR station pins on VFR charts
//

import MapKit
import UIKit

// MARK: - METAR Station Annotation

class METARStationAnnotation: NSObject, MKAnnotation {
    let metar: METAR

    var coordinate: CLLocationCoordinate2D {
        metar.coordinate
    }

    var title: String? {
        metar.stationId
    }

    var subtitle: String? {
        metar.flightCategory.displayName
    }

    var flightCategory: FlightCategory {
        metar.flightCategory
    }

    init(metar: METAR) {
        self.metar = metar
        super.init()
    }

    // Include the displayed METAR payload so changed observations replace stale pins.
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(metar.stationId)
        hasher.combine(metar.rawText)
        hasher.combine(metar.flightCategory.rawValue)
        hasher.combine(metar.observationTime.timeIntervalSince1970)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? METARStationAnnotation else { return false }
        return metar.stationId == other.metar.stationId &&
            metar.rawText == other.metar.rawText &&
            metar.flightCategory == other.metar.flightCategory &&
            metar.observationTime == other.metar.observationTime
    }
}

// MARK: - Query Pin Annotation

class QueryPinAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { "Query Location" }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

// MARK: - Annotation View Helpers

enum METARAnnotationHelper {

    static func uiColor(for category: FlightCategory) -> UIColor {
        switch category {
        case .vfr: return .systemGreen
        case .mvfr: return .systemBlue
        case .ifr: return .systemRed
        case .lifr: return UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: 1.0) // Magenta
        case .unknown: return .systemGray
        }
    }

    static func createMETARAnnotationView(for annotation: METARStationAnnotation, in mapView: MKMapView) -> MKAnnotationView {
        let identifier = "METARStation"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

        view.annotation = annotation
        view.canShowCallout = false

        // Create colored circle image
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        view.image = renderer.image { ctx in
            let color = uiColor(for: annotation.flightCategory)
            color.setFill()
            UIColor.white.setStroke()
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            let path = UIBezierPath(ovalIn: rect)
            path.lineWidth = 2.0
            path.fill()
            path.stroke()
        }

        view.centerOffset = CGPoint(x: 0, y: 0)
        return view
    }

    static func createQueryPinView(for annotation: QueryPinAnnotation, in mapView: MKMapView) -> MKMarkerAnnotationView {
        let identifier = "QueryPin"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

        view.annotation = annotation
        view.markerTintColor = .systemOrange
        view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
        return view
    }
}
