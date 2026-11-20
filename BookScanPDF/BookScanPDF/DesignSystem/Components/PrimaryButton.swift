//
//  PrimaryButton.swift
//  BookScanPDF
//

import SwiftUI

public enum ButtonVariant {
    case primary
    case accent
    case secondary
    case destructive
}

public struct PrimaryButton: View {
    public let title: String
    public let icon: String?
    public let variant: ButtonVariant
    public let isLoading: Bool
    public let action: () -> Void
    
    public init(title: String,
                icon: String? = nil,
                variant: ButtonVariant = .primary,
                isLoading: Bool = false,
                action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingS) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.9)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .contentShape(Rectangle())
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary, .accent, .destructive:
            return .white
        case .secondary:
            return Theme.label
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [Theme.primaryLight, Theme.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accent:
            LinearGradient(
                colors: [Theme.accent, Theme.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Theme.secondaryBackground
        case .destructive:
            Theme.errorRed
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .secondary:
            return Theme.cardBorder
        default:
            return Color.clear
        }
    }
}
