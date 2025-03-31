//
//  CameraView.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 28.3.25..
//
import SwiftUI
import AVFoundation

struct CameraPreviewRepresentable: UIViewRepresentable {
    let viewModel: MainViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = viewModel.previewLayer()
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
