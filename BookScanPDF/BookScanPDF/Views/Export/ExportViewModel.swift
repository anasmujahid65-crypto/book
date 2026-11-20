//
//  ExportViewModel.swift
//  BookScanPDF
//
//  Manages PDF export configuration, presets, live size calculations,
//  and post-generation sharing states.
//

import Foundation
import SwiftUI

public final class ExportViewModel: ObservableObject {
    public let project: Project
    
    @Published public var filename: String
    @Published public var selectedPreset: PDFPreset
    @Published public var selectedPageSize: PageSizeOption
    @Published public var ocrEnabled: Bool
    
    @Published public var isExporting: Bool = false
    @Published public var exportCurrentPage: Int = 0
    @Published public var exportTotalPages: Int = 0
    @Published public var exportResult: PDFExportResult? = nil
    @Published public var errorMessage: String? = nil
    
    @Published public var isShowingPreview: Bool = false
    @Published public var isShowingShareSheet: Bool = false
    @Published public var isShowingSaveToFiles: Bool = false
    
    public init(project: Project) {
        self.project = project
        self.filename = project.name
        self.selectedPreset = project.pdfPreset
        self.selectedPageSize = project.pageSize
        self.ocrEnabled = project.ocrEnabled || AppSettings.shared.ocrEnabledDefault
        self.exportTotalPages = project.pageCount
    }
    
    public var estimatedFileSizeString: String {
        let totalKB = project.pageCount * selectedPreset.estimatedSizePerPageKB
        if totalKB >= 1024 {
            let mb = Double(totalKB) / 1024.0
            return String(format: "~%.1f MB", mb)
        } else {
            return "~\(totalKB) KB"
        }
    }
    
    public func startExport() {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = nil
        
        PDFExportManager.shared.exportProject(
            project: project,
            filename: filename,
            pageSizeOption: selectedPageSize,
            ocrEnabled: ocrEnabled
        ) { [weak self] current, total in
            DispatchQueue.main.async {
                self?.exportCurrentPage = current
                self?.exportTotalPages = total
            }
        } completion: { [weak self] result in
            DispatchQueue.main.async {
                self?.isExporting = false
                switch result {
                case .success(let exportResult):
                    self?.exportResult = exportResult
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
