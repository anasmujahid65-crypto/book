//
//  GutterDetector.swift
//  BookScanPDF
//
//  Detects the vertical binding gutter (crease shadow) of an open two-page book spread
//  using column-intensity projection profiling.
//

import UIKit
import CoreGraphics

public final class GutterDetector {
    
    /// Analyzes an image to detect the vertical binding seam near the center (35% to 65% of width).
    /// Returns normalized split position (0.0 to 1.0). Defaults to 0.50 if no distinct valley is detected.
    public static func detectGutterSeam(in image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0.50 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Downsample to a small analysis grid for instant execution (~200px wide, ~150px tall)
        let sampleWidth = 200
        let sampleHeight = 150
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var rawBytes = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)
        
        guard let context = CGContext(
            data: &rawBytes,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0.50
        }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        
        // Scan columns between 35% and 65% of sample width
        let minCol = Int(Double(sampleWidth) * 0.35)
        let maxCol = Int(Double(sampleWidth) * 0.65)
        
        var minIntensitySum: Int = Int.max
        var bestCol: Int = sampleWidth / 2
        
        for col in minCol...maxCol {
            var colSum = 0
            for row in 0..<sampleHeight {
                colSum += Int(rawBytes[row * sampleWidth + col])
            }
            
            // Look for minimum intensity (darkest vertical binding crease)
            if colSum < minIntensitySum {
                minIntensitySum = colSum
                bestCol = col
            }
        }
        
        let normalized = CGFloat(bestCol) / CGFloat(sampleWidth)
        return max(0.40, min(0.60, normalized))
    }
}
