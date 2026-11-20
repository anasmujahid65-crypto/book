//
//  NewScanActionSheet.swift
//  BookScanPDF
//

import SwiftUI

public struct NewScanActionSheet: View {
    @Environment(\.presentationMode) var presentationMode
    public let onSelectCamera: () -> Void
    public let onSelectPhotos: () -> Void
    public let onSelectFiles: () -> Void
    
    public init(onSelectCamera: @escaping () -> Void,
                onSelectPhotos: @escaping () -> Void,
                onSelectFiles: @escaping () -> Void) {
        self.onSelectCamera = onSelectCamera
        self.onSelectPhotos = onSelectPhotos
        self.onSelectFiles = onSelectFiles
    }
    
    public var body: some View {
        VStack(spacing: Theme.spacingM) {
            // Drag indicator handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.spacingS)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Start New Scan")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.label)
                
                Text("Select your input source to begin scanning book pages.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Theme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.spacingL)
            .padding(.top, Theme.spacingS)
            
            VStack(spacing: Theme.spacingM) {
                ActionRowButton(
                    title: "Live Camera Series",
                    subtitle: "Continuous capture with live green edge indicator",
                    iconName: "camera.viewfinder",
                    accentColor: Theme.primaryLight
                ) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectCamera()
                }
                
                ActionRowButton(
                    title: "Import from Photos",
                    subtitle: "Select multiple page photos from your photo library",
                    iconName: "photo.on.rectangle.angled",
                    accentColor: Theme.accent
                ) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectPhotos()
                }
                
                ActionRowButton(
                    title: "Import from Files",
                    subtitle: "Import images or scanned folders from iCloud / Files",
                    iconName: "folder.badge.plus",
                    accentColor: Theme.primary
                ) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectFiles()
                }
            }
            .padding(.horizontal, Theme.spacingL)
            
            Spacer()
        }
        .padding(.bottom, Theme.spacingXL)
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct ActionRowButton: View {
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.label)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.secondaryLabel)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.tertiaryLabel)
            }
            .padding(Theme.spacingM)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
