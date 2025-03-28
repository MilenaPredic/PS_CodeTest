//
//  HomeViewModel.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import Combine
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    
    enum State {
        case idle
        case uploading
        case success(UploadResult)
        case failure(APIError)
        case permanentFailure(String)
    }
    
    private let repository: HomeRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleObserver: AppLifecycleObserver?
    private let cameraManager = CameraManager.shared
    private let locationManager = LocationManager.shared
    
    @Published var isPermissionDenied: Bool = false
    @Published var state: State = .idle
    @Published var selectedImage: Data?
    @Published var isUploading = false
    @Published var currentIndex: Int = 0
    @Published var totalCount: Int = 0
    
    let candidateName: String = AppConstants.defaultCandidateName
    
    private var uploadQueue: [URL] = []
    private var activeBackgroundUploads = 0
    
    // MARK: - Helpers
    
    var uploadProgressText: String {
        "\(currentIndex)/\(totalCount) \(HomeViewStrings.images)"
    }
    
    // MARK: - Init
    
    init(repository: HomeRepositoryProtocol = HomeRepository()) {
        self.repository = repository
        
        observePermissionChanges()
        
        self.lifecycleObserver = AppLifecycleObserver(
            onNetworkAvailable: { [weak self] in
                Task { await self?.processQueue() }
            },
            onAppBecameActive: { [weak self] in
                Task { await self?.processQueue() }
            }
        )
        
        // Handle background upload result
        NetworkService.shared.backgroundUploadDidFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                
                var tracker = UploadTracker.load()
                tracker.increment(uploaded: true)
                
                self.updateUploadCounts()
                print("URL: \(result.downloadUrl)")
                if tracker.queued == tracker.uploaded {
                    self.finishUpload()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permissions
    
    private func observePermissionChanges() {
        cameraManager.$isPermissionDenied
            .combineLatest(locationManager.$isPermissionDenied)
            .map { $0 || $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPermissionDenied)
    }
    
    func checkPermissions() {
        cameraManager.checkPermission()
        locationManager.checkPermission()
    }
    
    // MARK: - App Settings
    
    /// Opens app settings screen.
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else { return }
        UIApplication.shared.open(settingsUrl)
    }
    
    // MARK: - Upload Image
    
    func uploadImage() async {
        guard isImageValid(selectedImage) else { return }
        guard let data = selectedImage else { return }
        
        if let fileURL = repository.saveImageToDisk(data) {
            // Add image to the queue and update the tracker
            uploadQueue.append(fileURL)
            
            var tracker = UploadTracker.load()
            tracker.increment(uploaded: false)
            self.updateUploadCounts()
            
            if NetworkMonitor.shared.isConnected {
                await processQueue()
            } else {
                print("Offline. Image saved to disk.")
            }
        }
    }
    
    /// Validates image for upload.
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
    
    // MARK: - Queue Processing
    
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
                if !uploadQueue.isEmpty {
                    uploadQueue.removeFirst()
                }
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
    
    /// Tries to upload image with retries.
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
                    print("URL: \(result.downloadUrl)")
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
    
    // MARK: - Helper Methods
    
    private func updateUploadCounts() {
        let tracker = UploadTracker.load()
        self.currentIndex = tracker.uploaded
        self.totalCount = tracker.queued
    }
    
    private func finishUpload() {
        isUploading = false
        UploadTracker.clear()
    }
}

// MARK: - State Equatable

extension HomeViewModel.State: Equatable {
    static func == (lhs: HomeViewModel.State, rhs: HomeViewModel.State) -> Bool {
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
