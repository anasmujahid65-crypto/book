//
//  CropLoupeView.swift
//  BookScanPDF
//
//  Magnifier loupe that renders a live 2.5x magnified circular view
//  centered precisely on the active corner handle or touch coordinate.
//  Provides pixel accuracy when positioning book page crop corners.
//

import SwiftUI

public struct CropLoupeView: View {
    public let image: UIImage
    public let touchPoint: CGPoint
    public let viewSize: CGSize
    
    private let loupeSize: CGFloat = 120
    private let magnification: CGFloat = 2.5
    
    public init(image: UIImage, touchPoint: CGPoint, viewSize: CGSize) {
        self.image = image
        self.touchPoint = touchPoint
        self.viewSize = viewSize
    }
    
    public var body: some View {
        if viewSize.width > 0 && viewSize.height > 0 {
            let anchorX = max(0.0, min(1.0, touchPoint.x / viewSize.width))
            let anchorY = max(0.0, min(1.0, touchPoint.y / viewSize.height))
            
            // Position the loupe comfortably above the finger so it's never covered
            let loupeX = max(loupeSize / 2 + 8, min(viewSize.width - loupeSize / 2 - 8, touchPoint.x))
            let loupeY = max(loupeSize / 2 + 8, touchPoint.y - 85)
            
            ZStack {
                ZStack {
                    Color.black
                    
                    // Live magnified image section
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: viewSize.width, height: viewSize.height)
                        .scaleEffect(magnification, anchor: UnitPoint(x: anchorX, y: anchorY))
                        .offset(
                            x: (loupeSize / 2) - touchPoint.x,
                            y: (loupeSize / 2) - touchPoint.y
                        )
                    
                    // Precision Crosshair
                    Path { path in
                        let c = loupeSize / 2
                        // Horizontal reticle
                        path.move(to: CGPoint(x: c - 18, y: c))
                        path.addLine(to: CGPoint(x: c - 4, y: c))
                        path.move(to: CGPoint(x: c + 4, y: c))
                        path.addLine(to: CGPoint(x: c + 18, y: c))
                        // Vertical reticle
                        path.move(to: CGPoint(x: c, y: c - 18))
                        path.addLine(to: CGPoint(x: c, y: c - 4))
                        path.move(to: CGPoint(x: c, y: c + 4))
                        path.addLine(to: CGPoint(x: c, y: c + 18))
                        // Center dot
                        path.addEllipse(in: CGRect(x: c - 2, y: c - 2, width: 4, height: 4))
                    }
                    .stroke(Theme.accent, lineWidth: 2)
                }
                .frame(width: loupeSize, height: loupeSize)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 3.5)
                )
                .overlay(
                    Circle().stroke(Theme.accent.opacity(0.8), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 5)
            }
            .position(x: loupeX, y: loupeY)
            .allowsHitTesting(false)
        }
    }
}
