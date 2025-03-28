//
//  NetworkMonitor.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import Network
import Foundation

/// Monitors network connection status.
final class NetworkMonitor: ObservableObject {
    
    static let shared = NetworkMonitor()

    /// NWPathMonitor checks the current network path.
    private let monitor = NWPathMonitor()
    
    /// Background queue for the monitor.
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published private(set) var isConnected: Bool = true

    /// Initializes the monitor and starts listening for changes.
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
