//
//  CameraView.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//

import SwiftUI

/// A full-screen camera view that displays the camera preview.
struct CameraView: View {
    @Binding var capturedImageData: Data?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        CameraPreviewView(capturedImageData: $capturedImageData) {
            dismiss()
        }
        .ignoresSafeArea()
    }
}
