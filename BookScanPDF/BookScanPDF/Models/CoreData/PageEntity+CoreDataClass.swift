//
//  PageEntity+CoreDataClass.swift
//  BookScanPDF
//

import Foundation
import CoreData

@objc(PageEntity)
public class PageEntity: NSManagedObject {

}

extension PageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PageEntity> {
        return NSFetchRequest<PageEntity>(entityName: "PageEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var projectId: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var originalPath: String
    @NSManaged public var processedPath: String?
    @NSManaged public var thumbPath: String?
    @NSManaged public var status: String
    @NSManaged public var source: String
    @NSManaged public var editData: Data?
    @NSManaged public var isSplitChild: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var project: ProjectEntity?
}
