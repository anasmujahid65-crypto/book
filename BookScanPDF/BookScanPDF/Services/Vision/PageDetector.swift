//
//  PageDetector.swift
//  BookScanPDF
//
//  Real-time book page detection using Vision (VNDetectRectanglesRequest).
//  Applies 4 strict criteria, low-pass corner smoothing, and multi-frame hysteresis.
//

import Foundation
import Vision
import CoreGraphics
import CoreVideo

public enum IndicatorState: Equatable {
    case red(quad: NormalizedQuad?, hint: String)
    case amber(quad: NormalizedQuad?, hint: String)
    case green(quad: NormalizedQuad, hint: String)
    
    public var isGreen: Bool {
        if case .green = self { return true }
        return false
    }
    
    public var hint: String {
        switch self {
        case .red(_, let hint), .amber(_, let hint), .green(_, let hint):
            return hint
        }
    }
    
    public var quad: NormalizedQuad? {
        switch self {
        case .red(let quad, _), .amber(let quad, _):
            return quad
        case .green(let quad, _):
            return quad
        }
    }
}

public final class PageDetector {
    // Tuning Constants
    private let minAreaRatio: CGFloat = 0.45 // At least 45-50% of the frame
    private let edgeMargin: CGFloat = 0.02   // 2% margin from frame edges
    private let smoothingAlpha: CGFloat = 0.35 // Low-pass filter smoothing coefficient
    
    // Hysteresis Counters
    private let consecutivePassesNeededForGreen = 3
    private let consecutiveFailsNeededToDropGreen = 2
    private var consecutivePasses = 0
    private var consecutiveFails = 0
    private var wasGreen = false
    
    // Low-pass filtered quad
    private var smoothedQuad: NormalizedQuad?
    
