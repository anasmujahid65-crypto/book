//
//  CameraManager.swift
//  BookScanPDF
//
//  Manages AVFoundation capture pipeline. Supports rapid manual shutter fires,
//  low-latency video frame analysis for Vision, tap-to-focus, zoom, and hardware torch/flash.
//

import AVFoundation
import UIKit

public protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutputVideoFrame pixelBuffer: CVPixelBuffer)
    func cameraManager(_ manager: CameraManager, didCapturePhotoData data: Data)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
}

public final class CameraManager: NSObject {
    public weak var delegate: CameraManagerDelegate?
    
    public let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.bookscan.camera.session")
    private let videoDataQueue = DispatchQueue(label: "com.bookscan.camera.videoData", qos: .userInteractive)
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var isConfigured = false
    private var lastAnalysisFrameTimestamp: CFTimeInterval = 0
    private let analysisFrameInterval: CFTimeInterval = 1.0 / 12.0 // 12 Hz throttle
    
    public var currentFlashMode: AVCaptureDevice.FlashMode = .auto
    public var isTorchOn: Bool = false
    
    public override init() {
        super.init()
    }
    
    public func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Discover camera device (Default to standard 1x wide angle lens matching native Camera app)
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
            mediaType: .video,
            position: .back
        )
        
        guard let camera = deviceDiscoverySession.devices.first else {
            print("[CameraManager] No compatible back camera found.")
            session.commitConfiguration()
            return
        }
        
        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = 1.0
            camera.unlockForConfiguration()
            
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
            }
            
            // Setup Photo Output with full native sensor resolution
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.maxPhotoQualityPrioritization = .balanced
            }
            
            // Setup Video Data Output for Page Detection
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
            }
            
            // Set video orientation
            if let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            isConfigured = true
        } catch {
            print("[CameraManager] Failed to configure camera input: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - Capture Photo
    
    public func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.photoQualityPrioritization = .balanced
            
            if self.videoDeviceInput?.device.isFlashAvailable == true {
                photoSettings.flashMode = self.isTorchOn ? .off : self.currentFlashMode
            }
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - Torch & Flash Controls
    
    public func toggleTorch() {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.torchMode == .on {
                    device.torchMode = .off
                    self.isTorchOn = false
                } else {
                    try device.setTorchModeOn(level: 1.0)
                    self.isTorchOn = true
                }
                device.unlockForConfiguration()
            } catch {
                print("[CameraManager] Torch error: \(error)")
            }
        }
    }
    
    public func cycleFlashMode() -> AVCaptureDevice.FlashMode {
        switch currentFlashMode {
        case .auto:
            currentFlashMode = .on
        case .on:
            currentFlashMode = .off
        case .off:
            currentFlashMode = .auto
        @unknown default:
            currentFlashMode = .auto
        }
        return currentFlashMode
    }
    
    // MARK: - Focus & Zoom
    
    public func setFocusPoint(_ point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                print("[CameraManager] Focus error: \(error)")
            }
        }
    }
    
    public func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clampedZoom = max(device.minAvailableVideoZoomFactor, min(factor, min(device.maxAvailableVideoZoomFactor, 5.0)))
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
            } catch {
                print("[CameraManager] Zoom error: \(error)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTimestamp = CACurrentMediaTime()
        guard currentTimestamp - lastAnalysisFrameTimestamp >= analysisFrameInterval else {
            return
        }
        lastAnalysisFrameTimestamp = currentTimestamp
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.cameraManager(self, didOutputVideoFrame: pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.cameraManager(self, didFailWithError: error)
            return
        }
        guard let photoData = photo.fileDataRepresentation() else {
            let error = NSError(domain: "com.bookscan.camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract JPEG bytes"])
            delegate?.cameraManager(self, didFailWithError: error)
            return
        }
        
        delegate?.cameraManager(self, didCapturePhotoData: photoData)
    }
}
