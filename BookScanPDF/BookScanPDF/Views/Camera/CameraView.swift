//
//  CameraView.swift
//  BookScanPDF
//
//  Primary continuous book scanning screen. Keeps camera active across hundreds of shots
//  with zero editor interruption, live indicator guidance, and direct disk writing.
//

import SwiftUI
import AVFoundation

public struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentZoom: CGFloat = 1.0
    @State private var baseZoom: CGFloat = 1.0
    
    public init(project: Project) {
        _viewModel = StateObject(wrappedValue: CameraViewModel(project: project))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // MARK: - Live AVFoundation Camera Preview
                CameraPreviewView(session: viewModel.cameraManager.session)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newZoom = baseZoom * value
                                currentZoom = max(1.0, min(newZoom, 5.0))
                                viewModel.handlePinchZoom(scale: currentZoom)
                            }
                            .onEnded { _ in
                                baseZoom = currentZoom
                            }
                    )
                    .onTapGesture { location in
                        viewModel.handleTapToFocus(at: location, viewSize: geometry.size)
                    }
                
                // MARK: - Live Indicator & Grid Overlay
                CameraOverlayView(
                    indicatorState: viewModel.indicatorState,
                    showGrid: viewModel.showGrid,
                    pitch: viewModel.pitch,
                    roll: viewModel.roll,
                    isLevel: viewModel.isDeviceLevel,
                    focusPoint: viewModel.focusPoint
                )
                
                // MARK: - Shutter Flash Animation
                if viewModel.showShutterFlash {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                // MARK: - Top Navigation & Hint Bar
                VStack(spacing: 0) {
                    TopCameraBar(
                        flashIcon: viewModel.flashModeIcon,
                        isTorchOn: viewModel.isTorchActive,
                        isGridOn: viewModel.showGrid,
                        hintText: viewModel.indicatorState.hint,
                        isGreen: viewModel.indicatorState.isGreen,
                        onClose: { viewModel.handleCloseRequest() },
                        onToggleFlash: { viewModel.toggleFlash() },
                        onToggleTorch: { viewModel.toggleTorch() },
                        onToggleGrid: { viewModel.toggleGrid() }
                    )
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 8 : 16)
                    .padding(.horizontal, Theme.spacingM)
                    
                    Spacer()
                    
                    // MARK: - Page Counter Pill
                    Text("Page \(viewModel.pageCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .padding(.bottom, Theme.spacingM)
                    
                    // MARK: - Bottom Controls Bar
                    BottomControlsBar(
                        pageCount: viewModel.pageCount,
                        thumbnail: viewModel.latestThumbnail,
                        isGreen: viewModel.indicatorState.isGreen,
                        onShutter: { viewModel.triggerShutter() },
                        onThumbnailTap: { viewModel.navigateToReview = true },
                        onDone: { viewModel.navigateToReview = true }
                    )
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 20)
                    .padding(.horizontal, Theme.spacingL)
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.dismissCamera) { dismiss in
            if dismiss {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .actionSheet(isPresented: $viewModel.showExitConfirmation) {
            ActionSheet(
                title: Text("Scanning in Progress"),
                message: Text("You have captured \(viewModel.pageCount) pages in this book scan."),
                buttons: [
                    .default(Text("Keep Scanning")) {},
                    .default(Text("Save & Exit")) { viewModel.saveAndExit() },
                    .destructive(Text("Discard Scan")) { viewModel.discardAndExit() },
                    .cancel()
                ]
            )
        }
        .alert("Camera Permission Required", isPresented: $viewModel.isPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Please grant BookScan PDF camera access in iOS Settings to scan book pages.")
        }
        // Link to ReviewView
        .fullScreenCover(isPresented: $viewModel.navigateToReview) {
            ReviewView(project: viewModel.project)
        }
    }
}

// MARK: - Top Camera Bar Component
private struct TopCameraBar: View {
    let flashIcon: String
    let isTorchOn: Bool
    let isGridOn: Bool
    let hintText: String
    let isGreen: Bool
    let onClose: () -> Void
    let onToggleFlash: () -> Void
    let onToggleTorch: () -> Void
    let onToggleGrid: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Controls Group
                HStack(spacing: 14) {
                    Button(action: onToggleFlash) {
                        Image(systemName: flashIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onToggleTorch) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isTorchOn ? Theme.warningAmber : .white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onToggleGrid) {
                        Image(systemName: isGridOn ? "grid" : "grid.slash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isGridOn ? Theme.accent : .white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Centered Live Hint Chip
            HStack(spacing: 6) {
                Image(systemName: isGreen ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isGreen ? Theme.successGreen : Theme.warningAmber)
                
                Text(hintText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.65))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isGreen ? Theme.successGreen.opacity(0.7) : Color.white.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: hintText)
        }
    }
}

// MARK: - Bottom Controls Bar Component
private struct BottomControlsBar: View {
    let pageCount: Int
    let thumbnail: UIImage?
    let isGreen: Bool
    let onShutter: () -> Void
    let onThumbnailTap: () -> Void
    let onDone: () -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            // Left: Thumbnail / Series Stack Preview
            Button(action: onThumbnailTap) {
                ZStack(alignment: .topTrailing) {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if pageCount > 0 {
                        Text("\(pageCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .frame(width: 60)
            .disabled(pageCount == 0)
            .accessibilityLabel("Scanned pages stack: \(pageCount) pages")
            .accessibilityHint("Tap to review and edit captured pages")
            
            Spacer()
            
            // Center: Large Shutter Button (Always active!)
            Button(action: onShutter) {
                ZStack {
                    Circle()
                        .stroke(isGreen ? Theme.successGreen : Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .scaleEffect(isGreen ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isGreen)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                }
            }
            .accessibilityLabel("Shutter")
            .accessibilityHint(isGreen ? "Page aligned perfectly. Tap to capture page." : "Tap to capture page.")
            
            Spacer()
            
            // Right: Prominent Done Button
            Button(action: onDone) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Done")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(pageCount > 0 ? Theme.successGreen : Color.gray.opacity(0.5))
                .clipShape(Capsule())
            }
            .frame(minWidth: 70)
            .disabled(pageCount == 0)
            .accessibilityLabel("Done scanning series")
            .accessibilityHint("Finishes capture and opens review workspace")
        }
    }
}
