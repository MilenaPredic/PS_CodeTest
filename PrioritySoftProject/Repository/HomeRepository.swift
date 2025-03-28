//
//  HomeClient.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import UIKit
import ImageIO
import CoreLocation

/// Protocol defining repository methods for image upload and storage.
protocol HomeRepositoryProtocol {
    func isImageGeotagged(_ data: Data) -> Bool
    func saveImageToDisk(_ data: Data) -> URL?
    func loadCachedImageURLs() -> [URL]
    func removeImageFromDisk(_ dataToCompare: Data)
    func uploadImage(_ image: Data, candidateName: String) async throws -> UploadResult
    func uploadImageInBackground(_ image: Data, candidateName: String) throws -> UploadResult
}

/// Handles image uploads and caching.
final class HomeRepository: HomeRepositoryProtocol {

    // MARK: - Properties

    /// Directory used for caching images.
    private let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("UploadQueue")

    private let networkService: NetworkServiceProtocol
    private let fileManager: FileManager

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol = NetworkService.shared,
         fileManager: FileManager = .default) {
        self.networkService = networkService
        self.fileManager = fileManager
    }

    // MARK: - Upload Methods

    /// Uploads image in foreground using network service.
    func uploadImage(_ image: Data, candidateName: String) async throws -> UploadResult {
        try await networkService.uploadInForeground(
            router: UploadNetworkRouter.uploadFile(candidateName: candidateName),
            data: image,
            candidateName: candidateName
        )
    }

    /// Enqueues image for background upload.
    func uploadImageInBackground(_ image: Data, candidateName: String) throws -> UploadResult {
        try networkService.uploadInBackground(
            router: UploadNetworkRouter.uploadFile(candidateName: candidateName),
            data: image,
            candidateName: candidateName
        )

        // Dummy result since actual upload happens in background
        return UploadResult(downloadUrl: "")
    }

    // MARK: - Geotag & Persistence

    /// Checks if image contains GPS metadata.
    func isImageGeotagged(_ data: Data) -> Bool {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return false
        }
        return !gps.isEmpty
    }

    /// Saves image data to disk and returns its file URL.
    func saveImageToDisk(_ data: Data) -> URL? {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Loads all cached image file URLs from disk.
    func loadCachedImageURLs() -> [URL] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return fileURLs.filter { $0.pathExtension == "jpg" }
    }

    /// Removes image from disk that matches the given data.
    func removeImageFromDisk(_ dataToCompare: Data) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }

        for url in fileURLs where url.pathExtension == "jpg" {
            if let data = try? Data(contentsOf: url), data == dataToCompare {
                try? fileManager.removeItem(at: url)
                break
            }
        }
    }
}
