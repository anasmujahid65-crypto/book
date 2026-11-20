//
//  PageThumbnailCell.swift
//  BookScanPDF
//
//  Renders a single page card in the Review grid with memory-safe thumbnail loading,
//  shimmer processing states, failure retry overlays, and multi-selection badges.
//

import SwiftUI

public struct PageThumbnailCell: View {
    public let page: Page
    public let isSelected: Bool
    public let isSelectMode: Bool
    public let onTap: () -> Void
    public let onRotate: () -> Void
    public let onDelete: () -> Void
    public let onRetry: () -> Void
    public let onRetake: () -> Void
    public let onSplitSpread: () -> Void
    public let onReorder: () -> Void
    
    @State private var thumbnailImage: UIImage? = nil
    
    public init(page: Page,
                isSelected: Bool,
                isSelectMode: Bool,
                onTap: @escaping () -> Void,
                onRotate: @escaping () -> Void,
                onDelete: @escaping () -> Void,
                onRetry: @escaping () -> Void,
                onRetake: @escaping () -> Void,
                onSplitSpread: @escaping () -> Void,
                onReorder: @escaping () -> Void) {
        self.page = page
        self.isSelected = isSelected
        self.isSelectMode = isSelectMode
        self.onTap = onTap
        self.onRotate = onRotate
        self.onDelete = onDelete
        self.onRetry = onRetry
        self.onRetake = onRetake
        self.onSplitSpread = onSplitSpread
        self.onReorder = onReorder
    }
    
    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Background Box
                ZStack {
                    Theme.tertiaryBackground
                    
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if page.status == .processing || page.status == .pending {
                        ShimmerView()
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    } else if page.status == .failed {
                        VStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.errorRed)
                            Button("Retry", action: onRetry)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.errorRed)
                                .clipShape(Capsule())
                        }
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.secondaryLabel)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                        .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: isSelected ? 2.5 : 1)
                )
                
                // Top-Left Page Number Badge
                VStack {
                    HStack {
                        Text("\(page.orderIndex + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Capsule())
                            .padding(6)
                        Spacer()
                    }
                    Spacer()
                }
                
                // Multi-Selection Checkmark
                if isSelectMode {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Theme.accent : Color.black.opacity(0.4))
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onTap) {
                Label("Edit Page", systemImage: "slider.horizontal.3")
            }
            Button(action: onReorder) {
                Label("Move to Page #...", systemImage: "arrow.up.arrow.down")
            }
            Button(action: onSplitSpread) {
                Label("Split Two-Page Spread", systemImage: "arrow.triangle.split")
            }
            Button(action: onRotate) {
                Label("Rotate 90°", systemImage: "rotate.right")
            }
            Button(action: onRetake) {
                Label("Retake Shot", systemImage: "camera.arrow.trianglehead.2.clockwise.rotate.90")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Page", systemImage: "trash")
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: page.thumbPath) { _ in
            loadThumbnail()
        }
        .onChange(of: page.status) { _ in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let path = page.thumbPath ?? page.processedPath ?? page.originalPath
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            if let thumb = ImageDownsampler.downsample(imageAt: url, maxDimension: 320) {
                DispatchQueue.main.async {
                    self.thumbnailImage = thumb
                }
            }
        }
    }
}
