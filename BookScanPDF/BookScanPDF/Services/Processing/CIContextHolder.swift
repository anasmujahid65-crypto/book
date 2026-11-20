//
//  CIContextHolder.swift
//  BookScanPDF
//
//  Maintains a shared, high-performance Metal-backed CIContext created once.
//  Configured with disabled intermediate caching to preserve RAM on 3 GB devices.
//

import CoreImage
import Metal

public final class CIContextHolder {
    public static let shared = CIContextHolder()
    
    public let context: CIContext
    public let colorSpaceRGB: CGColorSpace
    public let colorSpaceGray: CGColorSpace
    
    private init() {
        let rgb = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let gray = CGColorSpace(name: CGColorSpace.extendedLinearGray) ?? CGColorSpaceCreateDeviceGray()
        
        self.colorSpaceRGB = rgb
        self.colorSpaceGray = gray
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            let options: [CIContextOption: Any] = [
                .workingColorSpace: rgb,
                .cacheIntermediates: false, // Prevents GPU texture memory leaks on iOS 15
                .useSoftwareRenderer: false
            ]
            self.context = CIContext(mtlDevice: metalDevice, options: options)
        } else {
            // Software fallback for simulator / non-metal environments
            self.context = CIContext(options: [
                .workingColorSpace: rgb,
                .cacheIntermediates: false
            ])
        }
    }
}
