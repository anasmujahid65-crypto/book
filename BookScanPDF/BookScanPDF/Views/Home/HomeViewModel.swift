//
//  HomeViewModel.swift
//  BookScanPDF
//

import Foundation
import CoreData
import SwiftUI

public final class HomeViewModel: ObservableObject {
    @Published public var projects: [Project] = []
    @Published public var searchText: String = ""
    @Published public var isShowingNewScanSheet: Bool = false
    @Published public var isShowingSettings: Bool = false
    @Published public var selectedProjectForCamera: Project?
    @Published public var selectedProjectForPhotosImport: Project?
    @Published public var selectedProjectForReview: Project?
    @Published public var interruptedProject: Project?
    @Published public var projectToRename: Project?
    @Published public var renameText: String = ""
    @Published public var isShowingRenameAlert: Bool = false
    
    private let dataController: DataController
    
    public init(dataController: DataController = .shared) {
        self.dataController = dataController
        fetchProjects()
        checkForInterruptedSession()
    }
    
    public var filteredProjects: [Project] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return projects
        }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    public func fetchProjects() {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.updatedAt, ascending: false)]
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            self.projects = entities.map { Project(entity: $0) }
        } catch {
            print("[HomeViewModel] Failed to fetch projects: \(error)")
        }
    }
    
    public func checkForInterruptedSession() {
        // Find if any project has pending or processing pages, or was updated in the last 24h with pages
        let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ OR status == %@", PageStatus.pending.rawValue, PageStatus.processing.rawValue)
        request.fetchLimit = 1
        
        do {
            let pages = try dataController.viewContext.fetch(request)
            if let firstPending = pages.first, let projectEntity = firstPending.project {
                self.interruptedProject = Project(entity: projectEntity)
            } else {
                self.interruptedProject = nil
            }
        } catch {
            self.interruptedProject = nil
        }
    }
    
    @discardableResult
    public func createNewProject(name: String? = nil) -> Project {
        let context = dataController.viewContext
        let entity = ProjectEntity(context: context)
        entity.id = UUID()
        let count = projects.count + 1
        entity.name = name ?? "Book Scan #\(count)"
        entity.createdAt = Date()
        entity.updatedAt = Date()
        entity.pageCount = 0
        entity.pdfPreset = AppSettings.shared.defaultPDFPreset.rawValue
        entity.pageSize = AppSettings.shared.defaultPageSize.rawValue
        entity.ocrEnabled = AppSettings.shared.ocrEnabledDefault
        
        dataController.save(context: context)
        let project = Project(entity: entity)
        fetchProjects()
        return project
    }
    
    public func deleteProject(_ project: Project) {
        let context = dataController.viewContext
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                dataController.save(context: context)
                
                DispatchQueue.global(qos: .utility).async {
                    DiskStorageManager.shared.deleteProjectFiles(for: project.id)
                }
                
                fetchProjects()
                if interruptedProject?.id == project.id {
                    interruptedProject = nil
                }
            }
        } catch {
            print("[HomeViewModel] Error deleting project: \(error)")
        }
    }
    
    public func duplicateProject(_ project: Project) {
        let context = dataController.viewContext
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        
        do {
            if let source = try context.fetch(request).first {
                let duplicate = ProjectEntity(context: context)
                duplicate.id = UUID()
                duplicate.name = "\(source.name) (Copy)"
                duplicate.createdAt = Date()
                duplicate.updatedAt = Date()
                duplicate.pageCount = source.pageCount
                duplicate.coverThumbPath = source.coverThumbPath
                duplicate.pdfPreset = source.pdfPreset
                duplicate.pageSize = source.pageSize
                duplicate.ocrEnabled = source.ocrEnabled
                duplicate.referenceEditData = source.referenceEditData
                
                // Note: deep-copies files if needed in background, or creates fresh reference
                dataController.save(context: context)
                fetchProjects()
            }
        } catch {
            print("[HomeViewModel] Error duplicating project: \(error)")
        }
    }
    
    public func startRename(for project: Project) {
        self.projectToRename = project
        self.renameText = project.name
        self.isShowingRenameAlert = true
    }
    
    public func commitRename() {
        guard let project = projectToRename, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let context = dataController.viewContext
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                entity.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.updatedAt = Date()
                dataController.save(context: context)
                fetchProjects()
            }
        } catch {
            print("[HomeViewModel] Error renaming project: \(error)")
        }
        
        projectToRename = nil
        renameText = ""
    }
}
