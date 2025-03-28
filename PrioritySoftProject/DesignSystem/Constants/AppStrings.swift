//
//  Constants.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//
import Foundation

enum HomeViewStrings {
    static let permissionTitle = "Allow permission"
    static let permissionDescription = "For moving forward, we need permission for Location, Camera and File System"
    static let uploading = "Uploading..."
    static let images = "images"
    static let allow = "Allow"
}

enum Errors {
    static let geotagError = "Image must be geotagged."
    static let sizeError = "Image must be under 5MB."
    static let uploadFailed = "Upload failed after 5 attempts. Will retry later."
}
