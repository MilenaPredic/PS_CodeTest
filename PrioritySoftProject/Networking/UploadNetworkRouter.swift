//
//  CameraRouter.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import Foundation

/// Defines a type that can provide a URLRequest.
protocol NetworkRoutable {
    var urlRequest: URLRequest { get throws }
    
    /// Gets value for a query item key from the request URL.
    func queryItemValue(for key: String) -> String
}

extension NetworkRoutable {
    func queryItemValue(for key: String) -> String {
        guard let url = try? self.urlRequest.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == key })?.value else {
            return ""
        }
        return value
    }
}

/// Upload router for creating specific upload requests.
enum UploadNetworkRouter: NetworkRoutable {
    case uploadFile(candidateName: String)

    /// Builds the URLRequest based on server definition.
    var urlRequest: URLRequest {
        get throws {
            guard let baseURL = URL(string: serverDefinition.baseUrl) else {
                throw APIError.invalidURL
            }

            var fullURL = baseURL.appendingPathComponent(serverDefinition.path)
            if let queryParameters = serverDefinition.queryParameters {
                var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: false)!
                components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                if let updatedURL = components.url {
                    fullURL = updatedURL
                }
            }

            var request = URLRequest(url: fullURL)
            request.httpMethod = serverDefinition.method.rawValue

            serverDefinition.headers?.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }

            return request
        }
    }

    /// Returns the appropriate server definition for the route.
    private var serverDefinition: ServerDefinition {
        switch self {
        case .uploadFile(let candidateName):
            return BaseServerDefinition.fileUpload(candidateName: candidateName)
        }
    }
}

// MARK: - Server Definition

/// Describes request details like path, method, headers, etc.
protocol ServerDefinition {
    var baseUrl: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: Any]? { get }
}

/// Concrete definitions for specific endpoints.
enum BaseServerDefinition {
    case fileUpload(candidateName: String)
}

extension BaseServerDefinition: ServerDefinition {
    var baseUrl: String {
        switch self {
        case .fileUpload:
            return ProcessInfo.processInfo.environment["API_URL"]!
        }
    }

    var path: String {
        switch self {
        case .fileUpload:
            return "/upload"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fileUpload:
            return .post
        }
    }

    var headers: [String: String]? {
        switch self {
        case .fileUpload:
            return nil
        }
    }

    var queryParameters: [String: Any]? {
        switch self {
        case .fileUpload(let candidateName):
            return ["candidateName": candidateName]
        }
    }
}

/// Supported HTTP methods.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
