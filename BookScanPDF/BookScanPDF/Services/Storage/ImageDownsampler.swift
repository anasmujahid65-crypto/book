//
//  ImageDownsampler.swift
//  BookScanPDF
//
//  Decodes images at specified maximum pixel sizes using ImageIO (CGImageSourceCreateThumbnailAtIndex).
//  Guarantees memory protection on low-RAM devices (iPhone 7 Plus 3GB) by never inflating
//  full 12MP images (48MB uncompressed) into RAM for UI thumbnails or previews.
//

import UIKit
import ImageIO

public final class ImageDownsampler {
    
    /// Downsamples an image from a file URL to a target maximum pixel dimension.
    /// Memory consumption is proportional only to the downsampled target dimension.
    public static func downsample(imageAt imageURL: URL, maxDimension: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    /// Downsamples an image from raw Data to a target maximum pixel dimension.
    public static func downsample(imageData: Data, maxDimension: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    /// Quick dimensions read without decoding pixel data into memory
    public static func readImageDimensions(at imageURL: URL) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
