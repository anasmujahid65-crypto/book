//
//  PageEditorView.swift
//  BookScanPDF
//
//  Comprehensive book page editor featuring interactive quadrilateral corner adjustment,
//  magnifier loupe, fine rotation, document filter presets, tone calibration, and cascade prompt.
//

import SwiftUI

public enum EditorToolTab: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case filter = "Filter"
    case adjust = "Adjust"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .crop: return "crop"
        case .filter: return "wand.and.stars"
        case .adjust: return "slider.horizontal.3"
        }
    }
}

public struct PageEditorView: View {
    @StateObject private var viewModel: PageEditorViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public let onSaveComplete: () -> Void
    @State private var activeTab: EditorToolTab = .crop
    
    public init(page: Page, project: Project, onSaveComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PageEditorViewModel(page: page, project: project))
        self.onSaveComplete = onSaveComplete
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Top Navigation Bar
                    EditorTopBar(
                        pageOrder: viewModel.page.orderIndex + 1,
                        isSaving: viewModel.isSaving,
                        onCancel: { presentationMode.wrappedValue.dismiss() },
                        onSave: {
                            viewModel.save {
                                onSaveComplete()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 8 : 16)
                    
                    // MARK: - Interactive Image Canvas
                    ZStack {
                        if activeTab == .crop, let imageToCrop = viewModel.displayedCropImage ?? viewModel.rawOriginalImage {
                            // Rotated/aligned image with interactive crop overlay
                            Image(uiImage: imageToCrop)
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    GeometryReader { imgGeo in
                                        InteractiveCropOverlay(
                                            quad: $viewModel.cropQuad,
                                            viewSize: imgGeo.size,
                                            onDragChanged: { corner, location in
                                                viewModel.updateLoupe(
                                                    corner: corner,
                                                    touchLocation: location,
                                                    viewSize: imgGeo.size
                                                )
                                            },
                                            onDragEnded: {
                                                viewModel.hideLoupe()
                                                viewModel.updateLivePreview()
                                            }
                                        )
                                    }
                                )
                                .padding(12)
                            
                            // Magnifier Loupe Overlay
                            if viewModel.showLoupe {
                                CropLoupeView(
                                    image: imageToCrop,
                                    touchPoint: viewModel.loupeTouchPoint,
                                    viewSize: viewModel.loupeViewSize
                                )
                            }
                        } else if let preview = viewModel.workingPreviewImage {
                            // Perspective-corrected & filtered live preview
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // MARK: - Tool Selector Tabs
                    ToolTabBar(activeTab: $activeTab) { tab in
                        viewModel.isCropActive = (tab == .crop)
                        viewModel.updateLivePreview()
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.vertical, 8)
                    
                    // MARK: - Bottom Tool Controls Panel
                    VStack {
                        switch activeTab {
                        case .crop:
                            CropControlsView(
                                fineStraighten: $viewModel.fineStraighten,
                                onRotate: { viewModel.rotateClockwise() },
                                onAutoDetect: { viewModel.autoDetectCorners() },
                                onReset: { viewModel.resetCorners() },
                                onSliderChanged: {
                                    viewModel.updateDisplayedCropImage()
                                    viewModel.updateLivePreview()
                                }
                            )
                        case .filter:
                            FilterSelectorView(
                                selectedFilter: $viewModel.selectedFilter,
                                onSelect: { filter in
                                    viewModel.selectedFilter = filter
                                    viewModel.updateLivePreview()
                                }
                            )
                        case .adjust:
                            AdjustmentSlidersView(
                                brightness: $viewModel.brightness,
                                contrast: $viewModel.contrast,
                                onSliderChanged: { viewModel.updateLivePreview() }
                            )
                        }
                    }
                    .frame(height: 110)
                    .padding(.horizontal, Theme.spacingL)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 16)
                    .background(Color.black.opacity(0.85).ignoresSafeArea())
                }
            }
        }
        .alert("Apply Page 1 Edits to All Pages?", isPresented: $viewModel.promptCascadePage1) {
            Button("Apply to All Pages") {
                viewModel.cascadeToAllPages {
                    onSaveComplete()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Keep Only This Page", role: .cancel) {
                onSaveComplete()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("You modified Page 1. Would you like to automatically cascade these filter and tone adjustments across the entire book?")
        }
    }
}

// MARK: - Subcomponents

private struct EditorTopBar: View {
    let pageOrder: Int
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("Edit Page \(pageOrder)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                } else {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
            }
            .disabled(isSaving)
        }
        .frame(height: 44)
    }
}

private struct ToolTabBar: View {
    @Binding var activeTab: EditorToolTab
    let onSelect: (EditorToolTab) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(EditorToolTab.allCases) { tab in
                Button(action: {
                    activeTab = tab
                    onSelect(tab)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                        Text(tab.rawValue)
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(activeTab == tab ? .white : Theme.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(activeTab == tab ? Theme.primaryLight : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

private struct CropControlsView: View {
    @Binding var fineStraighten: Double
    let onRotate: () -> Void
    let onAutoDetect: () -> Void
    let onReset: () -> Void
    let onSliderChanged: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onRotate) {
                    Label("Rotate 90°", systemImage: "rotate.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Button(action: onAutoDetect) {
                    Label("Auto Detect", systemImage: "viewfinder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Button(action: onReset) {
                    Text("Reset")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 8) {
                Text("-10°")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Slider(value: $fineStraighten, in: -10.0...10.0, step: 0.5) { _ in
                    onSliderChanged()
                }
                .accentColor(Theme.accent)
                Text("+10°")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }
}

private struct FilterSelectorView: View {
    @Binding var selectedFilter: FilterType
    let onSelect: (FilterType) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(FilterType.allCases) { filter in
                Button(action: { onSelect(filter) }) {
                    VStack(spacing: 4) {
                        Image(systemName: filter.iconName)
                            .font(.system(size: 20))
                        Text(filter.displayName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(selectedFilter == filter ? Theme.accent : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedFilter == filter ? Theme.accent.opacity(0.15) : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedFilter == filter ? Theme.accent : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
    }
}

private struct AdjustmentSlidersView: View {
    @Binding var brightness: Float
    @Binding var contrast: Float
    let onSliderChanged: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.warningAmber)
                Slider(value: $brightness, in: -0.5...0.5) { _ in
                    onSliderChanged()
                }
                .accentColor(Theme.warningAmber)
                Text(String(format: "%+.1f", brightness))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 38)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Slider(value: $contrast, in: 0.5...1.5) { _ in
                    onSliderChanged()
                }
                .accentColor(Theme.primaryLight)
                Text(String(format: "%.1f", contrast))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 38)
            }
        }
    }
}
