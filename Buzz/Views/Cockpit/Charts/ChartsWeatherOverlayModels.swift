//
//  ChartsWeatherOverlayModels.swift
//  Buzz
//
//  Created for chart weather annotations and overlay containers.
//

import MapKit
import ObjectiveC
import UIKit

// MARK: - PIREP Annotation

final class PIREPAnnotation: NSObject, MKAnnotation {
    let pirep: PIREP

    var coordinate: CLLocationCoordinate2D {
        pirep.coordinate
    }

    var title: String? {
        pirep.dominantHazard.displayName
    }

    var subtitle: String? {
        pirep.hazardSummary
    }

    init(pirep: PIREP) {
        self.pirep = pirep
        super.init()
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(pirep.id)
        hasher.combine(pirep.rawText)
        hasher.combine(pirep.observationTime.timeIntervalSince1970)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PIREPAnnotation else { return false }
        return pirep.id == other.pirep.id &&
            pirep.rawText == other.pirep.rawText &&
            pirep.observationTime == other.pirep.observationTime
    }
}

// MARK: - Associated Object Keys

private var gairmetAdvisoryKey: UInt8 = 0
private var sigmetAdvisoryKey: UInt8 = 0
private var overlayIDKey: UInt8 = 0

// MARK: - Weather Overlay Tagging

extension MKPolygon {
    var weatherOverlayID: String? {
        get { objc_getAssociatedObject(self, &overlayIDKey) as? String }
        set { objc_setAssociatedObject(self, &overlayIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var gairmetAdvisory: GAIRMETAdvisory? {
        get { objc_getAssociatedObject(self, &gairmetAdvisoryKey) as? GAIRMETAdvisory }
        set { objc_setAssociatedObject(self, &gairmetAdvisoryKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var sigmetAdvisory: SIGMETAdvisory? {
        get { objc_getAssociatedObject(self, &sigmetAdvisoryKey) as? SIGMETAdvisory }
        set { objc_setAssociatedObject(self, &sigmetAdvisoryKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension MKPolyline {
    var weatherOverlayID: String? {
        get { objc_getAssociatedObject(self, &overlayIDKey) as? String }
        set { objc_setAssociatedObject(self, &overlayIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var gairmetAdvisory: GAIRMETAdvisory? {
        get { objc_getAssociatedObject(self, &gairmetAdvisoryKey) as? GAIRMETAdvisory }
        set { objc_setAssociatedObject(self, &gairmetAdvisoryKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - Overlay Factories

enum GAIRMETOverlayFactory {
    static func makePolygon(for advisory: GAIRMETAdvisory) -> MKPolygon? {
        guard advisory.coordinates.count >= 3 else { return nil }
        var coords = advisory.coordinates
        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
        polygon.weatherOverlayID = advisory.id
        polygon.gairmetAdvisory = advisory
        return polygon
    }

    static func makePolyline(for advisory: GAIRMETAdvisory) -> MKPolyline? {
        guard advisory.coordinates.count >= 2 else { return nil }
        var coords = advisory.coordinates
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)
        polyline.weatherOverlayID = advisory.id
        polyline.gairmetAdvisory = advisory
        return polyline
    }
}

enum SIGMETOverlayFactory {
    static func makePolygon(for advisory: SIGMETAdvisory) -> MKPolygon? {
        guard advisory.coordinates.count >= 3 else { return nil }
        var coords = advisory.coordinates
        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
        polygon.weatherOverlayID = advisory.id
        polygon.sigmetAdvisory = advisory
        return polygon
    }
}

// MARK: - Annotation View Helper

enum ChartsWeatherOverlayHelper {
    static func createPIREPAnnotationView(
        for annotation: PIREPAnnotation,
        in mapView: MKMapView
    ) -> MKMarkerAnnotationView {
        let identifier = "PIREPReport"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

        view.annotation = annotation
        view.canShowCallout = false
        view.displayPriority = .defaultHigh
        view.markerTintColor = pirepTintColor(for: annotation.pirep.dominantHazard)
        view.glyphImage = UIImage(systemName: annotation.pirep.dominantHazard.systemImage)
        return view
    }

    static func pirepTintColor(for hazard: PIREPHazard) -> UIColor {
        switch hazard {
        case .turbulence:
            return .systemOrange
        case .icing:
            return .systemTeal
        case .weather:
            return .systemIndigo
        case .general:
            return .systemGray
        }
    }
}
