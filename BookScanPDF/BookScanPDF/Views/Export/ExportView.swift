//
//  ExportView.swift
//  BookScanPDF
//
//  Full-featured PDF export screen with quality presets, estimated file sizes,
//  progress indicators, in-app PDFKit preview, and system sharing/Files export.
//

import SwiftUI

public struct ExportView: View {
    @StateObject private var viewModel: ExportViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public init(project: Project) {
        _viewModel = StateObject(wrappedValue: ExportViewModel(project: project))
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if let result = viewModel.exportResult {
                    // MARK: - Export Success Screen
                    ExportSuccessView(
                        result: result,
                        filename: viewModel.filename,
                        onPreview: { viewModel.isShowingPreview = true },
                        onShare: { viewModel.isShowingShareSheet = true },
                        onSaveToFiles: { viewModel.isShowingSaveToFiles = true },
                        onDone: { presentationMode.wrappedValue.dismiss() }
                    )
                } else {
                    // MARK: - Export Configuration Form
                    ScrollView {
                        VStack(spacing: Theme.spacingL) {
                            // Filename Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("File Name")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.secondaryLabel)
                                
                                HStack {
                                    TextField("Document Name", text: $viewModel.filename)
                                        .font(.system(size: 16, weight: .medium))
                                    Text(".pdf")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Theme.secondaryLabel)
                                }
                                .padding(Theme.spacingM)
                                .background(Theme.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                            }
                            
                            // Quality Presets
                            VStack(alignment: .leading, spacing: Theme.spacingM) {
                                HStack {
                                    Text("Quality Preset")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.secondaryLabel)
                                    Spacer()
                                    Text("Est. Size: \(viewModel.estimatedFileSizeString)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.accent)
                                }
                                
                                VStack(spacing: Theme.spacingS) {
                                    ForEach(PDFPreset.allCases) { preset in
                                        PresetSelectionCard(
                                            preset: preset,
                                            isSelected: viewModel.selectedPreset == preset,
                                            pageCount: viewModel.project.pageCount
                                        ) {
                                            viewModel.selectedPreset = preset
                                        }
                                    }
                                }
                            }
                            
                            // Page Dimensions
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page Dimensions")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.secondaryLabel)
                                
                                Picker("Page Size", selection: $viewModel.selectedPageSize) {
                                    ForEach(PageSizeOption.allCases) { size in
                                        Text(size.displayName).tag(size)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // Searchable Text Layer (OCR)
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $viewModel.ocrEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Searchable OCR Text Layer")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(Theme.label)
                                        Text("On-device Latin text recognition. Enables copy/paste and keyword search in PDF viewers.")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.secondaryLabel)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                            }
                            .padding(Theme.spacingM)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                            
                            // Error Message
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.errorRed)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Primary Export CTA
                            PrimaryButton(
                                title: "Generate PDF (\(viewModel.estimatedFileSizeString))",
                                icon: "arrow.up.doc.fill",
                                variant: .accent,
                                isLoading: viewModel.isExporting
                            ) {
                                viewModel.startExport()
                            }
                            .padding(.top, Theme.spacingM)
                        }
                        .padding(Theme.spacingL)
                    }
                }
                
                // MARK: - Exporting Progress Modal
                if viewModel.isExporting {
                    ExportProgressOverlay(
                        currentPage: viewModel.exportCurrentPage,
                        totalPages: viewModel.exportTotalPages
                    )
                }
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.exportResult == nil && !viewModel.isExporting {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(Theme.secondaryLabel)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingPreview) {
                if let url = viewModel.exportResult?.fileURL {
                    NavigationView {
                        PDFPreviewView(documentURL: url)
                            .navigationTitle(viewModel.filename)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        viewModel.isShowingPreview = false
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingShareSheet) {
                if let url = viewModel.exportResult?.fileURL {
                    ActivityShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $viewModel.isShowingSaveToFiles) {
                if let url = viewModel.exportResult?.fileURL {
                    ExportDocumentPicker(fileURL: url) {
                        viewModel.isShowingSaveToFiles = false
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Preset Selection Card
private struct PresetSelectionCard: View {
    let preset: PDFPreset
    let isSelected: Bool
    let pageCount: Int
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.spacingM) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.label)
                        
                        if preset == .balanced {
                            StatusBadge(text: "Recommended", color: Theme.successGreen)
                        }
                    }
                    
                    Text(preset.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Theme.secondaryLabel)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("~\(pageCount * preset.estimatedSizePerPageKB / 1024) MB")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? Theme.accent : Theme.secondaryLabel)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Theme.accent : Theme.tertiaryLabel)
            }
            .padding(Theme.spacingM)
            .background(isSelected ? Theme.accent.opacity(0.08) : Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Export Success View
private struct ExportSuccessView: View {
    let result: PDFExportResult
    let filename: String
    let onPreview: () -> Void
    let onShare: () -> Void
    let onSaveToFiles: () -> Void
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.spacingXL) {
            Spacer()
            
            // Checkmark Illustration
            ZStack {
                Circle()
                    .fill(Theme.successGreen.opacity(0.14))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Theme.successGreen)
            }
            
            VStack(spacing: 8) {
                Text("PDF Generated Successfully!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.label)
                
                Text("\(filename).pdf")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.secondaryLabel)
                
                HStack(spacing: 12) {
                    StatusBadge(text: "\(result.pageCount) Pages", icon: "doc.fill", color: Theme.primaryLight)
                    StatusBadge(text: result.fileSizeFormatted, icon: "arrow.down.circle.fill", color: Theme.accent)
                    StatusBadge(text: String(format: "%.1fs", result.durationSeconds), icon: "stopwatch.fill", color: Theme.secondaryLabel)
                }
                .padding(.top, 4)
            }
            
            // Action Buttons Dock
            VStack(spacing: Theme.spacingM) {
                PrimaryButton(title: "Share PDF", icon: "square.and.arrow.up", variant: .accent, action: onShare)
                
                PrimaryButton(title: "Open & Preview", icon: "eye", variant: .secondary, action: onPreview)
                
                PrimaryButton(title: "Save to Files", icon: "folder", variant: .secondary, action: onSaveToFiles)
                
                Button("Done", action: onDone)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.secondaryLabel)
                    .padding(.top, 8)
            }
            .padding(.horizontal, Theme.spacingXL)
            
            Spacer()
        }
    }
}

// MARK: - Export Progress Overlay
private struct ExportProgressOverlay: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            
            VStack(spacing: Theme.spacingL) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 76, height: 76)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        .scaleEffect(1.3)
                }
                
                VStack(spacing: 6) {
                    Text("Streaming PDF...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.label)
                    
                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.secondaryLabel)
                }
                
                ProgressView(value: Double(currentPage), total: Double(max(1, totalPages)))
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(x: 1, y: 2)
                    .padding(.horizontal, Theme.spacingL)
                
                Text("Please keep the app open. Screen will remain awake.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.tertiaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.spacingXL)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, Theme.spacingXL)
        }
    }
}
