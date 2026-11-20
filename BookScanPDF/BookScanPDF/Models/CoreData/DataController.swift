//
//  DataController.swift
//  BookScanPDF
//
//  Manages Core Data stack for BookScan PDF.
//  Optimized for iOS 15.0+ with background context operations and thread-safe persistence.
//

import Foundation
import CoreData

public final class DataController: ObservableObject {
    public static let shared = DataController()
    
    public let container: NSPersistentContainer
    
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    public init(inMemory: Bool = false) {
        let model = BookScanModel.sharedModel
        let container = NSPersistentContainer(name: BookScanModel.modelName, managedObjectModel: model)
        
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
                let storeURL = appSupport.appendingPathComponent("BookScanPDF.sqlite")
                let description = NSPersistentStoreDescription(url: storeURL)
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [description]
            }
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data persistent store: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.container = container
    }
    
    /// Thread-safe context save
    public func save(context: NSManagedObjectContext? = nil) {
        let ctx = context ?? viewContext
        guard ctx.hasChanges else { return }
        
        ctx.performAndWait {
            do {
                try ctx.save()
            } catch {
                print("[DataController] Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    /// Creates a background context configured for high throughput batch jobs
    public func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}
