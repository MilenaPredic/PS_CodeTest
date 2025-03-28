//
//  HomeView.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import SwiftUI
import AVFoundation
import Combine

/// Main view that handles camera access, image upload, and permission UI.
struct HomeView: View {
    @State private var showCameraView = false
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        ZStack {
            backgroundImage

            VStack {
                statusBar

                Spacer()

                if homeViewModel.isPermissionDenied {
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
            homeViewModel.checkPermissions()
        }
        .sheet(isPresented: $showCameraView) {
            CameraView(capturedImageData: $homeViewModel.selectedImage)
        }
        .onChange(of: homeViewModel.selectedImage) {
            if homeViewModel.selectedImage != nil {
                showCameraView = false
            }
        }
        .task(id: homeViewModel.selectedImage) {
            if homeViewModel.selectedImage != nil {
                await homeViewModel.uploadImage()
            }
        }
    }

    /// Background image of the screen.
    private var backgroundImage: some View {
        Image(.background)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .padding(.top, 44)
    }

    /// Button that opens the camera view.
    private var cameraButton: some View {
        Button(action: {
            showCameraView = true
        }) {
            Image(.camera)
                .padding(40)
        }
    }

    /// Permission popup shown when camera or location access is denied.
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

            PrimaryButton(action: homeViewModel.openAppSettings)
                .padding(.top, 20)
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .background(Color.black)
        .cornerRadius(15)
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: homeViewModel.isPermissionDenied)
    }

    /// Status bar shown when uploading images.
    private var statusBar: some View {
        HStack {
            if homeViewModel.state == .uploading {
                Text(HomeViewStrings.uploading)
                    .bold()
                Spacer()
                Text(homeViewModel.uploadProgressText)
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
