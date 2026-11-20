//
//  CameraViewModel.swift
//  BookScanPDF
//
//  Coordinates continuous camera capture, live indicator analysis,
//  disk-first saving, page counter, and series persistence.
//

import Foundation
import SwiftUI
import CoreData
import AVFoundation

public final class CameraViewModel: ObservableObject {
    public let project: Project
    public let cameraManager = CameraManager()
    private let pageDetector = PageDetector()
    private let motionManager = MotionManager.shared
    private let dataController = DataController.shared
    
    // UI State
    @Published public var indicatorState: IndicatorState = .red(quad: nil, hint: "Analyzing scene...")
    @Published public var isDeviceLevel: Bool = false
    @Published public var pitch: Double = 0.0
    @Published public var roll: Double = 0.0
    
    @Published public var pageCount: Int
    @Published public var latestThumbnail: UIImage?
    @Published public var showShutterFlash: Bool = false
    @Published public var showGrid: Bool
    @Published public var flashModeIcon: String = "bolt.badge.a.fill"
    @Published public var isTorchActive: Bool = false
    @Published public var focusPoint: CGPoint?
    
    @Published public var isPermissionDenied: Bool = false
    @Published public var showExitConfirmation: Bool = false
    @Published public var navigateToReview: Bool = false
    @Published public var dismissCamera: Bool = false
    
    private var previousWasGreen: Bool = false
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    public init(project: Project) {
        self.project = project
        self.pageCount = project.pageCount
        self.showGrid = AppSettings.shared.gridDefault
        
        setupManagers()
        loadLatestThumbnail()
    }
    
    private func setupManagers() {
        cameraManager.delegate = self
        hapticFeedback.prepare()
        
        // Initialize default flash from Settings
        let defaultFlash = AppSettings.shared.flashDefault
        switch defaultFlash {
        case .auto:
            cameraManager.currentFlashMode = .auto
            flashModeIcon = "bolt.badge.a.fill"
        case .on:
            cameraManager.currentFlashMode = .on
            flashModeIcon = "bolt.fill"
        case .off:
            cameraManager.currentFlashMode = .off
            flashModeIcon = "bolt.slash.fill"
        }
        
        motionManager.onMotionUpdate = { [weak self] pitch, roll, level in
            DispatchQueue.main.async {
                self?.pitch = pitch
                self?.roll = roll
                self?.isDeviceLevel = level
            }
        }
    }
    
    public func onAppear() {
        // Keep screen awake during scanning
        UIApplication.shared.isIdleTimerDisabled = true
        
        let sensitivity = AppSettings.shared.indicatorSensitivity.angleToleranceDegrees
        motionManager.startMonitoring(toleranceDegrees: sensitivity)
        
        cameraManager.checkPermissions { [weak self] granted in
            if granted {
                self?.cameraManager.startSession()
            } else {
                self?.isPermissionDenied = true
            }
        }
    }
    
    public func onDisappear() {
        UIApplication.shared.isIdleTimerDisabled = false
        cameraManager.stopSession()
        motionManager.stopMonitoring()
    }
    
    // MARK: - Actions
    
    public func triggerShutter() {
        // Visual shutter flash
        withAnimation(.easeOut(duration: 0.10)) {
            showShutterFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.15)) {
                self.showShutterFlash = false
            }
        }
        
        // Haptic feedback
        if AppSettings.shared.hapticsEnabled {
            let shutterHaptic = UIImpactFeedbackGenerator(style: .medium)
            shutterHaptic.impactOccurred()
        }
        
        // Instant counter increment (Zero perceived lag)
        pageCount += 1
        
        // Trigger capture on hardware
        cameraManager.capturePhoto()
    }
    
    public func toggleFlash() {
        let newMode = cameraManager.cycleFlashMode()
        switch newMode {
        case .auto:
            flashModeIcon = "bolt.badge.a.fill"
        case .on:
            flashModeIcon = "bolt.fill"
        case .off:
            flashModeIcon = "bolt.slash.fill"
        @unknown default:
            flashModeIcon = "bolt.badge.a.fill"
        }
    }
    
    public func toggleTorch() {
        cameraManager.toggleTorch()
        isTorchActive = cameraManager.isTorchOn
    }
    
    public func toggleGrid() {
        showGrid.toggle()
    }
    
    public func handleTapToFocus(at point: CGPoint, viewSize: CGSize) {
        focusPoint = point
        // Convert to device normalized point (0.0 - 1.0)
        let normalizedPoint = CGPoint(x: point.x / viewSize.width, y: point.y / viewSize.height)
        cameraManager.setFocusPoint(normalizedPoint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.focusPoint == point {
                self?.focusPoint = nil
            }
        }
    }
    
    public func handlePinchZoom(scale: CGFloat) {
        cameraManager.setZoomFactor(scale)
    }
    
    public func handleCloseRequest() {
        if pageCount > 0 {
            showExitConfirmation = true
        } else {
            dismissCamera = true
        }
    }
    
    public func saveAndExit() {
        dismissCamera = true
    }
    
    public func discardAndExit() {
        // Delete all captures for this project if user wants to discard
        Task {
            DiskStorageManager.shared.deleteProjectFiles(for: project.id)
            let context = dataController.viewContext
            let fetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            if let entity = try? context.fetch(fetch).first {
                context.delete(entity)
                dataController.save(context: context)
            }
            await MainActor.run {
                self.dismissCamera = true
            }
        }
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadLatestThumbnail() {
        guard let cover = project.coverThumbPath else { return }
        let url = URL(fileURLWithPath: cover)
        DispatchQueue.global(qos: .userInitiated).async {
            if let img = ImageDownsampler.downsample(imageAt: url, maxDimension: 120) {
                DispatchQueue.main.async {
                    self.latestThumbnail = img
                }
            }
        }
    }
}

