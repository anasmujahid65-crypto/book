//
//  Page.swift
//  BookScanPDF
//

import Foundation

public struct Page: Identifiable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public var orderIndex: Int
    public var originalPath: String
    public var processedPath: String?
    public var thumbPath: String?
    public var status: PageStatus
    public var source: CaptureSource
    public var edit: PageEdit
    public var isSplitChild: Bool
    public var createdAt: Date
    
    public init(id: UUID = UUID(),
                projectId: UUID,
                orderIndex: Int,
                originalPath: String,
                processedPath: String? = nil,
                thumbPath: String? = nil,
                status: PageStatus = .pending,
                source: CaptureSource = .camera,
                edit: PageEdit = .default,
                isSplitChild: Bool = false,
                createdAt: Date = Date()) {
        self.id = id
        self.projectId = projectId
        self.orderIndex = orderIndex
        self.originalPath = originalPath
        self.processedPath = processedPath
        self.thumbPath = thumbPath
        self.status = status
        self.source = source
        self.edit = edit
        self.isSplitChild = isSplitChild
        self.createdAt = createdAt
    }
    
    public init(entity: PageEntity) {
        self.id = entity.id
        self.projectId = entity.projectId
        self.orderIndex = Int(entity.orderIndex)
        self.originalPath = entity.originalPath
        self.processedPath = entity.processedPath
        self.thumbPath = entity.thumbPath
        self.status = PageStatus(rawValue: entity.status) ?? .pending
        self.source = CaptureSource(rawValue: entity.source) ?? .camera
        self.edit = PageEdit.decode(from: entity.editData)
        self.isSplitChild = entity.isSplitChild
        self.createdAt = entity.createdAt
    }
}
