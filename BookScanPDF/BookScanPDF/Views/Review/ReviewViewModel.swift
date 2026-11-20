//
//  ReviewViewModel.swift
//  BookScanPDF
//
//  Coordinates project page review, multi-selection, reordering,
//  batch adjustments, page deletions, and continuing series capture.
//

import Foundation
import CoreData
import SwiftUI

public final class ReviewViewModel: ObservableObject {
    @Published public var project: Project
    @Published public var pages: [Page] = []
    @Published public var isSelectMode: Bool = false
    @Published public var selectedPageIds: Set<UUID> = []
    
    @Published public var isShowingEditor: Bool = false
    @Published public var selectedPageForEditor: Page?
    @Published public var selectedPageForSpreadSplit: Page?
    
    @Published public var isShowingCamera: Bool = false
    @Published public var retakePageId: UUID?
    @Published public var isShowingPhotosImport: Bool = false
    @Published public var isShowingDocumentImport: Bool = false
    
    @Published public var isShowingExport: Bool = false
    @Published public var isShowingSettings: Bool = false
    
    @Published public var isShowingRenameAlert: Bool = false
    @Published public var renameText: String = ""
    
    @Published public var isShowingReorderPrompt: Bool = false
    @Published public var pageToReorder: Page? = nil
    @Published public var targetPageInput: String = ""
    
    @Published public var showBatchApplyAlert: Bool = false
    @Published public var toastMessage: String? = nil
    
    private let dataController = DataController.shared
    
