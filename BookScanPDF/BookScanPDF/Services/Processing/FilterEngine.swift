//
//  FilterEngine.swift
//  BookScanPDF
//
//  Core Image filter execution engine. Handles perspective correction,
//  tone adjustments, document filters, and single-channel grayscale/B&W output.
//

import UIKit
import CoreImage

public final class FilterEngine {
    private let contextHolder = CIContextHolder.shared
    
    public init() {}
    
    // MARK: - Full Pipeline Execution
    
    /// Executes perspective correction, rotation, tone adjustments, and filter effects.
    public func process(
        ciImage: CIImage,
        edit: PageEdit,
        qualityPreset: PDFPreset
    ) -> (processedData: Data, isGrayscale: Bool)? {
        var current = ciImage
        let extent = current.extent
        let width = extent.width
        let height = extent.height
        
        // 1. Perspective Correction
        if let quad = edit.cropCorners {
            current = applyPerspectiveCorrection(image: current, quad: quad, imageSize: CGSize(width: width, height: height))
        }
        
        // 2. Rotation & Fine Straighten
        if edit.rotationDegrees != 0 {
            current = applyRotation(image: current, degrees: edit.rotationDegrees)
        }
        if abs(edit.fineStraightenAngle) > 0.01 {
            current = applyStraighten(image: current, angleDegrees: edit.fineStraightenAngle)
        }
        
        // 3. Brightness & Contrast Adjustments
        if abs(edit.brightness) > 0.01 || abs(edit.contrast - 1.0) > 0.01 {
            current = applyToneAdjustments(image: current, brightness: edit.brightness, contrast: edit.contrast)
        }
        
        // 4. Document Filter (Original, Enhanced, Grayscale, B&W)
        let isGray = (edit.filter == .grayscale || edit.filter == .blackAndWhite)
        current = applyFilter(image: current, filter: edit.filter)
        
        // 5. Downscale to PDF Preset Target if required
        if qualityPreset.targetLongSide > 0 {
            current = downscaleToFit(image: current, maxLongSide: qualityPreset.targetLongSide)
        }
        
        // 6. Render to JPEG Data using appropriate color space
        let outputExtent = current.extent
        let colorSpace = isGray ? contextHolder.colorSpaceGray : contextHolder.colorSpaceRGB
        
        guard let cgImage = contextHolder.context.createCGImage(
            current,
            from: outputExtent,
            format: isGray ? .L8 : .RGBA8,
            colorSpace: colorSpace
        ) else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: qualityPreset.compressionQuality) else {
            return nil
        }
        
        return (jpegData, isGray)
    }
    
    // MARK: - Perspective Correction
    
    public func applyPerspectiveCorrection(image: CIImage, quad: NormalizedQuad, imageSize: CGSize) -> CIImage {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        
        // CoreImage has origin at bottom-left, matching Vision's coordinate system
        let w = imageSize.width
        let h = imageSize.height
        
        let tl = CIVector(cgPoint: CGPoint(x: quad.topLeft.x * w, y: quad.topLeft.y * h))
        let tr = CIVector(cgPoint: CGPoint(x: quad.topRight.x * w, y: quad.topRight.y * h))
        let br = CIVector(cgPoint: CGPoint(x: quad.bottomRight.x * w, y: quad.bottomRight.y * h))
        let bl = CIVector(cgPoint: CGPoint(x: quad.bottomLeft.x * w, y: quad.bottomLeft.y * h))
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(tl, forKey: "inputTopLeft")
        filter.setValue(tr, forKey: "inputTopRight")
        filter.setValue(br, forKey: "inputBottomRight")
        filter.setValue(bl, forKey: "inputBottomLeft")
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Document Filters
    
    public func applyFilter(image: CIImage, filter: FilterType) -> CIImage {
        switch filter {
        case .original:
            // Apply subtle edge clarity so scanned text isn't soft
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(image, forKey: kCIInputImageKey)
                unsharp.setValue(1.5, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.30, forKey: kCIInputIntensityKey)
                return unsharp.outputImage ?? image
            }
            return image
            
        case .enhanced:
            // Color enhancement with vibrance and mild sharpening
            var result = image
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(result, forKey: kCIInputImageKey)
                colorControls.setValue(1.15, forKey: kCIInputSaturationKey)
                colorControls.setValue(1.08, forKey: kCIInputContrastKey)
                result = colorControls.outputImage ?? result
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(result, forKey: kCIInputImageKey)
                unsharp.setValue(2.0, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.40, forKey: kCIInputIntensityKey)
                result = unsharp.outputImage ?? result
            }
            return result
            
        case .grayscale:
            // Clean grayscale with slight contrast boost for legibility
            var result = image
            if let noir = CIFilter(name: "CIPhotoEffectNoir") {
                noir.setValue(result, forKey: kCIInputImageKey)
                result = noir.outputImage ?? result
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(result, forKey: kCIInputImageKey)
                unsharp.setValue(1.8, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.35, forKey: kCIInputIntensityKey)
                result = unsharp.outputImage ?? result
            }
            return result
            
        case .blackAndWhite:
            // High-contrast clean book text binarization
            // Desaturate -> Sharpen text edges -> Bleach paper background to pure white
            var result = image
            if let desaturate = CIFilter(name: "CIColorControls") {
                desaturate.setValue(result, forKey: kCIInputImageKey)
                desaturate.setValue(0.0, forKey: kCIInputSaturationKey)
                result = desaturate.outputImage ?? result
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(result, forKey: kCIInputImageKey)
                unsharp.setValue(3.0, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.85, forKey: kCIInputIntensityKey)
                result = unsharp.outputImage ?? result
            }
            if let thresholdControls = CIFilter(name: "CIColorControls") {
                thresholdControls.setValue(result, forKey: kCIInputImageKey)
                thresholdControls.setValue(2.6, forKey: kCIInputContrastKey)
                thresholdControls.setValue(0.18, forKey: kCIInputBrightnessKey)
                result = thresholdControls.outputImage ?? result
            }
            return result
        }
    }
    
    // MARK: - Adjustments
    
    public func applyToneAdjustments(image: CIImage, brightness: Float, contrast: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        return filter.outputImage ?? image
    }
    
    public func applyRotation(image: CIImage, degrees: Int) -> CIImage {
        switch degrees {
        case 90:
            return image.oriented(.right)
        case 180:
            return image.oriented(.down)
        case 270:
            return image.oriented(.left)
        default:
            return image
        }
    }
    
    public func applyStraighten(image: CIImage, angleDegrees: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIStraightenFilter") else { return image }
        let radians = angleDegrees * .pi / 180.0
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(radians, forKey: kCIInputAngleKey)
        return filter.outputImage ?? image
    }
    
    public func downscaleToFit(image: CIImage, maxLongSide: CGFloat) -> CIImage {
        let currentLongSide = max(image.extent.width, image.extent.height)
        guard currentLongSide > maxLongSide else { return image }
        
        let scale = maxLongSide / currentLongSide
        if let lanczos = CIFilter(name: "CILanczosScaleTransform") {
            lanczos.setValue(image, forKey: kCIInputImageKey)
            lanczos.setValue(scale, forKey: kCIInputScaleKey)
            lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let output = lanczos.outputImage {
                return output
            }
        }
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}
