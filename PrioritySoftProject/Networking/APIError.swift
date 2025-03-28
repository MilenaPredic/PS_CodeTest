//
//  APIError.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//
import Foundation

/// Defines possible API-related errors.
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingError
    case uploadFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return  "Invalid url"
        case .invalidResponse: return "Invalid response from server"
        case .statusCode(let code): return "Server returned status code \(code)"
        case .decodingError: return "Failed to decode response"
        case .uploadFailed: return "File upload failed"
        case .unknown(let error): return "Unknown error: \(error.localizedDescription)"
        }
    }
}