// MARK: - CameraManagerDelegate
extension CameraViewModel: CameraManagerDelegate {
    public func cameraManager(_ manager: CameraManager, didOutputVideoFrame pixelBuffer: CVPixelBuffer) {
        let state = pageDetector.processFrame(
            pixelBuffer: pixelBuffer,
            isDeviceLevel: isDeviceLevel,
            tiltPitch: pitch,
            tiltRoll: roll
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.indicatorState = state
            
            // Haptic tick when turning green
            if state.isGreen && !self.previousWasGreen && AppSettings.shared.hapticsEnabled {
                self.hapticFeedback.impactOccurred()
            }
            self.previousWasGreen = state.isGreen
        }
    }
    
    public func cameraManager(_ manager: CameraManager, didCapturePhotoData data: Data) {
        let pageId = UUID()
        let capturedQuad = indicatorState.quad
        
        // Disk-first write: write raw capture immediately to disk
        Task {
            do {
                let originalPath = try DiskStorageManager.shared.writeOriginalData(
                    data,
                    projectId: self.project.id,
                    pageId: pageId
                )
                
                // Downsample thumbnail for in-memory camera badge
                let thumbImage = ImageDownsampler.downsample(imageData: data, maxDimension: 140)
                
                // Save thumbnail to disk as well
                var thumbPath: String? = nil
                if let thumbData = thumbImage?.jpegData(compressionQuality: 0.7) {
                    thumbPath = try? DiskStorageManager.shared.writeThumbData(
                        thumbData,
                        projectId: self.project.id,
                        pageId: pageId
                    )
                }
                
                // Update Core Data on background context
                let bgContext = self.dataController.newBackgroundContext()
                bgContext.performAndWait {
                    let pageEntity = PageEntity(context: bgContext)
                    pageEntity.id = pageId
                    pageEntity.projectId = self.project.id
                    pageEntity.orderIndex = Int32(self.pageCount)
                    pageEntity.originalPath = originalPath
                    pageEntity.thumbPath = thumbPath
                    pageEntity.status = PageStatus.pending.rawValue
                    pageEntity.source = CaptureSource.camera.rawValue
                    pageEntity.createdAt = Date()
                    pageEntity.isSplitChild = false
                    
                    var edit = PageEdit.default
                    edit.cropCorners = capturedQuad
                    pageEntity.editData = edit.encodeToData()
                    
                    // Link to project
                    let projFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                    projFetch.predicate = NSPredicate(format: "id == %@", self.project.id as CVarArg)
                    if let projEntity = try? bgContext.fetch(projFetch).first {
                        pageEntity.project = projEntity
                        projEntity.pageCount = Int32(self.pageCount)
                        projEntity.updatedAt = Date()
                        if projEntity.coverThumbPath == nil {
                            projEntity.coverThumbPath = thumbPath
                        }
                    }
                    
                    self.dataController.save(context: bgContext)
                }
                
                // Enqueue page for background perspective correction and filtering
                ProcessingQueue.shared.enqueue(pageId: pageId, projectId: self.project.id)
                
                // Update UI on main thread
                await MainActor.run {
                    if let thumb = thumbImage {
                        self.latestThumbnail = thumb
                    }
                }
            } catch {
                print("[CameraViewModel] Failed to write capture: \(error)")
            }
        }
    }
    
    public func cameraManager(_ manager: CameraManager, didFailWithError error: Error) {
        print("[CameraViewModel] Camera error: \(error.localizedDescription)")
    }
}
