//
//  EmptyStateView.swift
//  BookScanPDF
//

import SwiftUI

public struct EmptyStateView: View {
    public let title: String
    public let message: String
    public let systemImage: String
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public init(title: String,
                message: String,
                systemImage: String,
                actionTitle: String? = nil,
                action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: Theme.spacingM) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 96, height: 96)
                
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .regular))
                    .foregroundColor(Theme.primaryLight)
            }
            .padding(.bottom, Theme.spacingS)
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.label)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacingXL)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top, Theme.spacingS)
            }
        }
        .padding(Theme.spacingXL)
    }
}
