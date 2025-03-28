//
//  CameraViewModel.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//

import AVFoundation
import CoreLocation
import Combine
import SwiftUI

/// ViewModel responsible for managing camera session and capturing photos.
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Captured image data (with optional location metadata).
    @Published var capturedImageData: Data?

    // MARK: - Private Properties

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let cameraRepository: CameraRepositoryProtocol = CameraRepository()
    private let locationProvider = LocationManager.shared

    // MARK: - Public Properties

    /// Called after image capture is finished to dismiss the camera view.
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        configureSession()
    }

    // MARK: - Session Configuration

    /// Sets up camera session and starts running it on a background queue.
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input),
                  self.session.canAddOutput(self.output) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            self.session.addOutput(self.output)
            self.session.sessionPreset = .photo
            self.session.commitConfiguration()

            self.session.startRunning()
        }
    }

    // MARK: - Capture Photo

    /// Captures a photo using current session settings.
    @objc func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Preview Layer

    /// Returns a configured preview layer for displaying the camera view.
    func previewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {

    /// Called when photo capture finishes.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }

        let location = locationProvider.currentLocation
        let finalData = cameraRepository.embedLocationIfNeeded(to: data, location: location)

        DispatchQueue.main.async {
            self.capturedImageData = finalData
            self.onDismiss?()
        }
    }
}
