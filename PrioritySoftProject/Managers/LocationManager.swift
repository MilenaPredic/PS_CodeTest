//
//  LocationService.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//
import CoreLocation
import Combine

/// A type for checking location permissions
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isPermissionDenied: Bool = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    /// Checks whether the user granted permissions to access the location.
    func checkPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isPermissionDenied = true
        default:
            isPermissionDenied = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}
