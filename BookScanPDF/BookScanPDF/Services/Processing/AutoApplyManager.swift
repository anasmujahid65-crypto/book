//
//  AutoApplyManager.swift
//  BookScanPDF
//
//  Manages the cascade of Page 1 filter, rotation, brightness, and contrast settings
//  across hundreds of subsequent book pages.
//

import Foundation
import CoreData

public final class AutoApplyManager {
    public static let shared = AutoApplyManager()
    
    private let dataController = DataController.shared
    
    private init() {}
    
    /// Updates all subsequent pages in the project to match Page 1's edits.
    /// Pages with `isUserModified == true` are preserved unless forced.
    @discardableResult
    public func cascadePage1Settings(
        projectId: UUID,
        forceOverwriteUserModified: Bool = false
    ) -> Int {
        guard AppSettings.shared.autoApplyPage1Settings else { return 0 }
        
        let bgContext = dataController.newBackgroundContext()
        var updatedCount = 0
        
        bgContext.performAndWait {
            // 1. Fetch Page 1 (orderIndex == 0)
            let page1Fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            page1Fetch.predicate = NSPredicate(format: "projectId == %@ AND orderIndex == 0", projectId as CVarArg)
            
            guard let page1 = try? bgContext.fetch(page1Fetch).first,
                  let page1EditData = page1.editData else {
                return
            }
            let page1Edit = PageEdit.decode(from: page1EditData)
            
            // 2. Update Project referenceEditData
            let projFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projFetch.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
            if let project = try? bgContext.fetch(projFetch).first {
                project.referenceEditData = page1EditData
                project.updatedAt = Date()
            }
            
            // 3. Fetch subsequent pages
            let pagesFetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            pagesFetch.predicate = NSPredicate(format: "projectId == %@ AND orderIndex > 0", projectId as CVarArg)
            
            guard let pages = try? bgContext.fetch(pagesFetch) else { return }
            
            let reuseCrop = AppSettings.shared.reusePage1CropArea
            var pageIdsToReProcess: [UUID] = []
            
            for page in pages {
                var currentEdit = PageEdit.decode(from: page.editData)
                if !currentEdit.isUserModified || forceOverwriteUserModified {
                    // Cascade parameters
                    currentEdit.filter = page1Edit.filter
                    currentEdit.rotationDegrees = page1Edit.rotationDegrees
                    currentEdit.fineStraightenAngle = page1Edit.fineStraightenAngle
                    currentEdit.brightness = page1Edit.brightness
                    currentEdit.contrast = page1Edit.contrast
                    
                    if reuseCrop && page1Edit.cropCorners != nil {
                        currentEdit.cropCorners = page1Edit.cropCorners
                    }
                    
                    page.editData = currentEdit.encodeToData()
                    page.status = PageStatus.pending.rawValue
                    pageIdsToReProcess.append(page.id)
                    updatedCount += 1
                }
            }
            
            self.dataController.save(context: bgContext)
            
            // Re-enqueue updated pages for processing
            for id in pageIdsToReProcess {
                ProcessingQueue.shared.enqueue(pageId: id, projectId: projectId)
            }
        }
        
        return updatedCount
    }
}
