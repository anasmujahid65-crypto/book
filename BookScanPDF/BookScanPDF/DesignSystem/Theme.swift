//
//  Theme.swift
//  BookScanPDF
//
//  Design system colors, typography, elevations, and layout metrics.
//  Fully compatible with iOS 15.0+ and supports Dynamic Type & Dark Mode.
//

import SwiftUI

public enum Theme {
    // MARK: - Brand Palette
    public static let primary = Color(red: 0.12, green: 0.22, blue: 0.44)       // Deep Indigo
    public static let primaryLight = Color(red: 0.22, green: 0.38, blue: 0.68)  // Medium Indigo
    public static let accent = Color(red: 0.95, green: 0.52, blue: 0.20)        // Warm Amber/Orange
    
    // Status Colors
    public static let successGreen = Color(red: 0.18, green: 0.80, blue: 0.44)  // Page OK Green
    public static let warningAmber = Color(red: 0.96, green: 0.71, blue: 0.18)  // Warning/Almost Amber
    public static let errorRed = Color(red: 0.92, green: 0.26, blue: 0.26)      // Error/Cutoff Red
    
    // Neutrals
    public static let background = Color(UIColor.systemBackground)
    public static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    public static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    public static let groupBackground = Color(UIColor.systemGroupedBackground)
    
    public static let label = Color(UIColor.label)
    public static let secondaryLabel = Color(UIColor.secondaryLabel)
    public static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    
    public static let cardBorder = Color(UIColor.separator).opacity(0.4)
    
    // MARK: - Radii & Spacing
    public static let cornerRadiusSmall: CGFloat = 8
    public static let cornerRadiusMedium: CGFloat = 16
    public static let cornerRadiusLarge: CGFloat = 24
    
    public static let spacingXS: CGFloat = 4
    public static let spacingS: CGFloat = 8
    public static let spacingM: CGFloat = 16
    public static let spacingL: CGFloat = 24
    public static let spacingXL: CGFloat = 32
    
    // MARK: - Shadows
    public static func cardShadow<V: View>(_ view: V) -> some View {
        view.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    public static func floatingShadow<V: View>(_ view: V) -> some View {
        view.shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}
