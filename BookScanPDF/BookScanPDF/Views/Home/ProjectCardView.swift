//
//  ProjectCardView.swift
//  BookScanPDF
//

import SwiftUI

public struct ProjectCardView: View {
    public let project: Project
    public let onTap: () -> Void
    public let onRename: () -> Void
    public let onDuplicate: () -> Void
    public let onDelete: () -> Void
    
    @State private var coverImage: UIImage? = nil
    
    public init(project: Project,
                onTap: @escaping () -> Void,
                onRename: @escaping () -> Void,
                onDuplicate: @escaping () -> Void,
                onDelete: @escaping () -> Void) {
        self.project = project
        self.onTap = onTap
        self.onRename = onRename
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail Box
                ZStack {
                    Theme.tertiaryBackground
                    
                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 34, weight: .light))
                                .foregroundColor(Theme.secondaryLabel)
                            Text(project.pageCount == 0 ? "Empty Scan" : "\(project.pageCount) Pages")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.tertiaryLabel)
                        }
                    }
                }
                .frame(height: 160)
                .clipped()
                
                // Metadata Box
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.label)
                        .lineLimit(1)
                    
                    HStack {
                        Text("\(project.pageCount) pages")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryLabel)
                        
                        Spacer()
                        
                        Text(formattedDate(project.updatedAt))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Theme.tertiaryLabel)
                    }
                    
                    if project.pageCount > 0 {
                        HStack(spacing: 4) {
                            StatusBadge(
                                text: estimatedSizeString,
                                icon: "doc.fill",
                                color: Theme.primaryLight
                            )
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(Theme.spacingM)
                .background(Theme.secondaryBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .modifier(CardShadowModifier())
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private var estimatedSizeString: String {
        let sizeKB = project.pageCount * project.pdfPreset.estimatedSizePerPageKB
        if sizeKB >= 1024 {
            let mb = Double(sizeKB) / 1024.0
            return String(format: "%.1f MB", mb)
        } else {
            return "\(sizeKB) KB"
        }
    }
    
    private func loadThumbnail() {
        guard coverImage == nil, let path = project.coverThumbPath else { return }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            if let thumb = ImageDownsampler.downsample(imageAt: url, maxDimension: 320) {
                DispatchQueue.main.async {
                    self.coverImage = thumb
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        Theme.cardShadow(content)
    }
}
