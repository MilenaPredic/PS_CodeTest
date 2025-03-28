//
//  Untitled.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//
import AVFoundation
import Combine

/// A type for checking camera permissions
final class CameraManager: ObservableObject {
    static let shared = CameraManager()
    
    @Published private(set) var isPermissionDenied: Bool = false

    private init() {
        checkPermission()
    }
    
    /// Checks whether the user granted permissions to access the camera.
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isPermissionDenied = !granted
                }
            }
        case .restricted, .denied:
            isPermissionDenied = true
        case .authorized:
            isPermissionDenied = false
        @unknown default:
            isPermissionDenied = true
        }
    }
}
