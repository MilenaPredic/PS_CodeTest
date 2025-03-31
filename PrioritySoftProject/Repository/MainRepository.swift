//
//  HomeClient.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import Foundation
import UIKit
import CoreLocation
import ImageIO

/// Protocol defining repository methods for image upload, metadata, and storage.
protocol MainRepositoryProtocol {
    func isImageGeotagged(_ data: Data) -> Bool
    func embedLocationIfNeeded(to data: Data, location: CLLocation?) -> Data
    func saveImageToDisk(_ data: Data) -> URL?
    func loadCachedImageURLs() -> [URL]
    func removeImageFromDisk(_ dataToCompare: Data)
    func uploadImage(_ image: Data, candidateName: String) async throws -> UploadResult
    func uploadImageInBackground(_ image: Data, candidateName: String) throws -> UploadResult
}

/// Handles image uploads, GPS embedding, and local file persistence.
final class MainRepository: MainRepositoryProtocol {

    // MARK: - Properties

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

    func uploadImage(_ image: Data, candidateName: String) async throws -> UploadResult {
        try await networkService.uploadInForeground(
            router: UploadNetworkRouter.uploadFile(candidateName: candidateName),
            data: image,
            candidateName: candidateName
        )
    }

    func uploadImageInBackground(_ image: Data, candidateName: String) throws -> UploadResult {
        try networkService.uploadInBackground(
            router: UploadNetworkRouter.uploadFile(candidateName: candidateName),
            data: image,
            candidateName: candidateName
        )
        return UploadResult(downloadUrl: "") // Dummy, real result comes later
    }

    // MARK: - GPS Metadata

    func isImageGeotagged(_ data: Data) -> Bool {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return false
        }
        return !gps.isEmpty
    }

    func embedLocationIfNeeded(to data: Data, location: CLLocation?) -> Data {
        guard let location = location,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(destinationData, uti, 1, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return data
        }

        var mutableMetadata = metadata
        mutableMetadata[kCGImagePropertyGPSDictionary] = gpsDictionary(for: location)

        CGImageDestinationAddImageFromSource(destination, source, 0, mutableMetadata as CFDictionary)
        CGImageDestinationFinalize(destination)

        return destinationData as Data? ?? data
    }

    private func gpsDictionary(for location: CLLocation) -> [CFString: Any] {
        var gps = [CFString: Any]()
        gps[kCGImagePropertyGPSLatitude] = abs(location.coordinate.latitude)
        gps[kCGImagePropertyGPSLatitudeRef] = location.coordinate.latitude >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude] = abs(location.coordinate.longitude)
        gps[kCGImagePropertyGPSLongitudeRef] = location.coordinate.longitude >= 0 ? "E" : "W"
        gps[kCGImagePropertyGPSAltitude] = location.altitude
        gps[kCGImagePropertyGPSAltitudeRef] = location.altitude < 0 ? 1 : 0
        gps[kCGImagePropertyGPSTimeStamp] = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .medium)
        gps[kCGImagePropertyGPSDateStamp] = DateFormatter.localizedString(from: location.timestamp, dateStyle: .short, timeStyle: .none)
        return gps
    }

    // MARK: - Persistence

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

    func loadCachedImageURLs() -> [URL] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return fileURLs.filter { $0.pathExtension == "jpg" }
    }

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
