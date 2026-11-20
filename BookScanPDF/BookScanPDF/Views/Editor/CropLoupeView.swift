//
//  CropLoupeView.swift
//  BookScanPDF
//
//  Magnifier loupe that renders a 2.5x magnified circular view centered on the active corner handle.
//  Provides sub-pixel accuracy when positioning book page crop corners.
//

import SwiftUI

public struct CropLoupeView: View {
    public let image: UIImage
    public let focusPoint: CGPoint // Position in image coordinates
    public let loupePosition: CGPoint // Position in view coordinates
    
    private let loupeSize: CGFloat = 110
    private let magnification: CGFloat = 2.4
    
    public init(image: UIImage, focusPoint: CGPoint, loupePosition: CGPoint) {
        self.image = image
        self.focusPoint = focusPoint
        self.loupePosition = loupePosition
    }
    
    public var body: some View {
        ZStack {
            // Magnified Image Crop
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(magnification)
                .offset(
                    x: -focusPoint.x * (magnification - 1.0),
                    y: -focusPoint.y * (magnification - 1.0)
                )
                .frame(width: loupeSize, height: loupeSize)
                .clipShape(Circle())
            
            // Precision Crosshair
            Path { path in
                let center = loupeSize / 2
                path.move(to: CGPoint(x: center - 12, y: center))
                path.addLine(to: CGPoint(x: center + 12, y: center))
                path.move(to: CGPoint(x: center, y: center - 12))
                path.addLine(to: CGPoint(x: center, y: center + 12))
            }
            .stroke(Theme.accent, lineWidth: 1.5)
            
            // Loupe Outer Ring & Shadow
            Circle()
                .stroke(Color.white, lineWidth: 3.5)
                .frame(width: loupeSize, height: loupeSize)
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .position(x: loupePosition.x, y: max(loupeSize / 2 + 10, loupePosition.y - 80))
        .allowsHitTesting(false)
    }
}
