//
//  MainViewModel.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//


import Foundation
import Combine
import UIKit
import AVFoundation
import CoreLocation

@MainActor
final class MainViewModel: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case uploading
        case success(UploadResult)
        case failure(APIError)
        case permanentFailure(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.uploading, .uploading):
                return true
            case (.success, .success), (.failure, .failure), (.permanentFailure, .permanentFailure):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Camera Properties

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    // MARK: - Upload & Location

    private let repository: MainRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleObserver: AppLifecycleObserver?
    private let locationManager = LocationManager.shared

    // MARK: - Published Properties

    @Published var isPermissionDenied: Bool = false
    @Published var state: State = .idle
    @Published var selectedImage: Data?
    @Published var capturedImageData: Data?
    @Published var isUploading = false
    @Published var currentIndex: Int = 0
    @Published var totalCount: Int = 0

    let candidateName: String = AppConstants.defaultCandidateName

    private var uploadQueue: [URL] = []
    private var activeBackgroundUploads = 0
    
        var uploadProgressText: String {
            "\(currentIndex)/\(totalCount) \(HomeViewStrings.images)"
        }

    // MARK: - Init

    init(repository: MainRepositoryProtocol = MainRepository()) {
        self.repository = repository
        super.init()

        configureSession()
        observePermissionChanges()

        self.lifecycleObserver = AppLifecycleObserver(
            onNetworkAvailable: { [weak self] in
                Task { await self?.processQueue() }
            },
            onAppBecameActive: { [weak self] in
                Task { await self?.processQueue() }
            }
        )

        NetworkService.shared.backgroundUploadDidFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                var tracker = UploadTracker.load()
                tracker.increment(uploaded: true)
                self.updateUploadCounts()
                if tracker.queued == tracker.uploaded {
                    self.finishUpload()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Permissions

    private func observePermissionChanges() {
        CameraManager.shared.$isPermissionDenied
            .combineLatest(locationManager.$isPermissionDenied)
            .map { $0 || $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPermissionDenied)
    }

    func checkPermissions() {
        CameraManager.shared.checkPermission()
        locationManager.checkPermission()
    }

    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else { return }
        UIApplication.shared.open(settingsUrl)
    }

    // MARK: - Camera Session

    private func configureSession() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.addOutput(output)
        session.sessionPreset = .photo
        session.commitConfiguration()
        session.startRunning()
    }

    func previewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Upload

    func uploadImage() async {
        guard isImageValid(selectedImage) else { return }
        guard let data = selectedImage else { return }

        if let fileURL = repository.saveImageToDisk(data) {
            uploadQueue.append(fileURL)

            var tracker = UploadTracker.load()
            tracker.increment(uploaded: false)
            self.updateUploadCounts()

            if NetworkMonitor.shared.isConnected {
                await processQueue()
            }
        }
    }

    private func isImageValid(_ data: Data?) -> Bool {
        guard let data = data else {
            state = .failure(.uploadFailed)
            return false
        }

        guard repository.isImageGeotagged(data) else {
            state = .permanentFailure(Errors.geotagError)
            return false
        }

        guard data.count <= AppConstants.maxImageSizeBytes else {
            state = .permanentFailure(Errors.sizeError)
            return false
        }

        return true
    }

    private func processQueue() async {
        guard !uploadQueue.isEmpty else { return }

        isUploading = true
        state = .uploading

        while !uploadQueue.isEmpty {
            let fileURL = uploadQueue.first!
            guard let data = try? Data(contentsOf: fileURL) else {
                uploadQueue.removeFirst()
                continue
            }

            currentIndex = totalCount - uploadQueue.count

            let success = await tryToUpload(data)

            if success {
                uploadQueue.removeFirst()
                repository.removeImageFromDisk(data)
            } else {
                state = .permanentFailure(Errors.uploadFailed)
                break
            }
        }

        if uploadQueue.isEmpty {
            finishUpload()
        }
    }

    private func tryToUpload(_ data: Data) async -> Bool {
        state = .uploading

        for attempt in 1...5 {
            do {
                if UIApplication.shared.applicationState == .background {
                    activeBackgroundUploads += 1
                    _ = try repository.uploadImageInBackground(data, candidateName: candidateName)
                    return false
                } else {
                    let result = try await repository.uploadImage(data, candidateName: candidateName)
                    state = .success(result)
                    return true
                }
            } catch {
                print("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
            }

            if attempt < 5 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        return false
    }

    private func updateUploadCounts() {
        let tracker = UploadTracker.load()
        self.currentIndex = tracker.uploaded
        self.totalCount = tracker.queued
    }

    private func finishUpload() {
        isUploading = false
        UploadTracker.clear()
        self.totalCount = 0
    }
}

extension MainViewModel: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        let location = locationManager.currentLocation
        let finalData = repository.embedLocationIfNeeded(to: data, location: location)
        self.capturedImageData = finalData
        self.selectedImage = finalData
    }
}
