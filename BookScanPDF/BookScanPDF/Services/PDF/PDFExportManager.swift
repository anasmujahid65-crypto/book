//
//  PDFExportManager.swift
//  BookScanPDF
//
//  Coordinates background PDF generation jobs, UI background task tokens,
//  idle timer locks, progress dispatch, and PDFKit integrity verification.
//

import UIKit
import CoreData
import PDFKit

public struct PDFExportResult {
    public let fileURL: URL
    public let fileSizeFormatted: String
    public let pageCount: Int
    public let durationSeconds: Double
}

public final class PDFExportManager: ObservableObject {
    public static let shared = PDFExportManager()
    
    @Published public var isExporting: Bool = false
    @Published public var currentPage: Int = 0
    @Published public var totalPages: Int = 0
    @Published public var estimatedSecondsRemaining: Double = 0
    
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private let dataController = DataController.shared
    
    private init() {}
    
    public func exportProject(
        project: Project,
        filename: String,
        pageSizeOption: PageSizeOption,
        ocrEnabled: Bool = false,
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<PDFExportResult, Error>) -> Void
    ) {
        let startTime = CACurrentMediaTime()
        self.isExporting = true
        self.currentPage = 0
        
        // Prevent screen sleep during large 500-page export
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        // Begin iOS Background Task
        self.backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "com.bookscan.pdf.export") { [weak self] in
            self?.endBackgroundTask()
        }
        
        Task {
            do {
                // 1. Fetch all project pages in sequential order
                let context = self.dataController.viewContext
                let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                request.predicate = NSPredicate(format: "projectId == %@", project.id as CVarArg)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \PageEntity.orderIndex, ascending: true)]
                
                let entities = try context.fetch(request)
                guard !entities.isEmpty else {
                    throw NSError(domain: "com.bookscan.pdf", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project contains no pages to export."])
                }
                
                let pageFilePaths: [URL] = entities.compactMap { entity in
                    let path = entity.processedPath ?? entity.originalPath
                    return URL(fileURLWithPath: path)
                }
                
                await MainActor.run {
                    self.totalPages = pageFilePaths.count
                }
                
                // 2. Prepare destination URL in sandboxed exports/ folder
                let cleanFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
                let destinationURL = DiskStorageManager.shared.exportPDFPath(
                    projectId: project.id,
                    filename: cleanFilename.isEmpty ? "BookScan" : cleanFilename
                )
                
                // 3. Stream PDF to disk page-by-page
                let writer = PDFStreamingWriter(destinationURL: destinationURL)
                try await writer.writePDF(
                    pageURLs: pageFilePaths,
                    pageSizeOption: pageSizeOption,
                    ocrEnabled: ocrEnabled
                ) { current, total in
                    DispatchQueue.main.async {
                        self.currentPage = current
                        let elapsed = CACurrentMediaTime() - startTime
                        let avgPerPage = elapsed / Double(max(1, current))
                        self.estimatedSecondsRemaining = max(0, avgPerPage * Double(total - current))
                        progress(current, total)
                    }
                }
                
                // 4. Integrity Verification: Confirm PDF validity using PDFKit
                guard let verifiedPDF = PDFDocument(url: destinationURL), verifiedPDF.pageCount == pageFilePaths.count else {
                    throw NSError(domain: "com.bookscan.pdf", code: -2, userInfo: [NSLocalizedDescriptionKey: "PDF integrity validation failed: generated page count mismatch."])
                }
                
                // 5. Calculate file size & finalize
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                let duration = CACurrentMediaTime() - startTime
                
                let result = PDFExportResult(
                    fileURL: destinationURL,
                    fileSizeFormatted: formattedSize,
                    pageCount: verifiedPDF.pageCount,
                    durationSeconds: duration
                )
                
                await MainActor.run {
                    self.isExporting = false
                    self.endBackgroundTask()
                    completion(.success(result))
                }
                
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.endBackgroundTask()
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func endBackgroundTask() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}
