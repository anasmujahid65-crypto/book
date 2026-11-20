//
//  Project.swift
//  BookScanPDF
//

import Foundation

public struct Project: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var pageCount: Int
    public var coverThumbPath: String?
    public var pdfPreset: PDFPreset
    public var pageSize: PageSizeOption
    public var ocrEnabled: Bool
    public var referenceEdit: PageEdit?
    
    public init(id: UUID = UUID(),
                name: String = "Book Scan",
                createdAt: Date = Date(),
                updatedAt: Date = Date(),
                pageCount: Int = 0,
                coverThumbPath: String? = nil,
                pdfPreset: PDFPreset = .balanced,
                pageSize: PageSizeOption = .fit,
                ocrEnabled: Bool = false,
                referenceEdit: PageEdit? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
        self.coverThumbPath = coverThumbPath
        self.pdfPreset = pdfPreset
        self.pageSize = pageSize
        self.ocrEnabled = ocrEnabled
        self.referenceEdit = referenceEdit
    }
    
    public init(entity: ProjectEntity) {
        self.id = entity.id
        self.name = entity.name
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.pageCount = Int(entity.pageCount)
        self.coverThumbPath = entity.coverThumbPath
        self.pdfPreset = PDFPreset(rawValue: entity.pdfPreset) ?? .balanced
        self.pageSize = PageSizeOption(rawValue: entity.pageSize) ?? .fit
        self.ocrEnabled = entity.ocrEnabled
        if let data = entity.referenceEditData {
            self.referenceEdit = PageEdit.decode(from: data)
        } else {
            self.referenceEdit = nil
        }
    }
}
