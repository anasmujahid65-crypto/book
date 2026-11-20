//
//  ImportProgressView.swift
//  BookScanPDF
//
//  Displays real-time batch import progress for multi-selected Photos and Files.
//

import SwiftUI

public struct ImportProgressView: View {
    @ObservedObject var importManager = ImportManager.shared
    public let onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            
            VStack(spacing: Theme.spacingL) {
                // Book Stack Graphic
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.accent)
                }
                
                VStack(spacing: 6) {
                    Text("Importing Book Pages")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.label)
                    
                    Text("\(importManager.currentProgress) of \(importManager.totalCount) pages imported")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryLabel)
                }
                
                // Progress Bar
                VStack(spacing: 8) {
                    ProgressView(value: progressRatio)
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    HStack {
                        Text("\(Int(progressRatio * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.tertiaryLabel)
                        Spacer()
                    }
                }
                .padding(.horizontal, Theme.spacingM)
                
                // Cancel Action
                Button(action: {
                    importManager.cancel()
                    onDismiss()
                }) {
                    Text("Cancel Import")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.errorRed)
                        .padding(.vertical, 8)
                }
            }
            .padding(Theme.spacingXL)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, Theme.spacingL)
        }
    }
    
    private var progressRatio: Double {
        guard importManager.totalCount > 0 else { return 0.0 }
        return Double(importManager.currentProgress) / Double(importManager.totalCount)
    }
}
