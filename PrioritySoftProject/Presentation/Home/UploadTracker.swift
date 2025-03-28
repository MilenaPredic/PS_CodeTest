//
//  UploadTracker.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 28.3.25..
//
import Foundation

struct UploadTracker: Codable {
    var queued: Int
    var uploaded: Int
    
    static let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fullPath = directory.appendingPathComponent("upload_tracker.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return fullPath
    }()
    
    static func load() -> UploadTracker {
        do {
            let data = try Data(contentsOf: fileURL)
            let tracker = try JSONDecoder().decode(UploadTracker.self, from: data)
            return tracker
        } catch {
            return UploadTracker(queued: 0, uploaded: 0)
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.fileURL)
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to save UploadTracker: \(error)")
        }
    }

    static func reset() {
        let tracker = UploadTracker(queued: 0, uploaded: 0)
        tracker.save()
    }

    mutating func increment(uploaded: Bool = false) {
        if uploaded {
            self.uploaded += 1
        } else {
            self.queued += 1
        }
        self.save()
    }

    var hasQueuedUploads: Bool {
        return queued > 0
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
