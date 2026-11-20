//
//  ProjectEntity+CoreDataClass.swift
//  BookScanPDF
//

import Foundation
import CoreData

@objc(ProjectEntity)
public class ProjectEntity: NSManagedObject {

}

extension ProjectEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectEntity> {
        return NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var pageCount: Int32
    @NSManaged public var coverThumbPath: String?
    @NSManaged public var pdfPreset: String
    @NSManaged public var pageSize: String
    @NSManaged public var ocrEnabled: Bool
    @NSManaged public var referenceEditData: Data?
    @NSManaged public var pages: NSSet?
}

// MARK: - Generated accessors for pages
extension ProjectEntity {
    @objc(addPagesObject:)
    @NSManaged public func addToPages(_ value: PageEntity)

    @objc(removePagesObject:)
    @NSManaged public func removeFromPages(_ value: PageEntity)

    @objc(addPages:)
    @NSManaged public func addToPages(_ values: NSSet)

    @objc(removePages:)
    @NSManaged public func removeFromPages(_ values: NSSet)
}
