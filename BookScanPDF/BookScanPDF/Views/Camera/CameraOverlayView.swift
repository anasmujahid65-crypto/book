//
//  CameraOverlayView.swift
//  BookScanPDF
//
//  Renders real-time page detection polygon, rule-of-thirds alignment grid,
//  level bubble, and tap-to-focus ring.
//

import SwiftUI

public struct CameraOverlayView: View {
    public let indicatorState: IndicatorState
    public let showGrid: Bool
    public let pitch: Double
    public let roll: Double
    public let isLevel: Bool
    public let focusPoint: CGPoint?
    
    public init(indicatorState: IndicatorState,
                showGrid: Bool,
                pitch: Double,
                roll: Double,
                isLevel: Bool,
                focusPoint: CGPoint?) {
        self.indicatorState = indicatorState
        self.showGrid = showGrid
        self.pitch = pitch
        self.roll = roll
        self.isLevel = isLevel
        self.focusPoint = focusPoint
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Rule-of-Thirds Grid
                if showGrid {
                    GridOverlay()
                }
                
                // MARK: - Page Outline Polygon
                if let quad = indicatorState.quad {
                    PageOutlineShape(quad: quad, size: geometry.size)
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        .animation(.easeOut(duration: 0.12), value: quad.topLeft)
                    
                    if indicatorState.isGreen {
                        PageOutlineShape(quad: quad, size: geometry.size)
                            .fill(Theme.successGreen.opacity(0.15))
                            .animation(.easeOut(duration: 0.12), value: quad.topLeft)
                    }
                    
                    // Corner handles
                    CornerPinsView(quad: quad, size: geometry.size, color: strokeColor)
                }
                
                // MARK: - Horizon Level Bubble
                VStack {
                    Spacer()
                    LevelBubbleView(pitch: pitch, roll: roll, isLevel: isLevel)
                        .padding(.bottom, 150)
                }
                
                // MARK: - Tap to Focus Box
                if let focusPoint = focusPoint {
                    FocusBoxView()
                        .position(focusPoint)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var strokeColor: Color {
        switch indicatorState {
        case .green: return Theme.successGreen
        case .amber: return Theme.warningAmber
        case .red: return Theme.errorRed
        }
    }
}

// MARK: - Polygon Path Shape
private struct PageOutlineShape: Shape {
    let quad: NormalizedQuad
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Convert Vision normalized (bottom-left origin) to SwiftUI (top-left origin)
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

// MARK: - Corner Pins
private struct CornerPinsView: View {
    let quad: NormalizedQuad
    let size: CGSize
    let color: Color
    
    var body: some View {
        let points = [
            CGPoint(x: quad.topLeft.x * size.width, y: (1.0 - quad.topLeft.y) * size.height),
            CGPoint(x: quad.topRight.x * size.width, y: (1.0 - quad.topRight.y) * size.height),
            CGPoint(x: quad.bottomRight.x * size.width, y: (1.0 - quad.bottomRight.y) * size.height),
            CGPoint(x: quad.bottomLeft.x * size.width, y: (1.0 - quad.bottomLeft.y) * size.height)
        ]
        
        ForEach(0..<points.count, id: \.self) { idx in
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(color, lineWidth: 3)
                )
                .position(points[idx])
        }
    }
}

// MARK: - Level Bubble
private struct LevelBubbleView: View {
    let pitch: Double
    let roll: Double
    let isLevel: Bool
    
    var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .stroke(isLevel ? Theme.successGreen : Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.25)))
            
            // Center Target Cross
            Path { path in
                path.move(to: CGPoint(x: 17, y: 22))
                path.addLine(to: CGPoint(x: 27, y: 22))
                path.move(to: CGPoint(x: 22, y: 17))
                path.addLine(to: CGPoint(x: 22, y: 27))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
            .frame(width: 44, height: 44)
            
            // Motion Bubble
            Circle()
                .fill(isLevel ? Theme.successGreen : Theme.warningAmber)
                .frame(width: 12, height: 12)
                .offset(
                    x: CGFloat(max(-16, min(16, roll * 1.8))),
                    y: CGFloat(max(-16, min(16, pitch * 1.8)))
                )
        }
    }
}

// MARK: - Alignment Grid
private struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width
                let h = proxy.size.height
                
                // Vertical lines
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }
}

// MARK: - Focus Box
private struct FocusBoxView: View {
    @State private var scale: CGFloat = 1.3
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Rectangle()
            .stroke(Theme.warningAmber, lineWidth: 2)
            .frame(width: 65, height: 65)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                    opacity = 0.0
                }
            }
    }
}