    // Vision Request
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1.60
        request.minimumSize = 0.20
        request.quadratureTolerance = 30.0
        request.minimumConfidence = 0.60
        request.maximumObservations = 1
        return request
    }()
    
    public init() {}
    
    public func reset() {
        smoothedQuad = nil
        consecutivePasses = 0
        consecutiveFails = 0
        wasGreen = false
    }
    
    /// Evaluates a video frame pixel buffer alongside current device motion state
    public func processFrame(pixelBuffer: CVPixelBuffer, isDeviceLevel: Bool, tiltPitch: Double, tiltRoll: Double) -> IndicatorState {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([rectangleRequest])
            guard let observation = rectangleRequest.results?.first else {
                smoothedQuad = nil
                consecutivePasses = 0
                wasGreen = false
                return .red(quad: nil, hint: "Page not detected")
            }
            
            // Vision coordinates have (0,0) at bottom-left
            let rawQuad = NormalizedQuad(
                topLeft: observation.topLeft,
                topRight: observation.topRight,
                bottomRight: observation.bottomRight,
                bottomLeft: observation.bottomLeft
            )
            
            // Apply low-pass exponential moving average to eliminate jitter
            let filteredQuad = smoothQuad(rawQuad)
            self.smoothedQuad = filteredQuad
            
            // MARK: - 4 Checks for Indicator
            
            // Check 1: Quadrilateral sanity
            let area = calculatePolygonArea(quad: filteredQuad)
            
            // Check 2: Big enough (at least ~45-50% of frame)
            let isBigEnough = area >= minAreaRatio
            
            // Check 3: Fully inside viewfinder with safety margin
            let isFullyInside = checkFullyInside(quad: filteredQuad, margin: edgeMargin)
            
            // Check 4: Skew & Level checks
            let (isUnskewed, skewHint) = checkSkew(quad: filteredQuad)
            
            // Determine result & hints
            if !isDeviceLevel {
                consecutivePasses = 0
                wasGreen = false
                let direction = abs(tiltPitch) > abs(tiltRoll)
                    ? (tiltPitch > 0 ? "Tilt phone forward" : "Tilt phone backward")
                    : (tiltRoll > 0 ? "Tilt phone left" : "Tilt phone right")
                return .amber(quad: filteredQuad, hint: direction)
            }
            
            if !isFullyInside {
                consecutivePasses = 0
                wasGreen = false
                return .red(quad: filteredQuad, hint: "Bring entire page inside")
            }
            
            if !isBigEnough {
                consecutivePasses = 0
                wasGreen = false
                return .amber(quad: filteredQuad, hint: "Move camera closer to page")
            }
            
            if !isUnskewed {
                consecutivePasses = 0
                wasGreen = false
                return .amber(quad: filteredQuad, hint: skewHint ?? "Align straight with page")
            }
            
            // All 4 checks passed! Apply hysteresis
            consecutivePasses += 1
            consecutiveFails = 0
            
            if wasGreen || consecutivePasses >= consecutivePassesNeededForGreen {
                wasGreen = true
                return .green(quad: filteredQuad, hint: "Perfect! Ready to capture")
            } else {
                return .amber(quad: filteredQuad, hint: "Holding steady...")
            }
            
        } catch {
            return .red(quad: nil, hint: "Analyzing scene...")
        }
    }
    
    // MARK: - Geometry & Filtering Helpers
    
    private func smoothQuad(_ newQuad: NormalizedQuad) -> NormalizedQuad {
        guard let prev = smoothedQuad else { return newQuad }
        
        func smoothPoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
            return CGPoint(
                x: p1.x * (1 - smoothingAlpha) + p2.x * smoothingAlpha,
                y: p1.y * (1 - smoothingAlpha) + p2.y * smoothingAlpha
            )
        }
        
        return NormalizedQuad(
            topLeft: smoothPoint(prev.topLeft, newQuad.topLeft),
            topRight: smoothPoint(prev.topRight, newQuad.topRight),
            bottomRight: smoothPoint(prev.bottomRight, newQuad.bottomRight),
            bottomLeft: smoothPoint(prev.bottomLeft, newQuad.bottomLeft)
        )
    }
    
    private func calculatePolygonArea(quad: NormalizedQuad) -> CGFloat {
        // Shoelace formula for normalized polygon area
        let pts = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]
        var area: CGFloat = 0.0
        let n = pts.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += pts[i].x * pts[j].y
            area -= pts[j].x * pts[i].y
        }
        return abs(area) / 2.0
    }
    
    private func checkFullyInside(quad: NormalizedQuad, margin: CGFloat) -> Bool {
        let corners = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]
        for pt in corners {
            if pt.x < margin || pt.x > (1.0 - margin) || pt.y < margin || pt.y > (1.0 - margin) {
                return false
            }
        }
        return true
    }
    
    private func checkSkew(quad: NormalizedQuad) -> (isUnskewed: Bool, hint: String?) {
        // Length of opposite sides
        let topLen = hypot(quad.topRight.x - quad.topLeft.x, quad.topRight.y - quad.topLeft.y)
        let bottomLen = hypot(quad.bottomRight.x - quad.bottomLeft.x, quad.bottomRight.y - quad.bottomLeft.y)
        let leftLen = hypot(quad.bottomLeft.x - quad.topLeft.x, quad.bottomLeft.y - quad.topLeft.y)
        let rightLen = hypot(quad.bottomRight.x - quad.topRight.x, quad.bottomRight.y - quad.topRight.y)
        
        guard topLen > 0, bottomLen > 0, leftLen > 0, rightLen > 0 else {
            return (false, "Page skewed")
        }
        
        // Ratio of opposing edges (trapezoid distortion)
        let horizontalRatio = max(topLen, bottomLen) / min(topLen, bottomLen)
        let verticalRatio = max(leftLen, rightLen) / min(leftLen, rightLen)
        
        if horizontalRatio > 1.30 || verticalRatio > 1.30 {
            return (false, "Keep phone parallel to page")
        }
        
        // Top edge horizontal orientation
        let dy = abs(quad.topRight.y - quad.topLeft.y)
        let dx = abs(quad.topRight.x - quad.topLeft.x)
        let angleDegrees = atan2(dy, dx) * 180.0 / .pi
        if angleDegrees > 12.0 {
            return (false, "Rotate phone to match page")
        }
        
        return (true, nil)
    }
}
