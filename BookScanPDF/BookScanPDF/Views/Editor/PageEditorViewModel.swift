//
//  PageEditorViewModel.swift
//  BookScanPDF
//
//  Manages live interactive editing of a scanned book page.
//  Operates on a downsampled working copy for smooth 60fps adjustments,
//  committing changes to background processing on save.
//

import Foundation
import SwiftUI
import CoreData
import CoreImage
import Vision

public final class PageEditorViewModel: ObservableObject {
    public let page: Page
    public let project: Project
    
    // Original image data
    @Published public var rawOriginalImage: UIImage?
    @Published public var workingPreviewImage: UIImage?
    
    // Interactive Edit Parameters
    @Published public var cropQuad: NormalizedQuad
    @Published public var selectedFilter: FilterType
    @Published public var rotationDegrees: Int
    @Published public var fineStraighten: Double
    @Published public var brightness: Float
    @Published public var contrast: Float
    
    // Tools UI State
    @Published public var isCropActive: Bool = false
    @Published public var showLoupe: Bool = false
    @Published public var loupePosition: CGPoint = .zero
    @Published public var loupeFocusPoint: CGPoint = .zero
    
    @Published public var isSaving: Bool = false
    @Published public var promptCascadePage1: Bool = false
    
    private let filterEngine = FilterEngine()
    private let dataController = DataController.shared
    
    public init(page: Page, project: Project) {
        self.page = page
        self.project = project
        
        self.cropQuad = page.edit.cropCorners ?? NormalizedQuad.defaultUnitSquare
        self.selectedFilter = page.edit.filter
        self.rotationDegrees = page.edit.rotationDegrees
        self.fineStraighten = page.edit.fineStraightenAngle
        self.brightness = page.edit.brightness
        self.contrast = page.edit.contrast
        
        loadWorkingImage()
    }
    
    private func loadWorkingImage() {
        let origURL = URL(fileURLWithPath: page.originalPath)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Memory safe downsample to 1600 px for interactive editing
            guard let self = self,
                  let image = ImageDownsampler.downsample(imageAt: origURL, maxDimension: 1600) else { return }
            
            DispatchQueue.main.async {
                self.rawOriginalImage = image
                self.updateLivePreview()
            }
        }
    }
    
    public func updateLivePreview() {
        guard let raw = rawOriginalImage, let cgImage = raw.cgImage else { return }
        
        var current = CIImage(cgImage: cgImage)
        
        // 1. Perspective Crop (only if not in interactive crop mode)
        if !isCropActive && cropQuad != NormalizedQuad.defaultUnitSquare {
            let size = CGSize(width: cgImage.width, height: cgImage.height)
            current = filterEngine.applyPerspectiveCorrection(image: current, quad: cropQuad, imageSize: size)
        }
        
        // 2. Rotation & Straighten
        if rotationDegrees != 0 {
            current = filterEngine.applyRotation(image: current, degrees: rotationDegrees)
        }
        if abs(fineStraighten) > 0.01 {
            current = filterEngine.applyStraighten(image: current, angleDegrees: fineStraighten)
        }
        
        // 3. Tone Adjustments
        if abs(brightness) > 0.01 || abs(contrast - 1.0) > 0.01 {
            current = filterEngine.applyToneAdjustments(image: current, brightness: brightness, contrast: contrast)
        }
        
        // 4. Document Filter
        current = filterEngine.applyFilter(image: current, filter: selectedFilter)
        
        // Render preview
        let context = CIContextHolder.shared.context
        if let outputCG = context.createCGImage(current, from: current.extent) {
            self.workingPreviewImage = UIImage(cgImage: outputCG)
        }
    }
    
    // MARK: - Tool Actions
    
    public func rotateClockwise() {
        rotationDegrees = (rotationDegrees + 90) % 360
        updateLivePreview()
    }
    
    public func autoDetectCorners() {
        guard let raw = rawOriginalImage, let cgImage = raw.cgImage else { return }
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1.60
        request.quadratureTolerance = 25.0
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        if let result = request.results?.first {
            self.cropQuad = NormalizedQuad(
                topLeft: result.topLeft,
                topRight: result.topRight,
                bottomRight: result.bottomRight,
                bottomLeft: result.bottomLeft
            )
            updateLivePreview()
        }
    }
    
    public func resetCorners() {
        self.cropQuad = NormalizedQuad.defaultUnitSquare
        updateLivePreview()
    }
    
    public func updateLoupe(corner: ActiveCorner, touchLocation: CGPoint, viewSize: CGSize) {
        self.showLoupe = true
        self.loupePosition = touchLocation
        
        // Calculate offset for focus within the magnifier
        let normX = touchLocation.x / viewSize.width - 0.5
        let normY = touchLocation.y / viewSize.height - 0.5
        self.loupeFocusPoint = CGPoint(x: normX * 100, y: normY * 100)
    }
    
    public func hideLoupe() {
        self.showLoupe = false
    }
    
    // MARK: - Save Changes
    
    public func save(completion: @escaping () -> Void) {
        isSaving = true
        
        let updatedEdit = PageEdit(
            cropCorners: cropQuad,
            filter: selectedFilter,
            rotationDegrees: rotationDegrees,
            fineStraightenAngle: fineStraighten,
            brightness: brightness,
            contrast: contrast,
            isUserModified: true // User manually tweaked this page
        )
        
        let bgContext = dataController.newBackgroundContext()
        let isPage1 = (page.orderIndex == 0)
        
        bgContext.performAndWait {
            let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", self.page.id as CVarArg)
            if let entity = try? bgContext.fetch(fetch).first {
                entity.editData = updatedEdit.encodeToData()
                entity.status = PageStatus.pending.rawValue
                
                if isPage1, let projEntity = entity.project {
                    projEntity.referenceEditData = updatedEdit.encodeToData()
                }
            }
            self.dataController.save(context: bgContext)
        }
        
        // Re-enqueue for full-resolution rendering in background
        ProcessingQueue.shared.enqueue(pageId: page.id, projectId: project.id, isPriority: true)
        
        if isPage1 && AppSettings.shared.autoApplyPage1Settings {
            promptCascadePage1 = true
        } else {
            isSaving = false
            completion()
        }
    }
    
    public func cascadeToAllPages(completion: @escaping () -> Void) {
        AutoApplyManager.shared.cascadePage1Settings(
            projectId: project.id,
            forceOverwriteUserModified: false
        )
        isSaving = false
        completion()
    }
}
