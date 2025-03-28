//
//  NetworkingService.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import Foundation
import UIKit
import Combine

/// Protocol defining upload methods.
protocol NetworkServiceProtocol {
    func uploadInForeground(router: NetworkRoutable,
                            data: Data,
                            candidateName: String) async throws -> UploadResult

    func uploadInBackground(router: NetworkRoutable,
                            data: Data,
                            candidateName: String) throws
}

/// Networking service for foreground and background uploads.
final class NetworkService: NSObject, NetworkServiceProtocol, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    // MARK: - Properties

    static let shared = NetworkService()

    /// Publisher used to notify when background upload finishes.
    let backgroundUploadDidFinish = PassthroughSubject<UploadResult, Never>()
    private var pendingUploadData: Data?
    
    // MARK: Initialization
    
    private override init() { super.init() }

    // MARK: - Background Session

    /// Configured URLSession for background uploads.
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.prioritysoft.upload.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config,
                          delegate: self,
                          delegateQueue: nil)
    }()

    // MARK: - Foreground Upload (async/await)

    /// Uploads file in foreground using async/await.
    func uploadInForeground(router: NetworkRoutable,
                            data: Data,
                            candidateName: String) async throws -> UploadResult {
        let (boundary, multipartURL) = try data.prepareMultipartFile(candidateName: candidateName)

        var request = try router.urlRequest
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await URLSession.shared.upload(for: request,
                                                                          fromFile: multipartURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(UploadResult.self, from: responseData)
        } catch {
            throw APIError.decodingError
        }
    }

    // MARK: - Background Upload (delegate-based)

    /// Starts file upload in background using delegate-based URLSession.
    func uploadInBackground(router: NetworkRoutable,
                            data: Data,
                            candidateName: String) throws {
        let (boundary, multipartURL) = try data.prepareMultipartFile(candidateName: candidateName)

        var request = try router.urlRequest
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let task = backgroundSession.uploadTask(with: request, fromFile: multipartURL)
        task.resume()
    }

    // MARK: - Delegate Methods

    /// Called when background upload task receives data.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            let result = try JSONDecoder().decode(UploadResult.self, from: data)
            pendingUploadData = data
            backgroundUploadDidFinish.send(result)
        } catch {
            print("⚠️ Failed to decode UploadResult in background: \(error)")
        }
    }
}

extension Data {
    /// Appends a string to Data using UTF-8 encoding.
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }

    /// Prepares multipart/form-data file for upload.
    func prepareMultipartFile(candidateName: String) throws -> (boundary: String, fileURL: URL) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"candidateName\"\r\n\r\n")
        body.append("\(candidateName)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(self)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(boundary).tmp")
        try body.write(to: fileURL)

        return (boundary, fileURL)
    }
}