    public init(project: Project) {
        self.project = project
        self.renameText = project.name
        fetchPages()
        
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchPages()
        }
    }
    
    public func fetchPages() {
        let context = dataController.viewContext
        let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "projectId == %@", project.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PageEntity.orderIndex, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            self.pages = entities.map { Page(entity: $0) }
            
            // Sync pageCount
            if self.project.pageCount != self.pages.count {
                self.project.pageCount = self.pages.count
                updateProjectPageCount(self.pages.count)
            }
        } catch {
            print("[ReviewViewModel] Failed to fetch pages: \(error)")
        }
    }
    
    private func updateProjectPageCount(_ count: Int) {
        let context = dataController.viewContext
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        if let projEntity = try? context.fetch(request).first {
            projEntity.pageCount = Int32(count)
            projEntity.updatedAt = Date()
            dataController.save(context: context)
        }
    }
    
    // MARK: - Multi-Selection
    
    public func toggleSelection(for pageId: UUID) {
        if selectedPageIds.contains(pageId) {
            selectedPageIds.remove(pageId)
        } else {
            selectedPageIds.insert(pageId)
        }
    }
    
    public func selectAll() {
        if selectedPageIds.count == pages.count {
            selectedPageIds.removeAll()
        } else {
            selectedPageIds = Set(pages.map { $0.id })
        }
    }
    
    // MARK: - Reordering
    
    public func movePage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < pages.count,
              destinationIndex >= 0, destinationIndex < pages.count else { return }
        
        var reordered = pages
        let moved = reordered.remove(at: sourceIndex)
        reordered.insert(moved, at: destinationIndex)
        
        // Re-index all pages
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            for (newIndex, page) in reordered.enumerated() {
                let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", page.id as CVarArg)
                if let entity = try? bgContext.fetch(request).first {
                    entity.orderIndex = Int32(newIndex)
                }
            }
            self.dataController.save(context: bgContext)
        }
        
        fetchPages()
    }
    
    public func promptReorder(for page: Page) {
        self.pageToReorder = page
        self.targetPageInput = "\(page.orderIndex + 1)"
        self.isShowingReorderPrompt = true
    }
    
    public func executeReorder() {
        guard let page = pageToReorder,
              let targetNumber = Int(targetPageInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self.pageToReorder = nil
            return
        }
        let clampedTarget = max(1, min(pages.count, targetNumber))
        let sourceIndex = page.orderIndex
        let destinationIndex = clampedTarget - 1
        
        if sourceIndex != destinationIndex {
            movePage(from: sourceIndex, to: destinationIndex)
            showToast("Moved Page \(sourceIndex + 1) → Page \(destinationIndex + 1)")
        }
        self.pageToReorder = nil
    }
    
    // MARK: - Deletion
    
    public func deletePage(_ page: Page) {
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", page.id as CVarArg)
            if let entity = try? bgContext.fetch(request).first {
                bgContext.delete(entity)
                self.dataController.save(context: bgContext)
            }
        }
        
        DispatchQueue.global(qos: .utility).async {
            DiskStorageManager.shared.deletePageFiles(projectId: page.projectId, pageId: page.id)
        }
        
        normalizeOrderIndices()
        fetchPages()
    }
    
    public func deleteSelectedPages() {
        let idsToDelete = selectedPageIds
        guard !idsToDelete.isEmpty else { return }
        
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            for pageId in idsToDelete {
                let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
                if let entity = try? bgContext.fetch(request).first {
                    bgContext.delete(entity)
                }
            }
            self.dataController.save(context: bgContext)
        }
        
        DispatchQueue.global(qos: .utility).async {
            for pageId in idsToDelete {
                DiskStorageManager.shared.deletePageFiles(projectId: self.project.id, pageId: pageId)
            }
        }
        
        selectedPageIds.removeAll()
        isSelectMode = false
        normalizeOrderIndices()
        fetchPages()
    }
    
    private func normalizeOrderIndices() {
        let context = dataController.viewContext
        let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "projectId == %@", project.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PageEntity.orderIndex, ascending: true)]
        
        if let entities = try? context.fetch(request) {
            for (idx, entity) in entities.enumerated() {
                entity.orderIndex = Int32(idx)
            }
            dataController.save(context: context)
        }
    }
    
    // MARK: - Batch Adjustments
    
    public func batchRotateSelected(clockwise: Bool = true) {
        let delta = clockwise ? 90 : 270
        let targetIds = isSelectMode ? selectedPageIds : Set(pages.map { $0.id })
        
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            for pageId in targetIds {
                let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
                if let entity = try? bgContext.fetch(fetch).first {
                    var edit = PageEdit.decode(from: entity.editData)
                    edit.rotationDegrees = (edit.rotationDegrees + delta) % 360
                    edit.isUserModified = true
                    entity.editData = edit.encodeToData()
                    entity.status = PageStatus.pending.rawValue
                    ProcessingQueue.shared.enqueue(pageId: pageId, projectId: self.project.id, isPriority: true)
                }
            }
            self.dataController.save(context: bgContext)
        }
        showToast("Rotated \(targetIds.count) pages")
    }
    
    public func batchApplyFilter(_ filter: FilterType) {
        let targetIds = isSelectMode ? selectedPageIds : Set(pages.map { $0.id })
        
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            for pageId in targetIds {
                let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
                if let entity = try? bgContext.fetch(fetch).first {
                    var edit = PageEdit.decode(from: entity.editData)
                    edit.filter = filter
                    edit.isUserModified = true
                    entity.editData = edit.encodeToData()
                    entity.status = PageStatus.pending.rawValue
                    ProcessingQueue.shared.enqueue(pageId: pageId, projectId: self.project.id, isPriority: true)
                }
            }
            self.dataController.save(context: bgContext)
        }
        showToast("Applied \(filter.displayName) to \(targetIds.count) pages")
    }
    
    public func applyPage1SettingsToAll() {
        let count = AutoApplyManager.shared.cascadePage1Settings(
            projectId: project.id,
            forceOverwriteUserModified: true
        )
        showToast("Applied Page 1 edits to \(count) pages")
    }
    
    public func retryFailedPage(_ page: Page) {
        ProcessingQueue.shared.enqueue(pageId: page.id, projectId: project.id, isPriority: true)
        showToast("Retrying Page \(page.orderIndex + 1)...")
    }
    
    // MARK: - Renaming
    
    public func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        project.name = trimmed
        let context = dataController.viewContext
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        if let entity = try? context.fetch(request).first {
            entity.name = trimmed
            entity.updatedAt = Date()
            dataController.save(context: context)
        }
    }
    
    private func showToast(_ text: String) {
        withAnimation {
            self.toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            withAnimation {
                self?.toastMessage = nil
            }
        }
    }
}
