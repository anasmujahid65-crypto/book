//
//  ProcessingOperation.swift
//  BookScanPDF
//
//  Executes end-to-end perspective correction, filtering, and thumbnail generation for a single page.
//  Strictly wrapped in autoreleasepool to guarantee flat O(1) memory consumption on 3 GB RAM devices.
//

import Foundation
import CoreData
import CoreImage
import Vision
import UIKit

public final class ProcessingOperation: Operation {
    public let pageId: UUID
    public let projectId: UUID
    
    private let filterEngine = FilterEngine()
    private let dataController = DataController.shared
    
    public init(pageId: UUID, projectId: UUID) {
        self.pageId = pageId
        self.projectId = projectId
        super.init()
        self.name = "PageProcessing-\(pageId.uuidString)"
        self.qualityOfService = .userInitiated
    }
    
    public override func main() {
        guard !isCancelled else { return }
        
        // Wrap entire pipeline execution in autoreleasepool
        autoreleasepool {
            processPage()
        }
    }
    
    private func processPage() {
        let bgContext = dataController.newBackgroundContext()
        var pageRecord: Page?
        var projectPreset: PDFPreset = .balanced
        var referenceEdit: PageEdit? = nil
        var isPage1 = false
        
        bgContext.performAndWait {
            let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
            if let entity = try? bgContext.fetch(fetch).first {
                entity.status = PageStatus.processing.rawValue
                self.dataController.save(context: bgContext)
                pageRecord = Page(entity: entity)
                isPage1 = (entity.orderIndex == 0)
                
                if let projEntity = entity.project {
                    projectPreset = PDFPreset(rawValue: projEntity.pdfPreset) ?? .balanced
                    if let refData = projEntity.referenceEditData {
                        referenceEdit = PageEdit.decode(from: refData)
                    }
                }
            }
        }
        
        guard let page = pageRecord, !isCancelled else { return }
        
        do {
            let originalURL = URL(fileURLWithPath: page.originalPath)
            
            // 1. Downsample original image to working resolution (~2200 px max long side)
            let workingLongSide: CGFloat = projectPreset == .original ? 3000 : 2200
            guard let workingImage = ImageDownsampler.downsample(imageAt: originalURL, maxDimension: workingLongSide),
                  let workingCGImage = workingImage.cgImage else {
                markPageFailed(pageId: pageId)
                return
            }
            
            var edit = page.edit
            
            // MARK: - Auto-Apply Settings from Page 1 (if enabled)
            let autoApplyEnabled = AppSettings.shared.autoApplyPage1Settings
            let reuseCropArea = AppSettings.shared.reusePage1CropArea
            
            if !isPage1 && autoApplyEnabled && !edit.isUserModified, let ref = referenceEdit {
                // Inherit tone, filter, rotation from Page 1
                edit.filter = ref.filter
                edit.rotationDegrees = ref.rotationDegrees
                edit.fineStraightenAngle = ref.fineStraightenAngle
                edit.brightness = ref.brightness
                edit.contrast = ref.contrast
                
                // Tripod mode: reuse Page 1 crop rectangle
                if reuseCropArea && ref.cropCorners != nil {
                    edit.cropCorners = ref.cropCorners
                }
            }
            
            // 2. Corner detection fallback if not already captured
            if edit.cropCorners == nil && AppSettings.shared.autoDetectEdges {
                edit.cropCorners = detectCorners(in: workingCGImage)
            }
            
            // 3. Process image with Core Image
            let ciImage = CIImage(cgImage: workingCGImage)
            guard let (processedData, _) = filterEngine.process(
                ciImage: ciImage,
                edit: edit,
                qualityPreset: projectPreset
            ) else {
                markPageFailed(pageId: pageId)
                return
            }
            
            guard !isCancelled else { return }
            
            // 4. Save processed JPEG to disk
            let processedPath = try DiskStorageManager.shared.writeProcessedData(
                processedData,
                projectId: projectId,
                pageId: pageId
            )
            
            // 5. Generate and save ~320 px thumbnail
            var thumbPath: String? = nil
            if let thumbImg = ImageDownsampler.downsample(imageData: processedData, maxDimension: 320),
               let thumbData = thumbImg.jpegData(compressionQuality: 0.75) {
                thumbPath = try? DiskStorageManager.shared.writeThumbData(
                    thumbData,
                    projectId: projectId,
                    pageId: pageId
                )
            }
            
            // 6. Update Core Data status to Ready
            bgContext.performAndWait {
                let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
                if let entity = try? bgContext.fetch(fetch).first {
                    entity.processedPath = processedPath
                    if let thumb = thumbPath {
                        entity.thumbPath = thumb
                    }
                    entity.status = PageStatus.ready.rawValue
                    entity.editData = edit.encodeToData()
                    
                    if let projectEntity = entity.project {
                        projectEntity.updatedAt = Date()
                        if isPage1 {
                            // If Page 1, store its edits as referenceEditData
                            projectEntity.referenceEditData = edit.encodeToData()
                            if let thumb = thumbPath {
                                projectEntity.coverThumbPath = thumb
                            }
                        }
                    }
                    
                    self.dataController.save(context: bgContext)
                }
            }
            
        } catch {
            print("[ProcessingOperation] Error processing page \(pageId): \(error)")
            markPageFailed(pageId: pageId)
        }
    }
    
    private func markPageFailed(pageId: UUID) {
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", pageId as CVarArg)
            if let entity = try? bgContext.fetch(fetch).first {
                entity.status = PageStatus.failed.rawValue
                self.dataController.save(context: bgContext)
            }
        }
    }
    
    private func detectCorners(in cgImage: CGImage) -> NormalizedQuad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1.60
        request.minimumSize = 0.25
        request.quadratureTolerance = 25.0
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        if let observation = request.results?.first {
            return NormalizedQuad(
                topLeft: observation.topLeft,
                topRight: observation.topRight,
                bottomRight: observation.bottomRight,
                bottomLeft: observation.bottomLeft
            )
        }
        return nil
    }
}
