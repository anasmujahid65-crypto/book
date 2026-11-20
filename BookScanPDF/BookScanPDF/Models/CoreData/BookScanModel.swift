//
//  BookScanModel.swift
//  BookScanPDF
//
//  Programmatic Core Data Model definition compatible with iOS 15.0+.
//  Avoids build issues with .xcdatamodeld compilation while maintaining 100% Core Data performance.
//

import Foundation
import CoreData

public final class BookScanModel {
    public static let modelName = "BookScanModel"
    
    public static let sharedModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        
        // MARK: - Project Entity
        let projectEntity = NSEntityDescription()
        projectEntity.name = "ProjectEntity"
        projectEntity.managedObjectClassName = NSStringFromClass(ProjectEntity.self)
        
        let projIdAttr = NSAttributeDescription()
        projIdAttr.name = "id"
        projIdAttr.attributeType = .UUIDAttributeType
        projIdAttr.isOptional = false
        
        let projNameAttr = NSAttributeDescription()
        projNameAttr.name = "name"
        projNameAttr.attributeType = .stringAttributeType
        projNameAttr.isOptional = false
        projNameAttr.defaultValue = "Untitled Scan"
        
        let projCreatedAtAttr = NSAttributeDescription()
        projCreatedAtAttr.name = "createdAt"
        projCreatedAtAttr.attributeType = .dateAttributeType
        projCreatedAtAttr.isOptional = false
        
        let projUpdatedAtAttr = NSAttributeDescription()
        projUpdatedAtAttr.name = "updatedAt"
        projUpdatedAtAttr.attributeType = .dateAttributeType
        projUpdatedAtAttr.isOptional = false
        
        let projPageCountAttr = NSAttributeDescription()
        projPageCountAttr.name = "pageCount"
        projPageCountAttr.attributeType = .integer32AttributeType
        projPageCountAttr.defaultValue = 0
        
        let projCoverThumbAttr = NSAttributeDescription()
        projCoverThumbAttr.name = "coverThumbPath"
        projCoverThumbAttr.attributeType = .stringAttributeType
        projCoverThumbAttr.isOptional = true
        
        let projPdfPresetAttr = NSAttributeDescription()
        projPdfPresetAttr.name = "pdfPreset"
        projPdfPresetAttr.attributeType = .stringAttributeType
        projPdfPresetAttr.defaultValue = "balanced"
        
        let projPageSizeAttr = NSAttributeDescription()
        projPageSizeAttr.name = "pageSize"
        projPageSizeAttr.attributeType = .stringAttributeType
        projPageSizeAttr.defaultValue = "fit"
        
        let projOcrEnabledAttr = NSAttributeDescription()
        projOcrEnabledAttr.name = "ocrEnabled"
        projOcrEnabledAttr.attributeType = .booleanAttributeType
        projOcrEnabledAttr.defaultValue = false
        
        let projReferenceEditDataAttr = NSAttributeDescription()
        projReferenceEditDataAttr.name = "referenceEditData"
        projReferenceEditDataAttr.attributeType = .binaryDataAttributeType
        projReferenceEditDataAttr.isOptional = true
        
        // MARK: - Page Entity
        let pageEntity = NSEntityDescription()
        pageEntity.name = "PageEntity"
        pageEntity.managedObjectClassName = NSStringFromClass(PageEntity.self)
        
        let pageIdAttr = NSAttributeDescription()
        pageIdAttr.name = "id"
        pageIdAttr.attributeType = .UUIDAttributeType
        pageIdAttr.isOptional = false
        
        let pageProjectIdAttr = NSAttributeDescription()
        pageProjectIdAttr.name = "projectId"
        pageProjectIdAttr.attributeType = .UUIDAttributeType
        pageProjectIdAttr.isOptional = false
        
        let pageOrderIndexAttr = NSAttributeDescription()
        pageOrderIndexAttr.name = "orderIndex"
        pageOrderIndexAttr.attributeType = .integer32AttributeType
        pageOrderIndexAttr.defaultValue = 0
        
        let pageOriginalPathAttr = NSAttributeDescription()
        pageOriginalPathAttr.name = "originalPath"
        pageOriginalPathAttr.attributeType = .stringAttributeType
        pageOriginalPathAttr.isOptional = false
        
        let pageProcessedPathAttr = NSAttributeDescription()
        pageProcessedPathAttr.name = "processedPath"
        pageProcessedPathAttr.attributeType = .stringAttributeType
        pageProcessedPathAttr.isOptional = true
        
        let pageThumbPathAttr = NSAttributeDescription()
        pageThumbPathAttr.name = "thumbPath"
        pageThumbPathAttr.attributeType = .stringAttributeType
        pageThumbPathAttr.isOptional = true
        
        let pageStatusAttr = NSAttributeDescription()
        pageStatusAttr.name = "status"
        pageStatusAttr.attributeType = .stringAttributeType
        pageStatusAttr.defaultValue = "pending"
        
        let pageSourceAttr = NSAttributeDescription()
        pageSourceAttr.name = "source"
        pageSourceAttr.attributeType = .stringAttributeType
        pageSourceAttr.defaultValue = "camera"
        
        let pageEditDataAttr = NSAttributeDescription()
        pageEditDataAttr.name = "editData"
        pageEditDataAttr.attributeType = .binaryDataAttributeType
        pageEditDataAttr.isOptional = true
        
        let pageIsSplitChildAttr = NSAttributeDescription()
        pageIsSplitChildAttr.name = "isSplitChild"
        pageIsSplitChildAttr.attributeType = .booleanAttributeType
        pageIsSplitChildAttr.defaultValue = false
        
        let pageCreatedAtAttr = NSAttributeDescription()
        pageCreatedAtAttr.name = "createdAt"
        pageCreatedAtAttr.attributeType = .dateAttributeType
        pageCreatedAtAttr.isOptional = false
        
        // MARK: - Relationships
        let projectPagesRel = NSRelationshipDescription()
        projectPagesRel.name = "pages"
        projectPagesRel.destinationEntity = pageEntity
        projectPagesRel.minCount = 0
        projectPagesRel.maxCount = 0 // to-many
        projectPagesRel.deleteRule = .cascadeDeleteRule
        
        let pageProjectRel = NSRelationshipDescription()
        pageProjectRel.name = "project"
        pageProjectRel.destinationEntity = projectEntity
        pageProjectRel.minCount = 1
        pageProjectRel.maxCount = 1 // to-one
        pageProjectRel.deleteRule = .nullifyDeleteRule
        
        projectPagesRel.inverseRelationship = pageProjectRel
        pageProjectRel.inverseRelationship = projectPagesRel
        
        // Assign attributes and relationships
        projectEntity.properties = [
            projIdAttr, projNameAttr, projCreatedAtAttr, projUpdatedAtAttr,
            projPageCountAttr, projCoverThumbAttr, projPdfPresetAttr,
            projPageSizeAttr, projOcrEnabledAttr, projReferenceEditDataAttr,
            projectPagesRel
        ]
        
        pageEntity.properties = [
            pageIdAttr, pageProjectIdAttr, pageOrderIndexAttr, pageOriginalPathAttr,
            pageProcessedPathAttr, pageThumbPathAttr, pageStatusAttr, pageSourceAttr,
            pageEditDataAttr, pageIsSplitChildAttr, pageCreatedAtAttr,
            pageProjectRel
        ]
        
        model.entities = [projectEntity, pageEntity]
        return model
    }()
}
