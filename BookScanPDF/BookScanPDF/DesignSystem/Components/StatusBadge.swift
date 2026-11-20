//
//  StatusBadge.swift
//  BookScanPDF
//

import SwiftUI

public struct StatusBadge: View {
    public let text: String
    public let icon: String?
    public let color: Color
    
    public init(text: String, icon: String? = nil, color: Color = Theme.primary) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}
