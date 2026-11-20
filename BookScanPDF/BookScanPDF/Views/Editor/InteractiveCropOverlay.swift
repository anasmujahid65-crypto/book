//
//  InteractiveCropOverlay.swift
//  BookScanPDF
//
//  Interactive quadrilateral crop overlay with four draggable corner pins
//  and real-time touch coordinate reporting for the magnifier loupe.
//

import SwiftUI

public enum ActiveCorner {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
    case none
}

public struct InteractiveCropOverlay: View {
    @Binding public var quad: NormalizedQuad
    public let viewSize: CGSize
    public let onDragChanged: (ActiveCorner, CGPoint) -> Void
    public let onDragEnded: () -> Void
    
    @State private var draggingCorner: ActiveCorner = .none
    
    public init(quad: Binding<NormalizedQuad>,
                viewSize: CGSize,
                onDragChanged: @escaping (ActiveCorner, CGPoint) -> Void,
                onDragEnded: @escaping () -> Void) {
        self._quad = quad
        self.viewSize = viewSize
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }
    
    public var body: some View {
        ZStack {
            // Polygon Outline
            CropPolygonShape(quad: quad, size: viewSize)
                .stroke(Theme.accent, lineWidth: 2.5)
            
            // Subtle fill
            CropPolygonShape(quad: quad, size: viewSize)
                .fill(Theme.accent.opacity(0.12))
            
            // 4 Corner Handles
            cornerHandle(corner: .topLeft, normalizedPoint: quad.topLeft)
            cornerHandle(corner: .topRight, normalizedPoint: quad.topRight)
            cornerHandle(corner: .bottomRight, normalizedPoint: quad.bottomRight)
            cornerHandle(corner: .bottomLeft, normalizedPoint: quad.bottomLeft)
        }
    }
    
    private func cornerHandle(corner: ActiveCorner, normalizedPoint: CGPoint) -> some View {
        let screenPoint = CGPoint(
            x: normalizedPoint.x * viewSize.width,
            y: (1.0 - normalizedPoint.y) * viewSize.height
        )
        
        return ZStack {
            // Touch target (expanded for thumb accessibility)
            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
            
            // Visible handle pin
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(Theme.accent, lineWidth: 3.5)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .position(screenPoint)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    draggingCorner = corner
                    let newX = max(0.0, min(1.0, value.location.x / viewSize.width))
                    let newY = max(0.0, min(1.0, 1.0 - (value.location.y / viewSize.height)))
                    let clampedNormalized = CGPoint(x: newX, y: newY)
                    
                    switch corner {
                    case .topLeft:
                        quad.topLeft = clampedNormalized
                    case .topRight:
                        quad.topRight = clampedNormalized
                    case .bottomRight:
                        quad.bottomRight = clampedNormalized
                    case .bottomLeft:
                        quad.bottomLeft = clampedNormalized
                    case .none:
                        break
                    }
                    
                    onDragChanged(corner, value.location)
                }
                .onEnded { _ in
                    draggingCorner = .none
                    onDragEnded()
                }
        )
    }
}

private struct CropPolygonShape: Shape {
    let quad: NormalizedQuad
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = CGPoint(x: quad.topLeft.x * size.width, y: (1.0 - quad.topLeft.y) * size.height)
        let tr = CGPoint(x: quad.topRight.x * size.width, y: (1.0 - quad.topRight.y) * size.height)
        let br = CGPoint(x: quad.bottomRight.x * size.width, y: (1.0 - quad.bottomRight.y) * size.height)
        let bl = CGPoint(x: quad.bottomLeft.x * size.width, y: (1.0 - quad.bottomLeft.y) * size.height)
        
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()
        return path
    }
}
