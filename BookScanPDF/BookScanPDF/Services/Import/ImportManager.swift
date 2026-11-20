//
//  ImportManager.swift
//  BookScanPDF
//
//  Orchestrates batch importing from Photos and Files into a project.
//  Enforces memory bounds by streaming file representations directly into sandboxed storage.
//

import Foundation
import SwiftUI
import CoreData

public final class ImportManager: ObservableObject {
    public static let shared = ImportManager()
    
    @Published public var isImporting: Bool = false
    @Published public var currentProgress: Int = 0
    @Published public var totalCount: Int = 0
    @Published public var currentProjectName: String = ""
    
    private var isCancelled = false
    private let dataController = DataController.shared
    
    private init() {}
    
    public func importFiles(
        urls: [URL],
        into project: Project,
        source: CaptureSource = .photos,
        completion: @escaping (Int) -> Void
    ) {
        guard !urls.isEmpty else {
            completion(0)
            return
        }
        
        self.isCancelled = false
        self.isImporting = true
        self.currentProgress = 0
        self.totalCount = urls.count
        self.currentProjectName = project.name
        
        Task {
            var successfullyImported = 0
            let startIndex = project.pageCount
            
            for (idx, fileURL) in urls.enumerated() {
                guard !self.isCancelled else { break }
                
                let pageId = UUID()
                let targetOrder = startIndex + idx
                
                do {
                    // Read data from temporary file
                    let fileData = try Data(contentsOf: fileURL, options: .alwaysMapped)
                    
                    // Write directly to disk-first sandboxed original storage
                    let originalPath = try DiskStorageManager.shared.writeOriginalData(
                        fileData,
                        projectId: project.id,
                        pageId: pageId
                    )
                    
                    // Downsample lightweight thumbnail
                    var thumbPath: String? = nil
                    if let thumbImg = ImageDownsampler.downsample(imageData: fileData, maxDimension: 140),
                       let thumbData = thumbImg.jpegData(compressionQuality: 0.70) {
                        thumbPath = try? DiskStorageManager.shared.writeThumbData(
                            thumbData,
                            projectId: project.id,
                            pageId: pageId
                        )
                    }
                    
                    // Create Core Data entity on background context
                    let bgContext = self.dataController.newBackgroundContext()
                    bgContext.performAndWait {
                        let pageEntity = PageEntity(context: bgContext)
                        pageEntity.id = pageId
                        pageEntity.projectId = project.id
                        pageEntity.orderIndex = Int32(targetOrder)
                        pageEntity.originalPath = originalPath
                        pageEntity.thumbPath = thumbPath
                        pageEntity.status = PageStatus.pending.rawValue
                        pageEntity.source = source.rawValue
                        pageEntity.createdAt = Date()
                        pageEntity.isSplitChild = false
                        pageEntity.editData = PageEdit.default.encodeToData()
                        
                        let projFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                        projFetch.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
                        if let projEntity = try? bgContext.fetch(projFetch).first {
                            pageEntity.project = projEntity
                            projEntity.pageCount = Int32(targetOrder + 1)
                            projEntity.updatedAt = Date()
                            if projEntity.coverThumbPath == nil {
                                projEntity.coverThumbPath = thumbPath
                            }
                        }
                        
                        self.dataController.save(context: bgContext)
                    }
                    
                    // Enqueue for background perspective correction & filter cascade
                    ProcessingQueue.shared.enqueue(pageId: pageId, projectId: project.id)
                    successfullyImported += 1
                    
                    // Remove temporary import file
                    try? FileManager.default.removeItem(at: fileURL)
                    
                } catch {
                    print("[ImportManager] Failed to import file \(fileURL.lastPathComponent): \(error)")
                }
                
                await MainActor.run {
                    self.currentProgress = idx + 1
                }
            }
            
            await MainActor.run {
                self.isImporting = false
                completion(successfullyImported)
            }
        }
    }
    
    public func cancel() {
        self.isCancelled = true
        self.isImporting = false
    }
}
