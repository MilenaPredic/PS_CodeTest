//
//  CameraRepository.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//

import Foundation
import CoreLocation
import ImageIO

/// Protocol for embedding location into image data.
protocol CameraRepositoryProtocol {
    func embedLocationIfNeeded(to data: Data, location: CLLocation?) -> Data
}

/// Adds GPS metadata to image if location is available.
final class CameraRepository: CameraRepositoryProtocol {

    /// Embeds GPS metadata into image if location is provided.
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

    /// Creates a GPS metadata dictionary from CLLocation.
    private func gpsDictionary(for location: CLLocation) -> [CFString: Any] {
        var gps = [CFString: Any]()
        gps[kCGImagePropertyGPSLatitude] = abs(location.coordinate.latitude)
        gps[kCGImagePropertyGPSLatitudeRef] = location.coordinate.latitude >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude] = abs(location.coordinate.longitude)
        gps[kCGImagePropertyGPSLongitudeRef] = location.coordinate.longitude >= 0 ? "E" : "W"
        gps[kCGImagePropertyGPSAltitude] = location.altitude
        gps[kCGImagePropertyGPSAltitudeRef] = location.altitude < 0 ? 1 : 0
        gps[kCGImagePropertyGPSTimeStamp] = DateFormatter.localizedString(from: location.timestamp,
                                                                          dateStyle: .none,
                                                                          timeStyle: .medium)
        gps[kCGImagePropertyGPSDateStamp] = DateFormatter.localizedString(from: location.timestamp,
                                                                          dateStyle: .short,
                                                                          timeStyle: .none)
        return gps
    }
}

