//
//  PageEdit.swift
//  BookScanPDF
//

import Foundation
import CoreGraphics

public struct NormalizedQuad: Codable, Equatable {
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomRight: CGPoint
    public var bottomLeft: CGPoint
    
    public init(topLeft: CGPoint = CGPoint(x: 0, y: 1),
                topRight: CGPoint = CGPoint(x: 1, y: 1),
                bottomRight: CGPoint = CGPoint(x: 1, y: 0),
                bottomLeft: CGPoint = CGPoint(x: 0, y: 0)) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }
    
    public static var defaultUnitSquare: NormalizedQuad {
        return NormalizedQuad(
            topLeft: CGPoint(x: 0, y: 1),
            topRight: CGPoint(x: 1, y: 1),
            bottomRight: CGPoint(x: 1, y: 0),
            bottomLeft: CGPoint(x: 0, y: 0)
        )
    }
}

public struct PageEdit: Codable, Equatable {
    public var cropCorners: NormalizedQuad?
    public var filter: FilterType
    public var rotationDegrees: Int // 0, 90, 180, 270
    public var fineStraightenAngle: Double // -10.0 to +10.0
    public var brightness: Float // -0.5 to +0.5, 0.0 default
    public var contrast: Float // 0.5 to 1.5, 1.0 default
    public var isUserModified: Bool
    
    public init(cropCorners: NormalizedQuad? = nil,
                filter: FilterType? = nil,
                rotationDegrees: Int = 0,
                fineStraightenAngle: Double = 0.0,
                brightness: Float = 0.0,
                contrast: Float = 1.0,
                isUserModified: Bool = false) {
        self.cropCorners = cropCorners
        self.filter = filter ?? AppSettings.shared.defaultFilter
        self.rotationDegrees = rotationDegrees
        self.fineStraightenAngle = fineStraightenAngle
        self.brightness = brightness
        self.contrast = contrast
        self.isUserModified = isUserModified
    }
    
    public static var `default`: PageEdit {
        return PageEdit(
            cropCorners: nil,
            filter: AppSettings.shared.defaultFilter,
            rotationDegrees: 0,
            fineStraightenAngle: 0.0,
            brightness: 0.0,
            contrast: 1.0,
            isUserModified: false
        )
    }
    
    public func encodeToData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    public static func decode(from data: Data?) -> PageEdit {
        guard let data = data,
              let edit = try? JSONDecoder().decode(PageEdit.self, from: data) else {
            return .default
        }
        return edit
    }
}
