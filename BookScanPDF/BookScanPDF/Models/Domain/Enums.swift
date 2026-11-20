//
//  Enums.swift
//  BookScanPDF
//

import Foundation
import SwiftUI

public enum FilterType: String, CaseIterable, Codable, Identifiable {
    case original = "original"
    case enhanced = "enhanced"
    case grayscale = "grayscale"
    case blackAndWhite = "blackAndWhite"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .enhanced: return "Enhanced"
        case .grayscale: return "Grayscale"
        case .blackAndWhite: return "B&W Text"
        }
    }
    
    public var iconName: String {
        switch self {
        case .original: return "photo"
        case .enhanced: return "wand.and.stars"
        case .grayscale: return "circle.lefthalf.filled"
        case .blackAndWhite: return "doc.plaintext"
        }
    }
}

public enum PDFPreset: String, CaseIterable, Codable, Identifiable {
    case original = "original"
    case high = "high"
    case balanced = "balanced"
    case small = "small"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .original: return "Original"
        case .high: return "High Quality"
        case .balanced: return "Balanced"
        case .small: return "Small File"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .original: return "Full capture resolution, max quality"
        case .high: return "2400px long side, ~90% JPEG quality"
        case .balanced: return "2000px long side, ~80% JPEG quality (Recommended)"
        case .small: return "1500px long side, single-channel 8-bit gray/B&W"
        }
    }
    
    public var targetLongSide: CGFloat {
        switch self {
        case .original: return 0 // unconstrained
        case .high: return 2400
        case .balanced: return 2000
        case .small: return 1500
        }
    }
    
    public var compressionQuality: CGFloat {
        switch self {
        case .original: return 0.95
        case .high: return 0.90
        case .balanced: return 0.82
        case .small: return 0.65
        }
    }
    
    public var estimatedSizePerPageKB: Int {
        switch self {
        case .original: return 800
        case .high: return 350
        case .balanced: return 180
        case .small: return 60
        }
    }
}

public enum PageSizeOption: String, CaseIterable, Codable, Identifiable {
    case fit = "fit"
    case a4 = "a4"
    case letter = "letter"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .fit: return "Fit to Image"
        case .a4: return "A4 (210 × 297 mm)"
        case .letter: return "US Letter (8.5 × 11 in)"
        }
    }
    
    /// Dimensions in PDF points (72 points/inch)
    public var dimensions: (width: CGFloat, height: CGFloat)? {
        switch self {
        case .fit:
            return nil
        case .a4:
            return (width: 595.28, height: 841.89)
        case .letter:
            return (width: 612.0, height: 792.0)
        }
    }
}

public enum PageStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case ready = "ready"
    case failed = "failed"
}

public enum CaptureSource: String, Codable {
    case camera = "camera"
    case photos = "photos"
    case files = "files"
}
