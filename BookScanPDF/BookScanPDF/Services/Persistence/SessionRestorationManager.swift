//
//  SessionRestorationManager.swift
//  BookScanPDF
//
//  Tracks session activity and crash/termination recovery markers.
//  Enables automatic state reconciliation across unplanned app terminations on low-memory devices.
//

import Foundation
import CoreData

public final class SessionRestorationManager {
    public static let shared = SessionRestorationManager()
    
    private let stateURL: URL
    
    private struct ActiveSessionRecord: Codable {
        let activeProjectId: UUID?
        let timestamp: Date
        let isExportInProgress: Bool
    }
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.stateURL = appSupport.appendingPathComponent("BookScanData", isDirectory: true)
            .appendingPathComponent("session_manifest.json")
    }
    
    public func recordSessionStart(projectId: UUID) {
        let record = ActiveSessionRecord(
            activeProjectId: projectId,
            timestamp: Date(),
            isExportInProgress: false
        )
        save(record)
    }
    
    public func recordExportStart(projectId: UUID) {
        let record = ActiveSessionRecord(
            activeProjectId: projectId,
            timestamp: Date(),
            isExportInProgress: true
        )
        save(record)
    }
    
    public func clearActiveSession() {
        try? FileManager.default.removeItem(at: stateURL)
    }
    
    public func reconcileOnLaunch() {
        guard FileManager.default.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL),
              let record = try? JSONDecoder().decode(ActiveSessionRecord.self, from: data) else {
            return
        }
        
        print("[SessionRestorationManager] Reconciling session from \(record.timestamp)...")
        
        // Clean orphaned temporary files in tmp/
        let tmpDir = FileManager.default.temporaryDirectory
        if let contents = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // Resume any pending or failed pages
        ProcessingQueue.shared.resumePendingPages()
    }
    
    private func save(_ record: ActiveSessionRecord) {
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }
}
