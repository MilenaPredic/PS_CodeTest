//
//  AppLifecycleObserver.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//

import Foundation
import Combine
import UIKit

/// Observes app lifecycle and network availability events.
final class AppLifecycleObserver {
    
    /// Stores Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Called when network becomes available.
    private let onNetworkAvailable: () -> Void
    
    /// Called when app becomes active.
    private let onAppBecameActive: () -> Void

    /// Initializes observers with callbacks.
    init(onNetworkAvailable: @escaping () -> Void,
         onAppBecameActive: @escaping () -> Void) {
        self.onNetworkAvailable = onNetworkAvailable
        self.onAppBecameActive = onAppBecameActive

        observeNetworkStatus()
        observeAppState()
    }

    /// Subscribes to network status changes.
    private func observeNetworkStatus() {
        NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.onNetworkAvailable()
                }
            }
            .store(in: &cancellables)
    }

    /// Subscribes to app active state notifications.
    private func observeAppState() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.onAppBecameActive()
            }
            .store(in: &cancellables)
    }
}
