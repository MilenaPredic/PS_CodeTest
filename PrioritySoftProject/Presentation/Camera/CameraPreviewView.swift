//
//  CameraPreview.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 27.3.25..
//

import SwiftUI
import Combine

/// SwiftUI wrapper for a custom camera preview using UIViewRepresentable.
struct CameraPreviewView: UIViewRepresentable {
    @Binding var capturedImageData: Data?
    var onDismiss: () -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        context.coordinator.viewModel.onDismiss = onDismiss
        
        let previewLayer = context.coordinator.viewModel.previewLayer()
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        
        let button = makeCaptureButton(target: context.coordinator.viewModel,
                                       action: #selector(CameraViewModel.capturePhoto))
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            button.widthAnchor.constraint(equalToConstant: 70),
            button.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No dynamic update needed.
    }
    
    /// Creates coordinator to handle bindings and view model.
    func makeCoordinator() -> Coordinator {
        Coordinator(capturedImage: $capturedImageData, onDismiss: onDismiss)
    }
    
    private func makeCaptureButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        button.tintColor = .white
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    /// Coordinator class for managing view model and image data binding.
    class Coordinator {
        let viewModel = CameraViewModel()
        var capturedImage: Binding<Data?>
        private var cancellable: AnyCancellable?
        
        init(capturedImage: Binding<Data?>, onDismiss: @escaping () -> Void) {
            self.capturedImage = capturedImage
            viewModel.onDismiss = onDismiss
            
            /// Bind captured image from view model to SwiftUI state
            cancellable = viewModel.$capturedImageData
                .receive(on: RunLoop.main)
                .sink { image in
                    capturedImage.wrappedValue = image
                }
        }
    }
}
