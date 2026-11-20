//
//  MotionManager.swift
//  BookScanPDF
//
//  Tracks device attitude and gravity vectors using Core Motion.
//  Determines whether the device is held sufficiently parallel/level to the physical page.
//

import Foundation
import CoreMotion

public final class MotionManager {
    public static let shared = MotionManager()
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    public private(set) var pitchDegrees: Double = 0.0
    public private(set) var rollDegrees: Double = 0.0
    public private(set) var isLevel: Bool = false
    
    public var onMotionUpdate: ((Double, Double, Bool) -> Void)?
    
    private init() {
        queue.name = "com.bookscan.motion"
        queue.maxConcurrentOperationCount = 1
    }
    
    public func startMonitoring(toleranceDegrees: Double = 6.0) {
        guard motionManager.isDeviceMotionAvailable else {
            // Simulator or hardware without gyro: fallback to always level
            self.isLevel = true
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 15.0 // 15 Hz
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            
            // Gravity components: gravity.z is near -1.0 when phone is held flat face-up
            // We calculate tilt deviation from flat horizontal plane
            let gx = motion.gravity.x
            let gy = motion.gravity.y
            let gz = motion.gravity.z
            
            // Pitch: tilt forward/backward (degrees)
            let pitch = atan2(gy, sqrt(gx * gx + gz * gz)) * 180.0 / .pi
            // Roll: tilt left/right (degrees)
            let roll = atan2(gx, sqrt(gy * gy + gz * gz)) * 180.0 / .pi
            
            self.pitchDegrees = pitch
            self.rollDegrees = roll
            
            // For scanning a book on a table, the phone is flat (pitch ~ 0°, roll ~ 0°)
            // or for a book standing on a lectern, within tolerance of the plane.
            let level = (abs(pitch) <= toleranceDegrees) && (abs(roll) <= toleranceDegrees)
            self.isLevel = level
            
            self.onMotionUpdate?(pitch, roll, level)
        }
    }
    
    public func stopMonitoring() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}
