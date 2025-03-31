//
//  MainView.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import SwiftUI
import Combine

/// Main view that handles camera access, image upload, and permission UI.
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    // @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraPreviewRepresentable(viewModel: viewModel)
            VStack {
                statusBar
                Spacer()
                
                if viewModel.isPermissionDenied {
                    permissionPopup
                } else {
                    HStack {
                        Spacer()
                        cameraButton
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            viewModel.checkPermissions()
        }
        .onChange(of: viewModel.capturedImageData) {
            viewModel.selectedImage = viewModel.capturedImageData
        }
        .task(id: viewModel.selectedImage) {
            if viewModel.selectedImage != nil {
                await viewModel.uploadImage()
            }
        }
    }
    
    private var cameraButton: some View {
        Button(action: {
            viewModel.capturePhoto()
        }) {
            Image(.camera)
                .padding(40)
        }
    }
    
    private var permissionPopup: some View {
        VStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 10) {
                Text(HomeViewStrings.permissionTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(HomeViewStrings.permissionDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.appGray)
            }
            
            PrimaryButton(action: viewModel.openAppSettings)
                .padding(.top, 20)
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .background(Color.black)
        .cornerRadius(15)
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: viewModel.isPermissionDenied)
    }
    
    private var statusBar: some View {
        HStack {
            if viewModel.state == .uploading {
                Text(HomeViewStrings.uploading)
                    .bold()
            }
            Spacer()
            if viewModel.totalCount > 0 {
                Text(viewModel.uploadProgressText)
            }
    }
        .font(.system(size: 14))
        .foregroundColor(.white)
        .padding(.horizontal, 17)
        .padding(.top, 86)
        .padding(.bottom)
        .frame(maxWidth: .infinity)
        .background(Color.black)
}
}
