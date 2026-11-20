//
//  DiskStorageManager.swift
//  BookScanPDF
//
//  Disk-first file system storage. Enforces strict zero-memory footprint by writing captures
//  immediately to disk in sandboxed Application Support folders (excluded from iCloud backup).
//

import Foundation
import UIKit

public final class DiskStorageManager: @unchecked Sendable {
    public static let shared = DiskStorageManager()
    
    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let lock = NSLock()
    
    private init() {
        guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }
        self.appSupportURL = url.appendingPathComponent("BookScanData", isDirectory: true)
        createBaseDirectoriesIfNeeded()
    }
    
    private func createBaseDirectoriesIfNeeded() {
        do {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableURL = appSupportURL
                try mutableURL.setResourceValues(resourceValues)
            }
        } catch {
            print("[DiskStorageManager] Failed to create or exclude base storage directory: \(error)")
        }
    }
    
    // MARK: - Directory Resolution
    
    public func projectDirectory(for projectId: UUID) -> URL {
        return appSupportURL.appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId.uuidString, isDirectory: true)
    }
    
    public func originalsDirectory(for projectId: UUID) -> URL {
        return projectDirectory(for: projectId).appendingPathComponent("originals", isDirectory: true)
    }
    
    public func processedDirectory(for projectId: UUID) -> URL {
        return projectDirectory(for: projectId).appendingPathComponent("processed", isDirectory: true)
    }
    
    public func thumbsDirectory(for projectId: UUID) -> URL {
        return projectDirectory(for: projectId).appendingPathComponent("thumbs", isDirectory: true)
    }
    
    public func exportsDirectory(for projectId: UUID) -> URL {
        return projectDirectory(for: projectId).appendingPathComponent("exports", isDirectory: true)
    }
    
    // MARK: - File Paths
    
    public func originalPath(projectId: UUID, pageId: UUID) -> URL {
        return originalsDirectory(for: projectId).appendingPathComponent("\(pageId.uuidString).jpg")
    }
    
    public func processedPath(projectId: UUID, pageId: UUID) -> URL {
        return processedDirectory(for: projectId).appendingPathComponent("\(pageId.uuidString).jpg")
    }
    
    public func thumbPath(projectId: UUID, pageId: UUID) -> URL {
        return thumbsDirectory(for: projectId).appendingPathComponent("\(pageId.uuidString).jpg")
    }
    
    public func exportPDFPath(projectId: UUID, filename: String) -> URL {
        let safeName = filename.hasSuffix(".pdf") ? filename : "\(filename).pdf"
        return exportsDirectory(for: projectId).appendingPathComponent(safeName)
    }
    
    // MARK: - Project Structure Creation
    
    public func ensureProjectDirectoriesExist(for projectId: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        
        let dirs = [
            originalsDirectory(for: projectId),
            processedDirectory(for: projectId),
            thumbsDirectory(for: projectId),
            exportsDirectory(for: projectId)
        ]
        
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    // MARK: - Write Operations
    
    public func writeOriginalData(_ data: Data, projectId: UUID, pageId: UUID) throws -> String {
        try ensureProjectDirectoriesExist(for: projectId)
        let destination = originalPath(projectId: projectId, pageId: pageId)
        try data.write(to: destination, options: .atomic)
        return destination.path
    }
    
    public func writeProcessedData(_ data: Data, projectId: UUID, pageId: UUID) throws -> String {
        try ensureProjectDirectoriesExist(for: projectId)
        let destination = processedPath(projectId: projectId, pageId: pageId)
        try data.write(to: destination, options: .atomic)
        return destination.path
    }
    
    public func writeThumbData(_ data: Data, projectId: UUID, pageId: UUID) throws -> String {
        try ensureProjectDirectoriesExist(for: projectId)
        let destination = thumbPath(projectId: projectId, pageId: pageId)
        try data.write(to: destination, options: .atomic)
        return destination.path
    }
    
    // MARK: - Delete Operations
    
    public func deleteProjectFiles(for projectId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        let dir = projectDirectory(for: projectId)
        try? fileManager.removeItem(at: dir)
    }
    
    public func deletePageFiles(projectId: UUID, pageId: UUID) {
        let orig = originalPath(projectId: projectId, pageId: pageId)
        let proc = processedPath(projectId: projectId, pageId: pageId)
        let thumb = thumbPath(projectId: projectId, pageId: pageId)
        
        try? fileManager.removeItem(at: orig)
        try? fileManager.removeItem(at: proc)
        try? fileManager.removeItem(at: thumb)
    }
    
    // MARK: - Storage Analytics
    
    public func calculateStorageUsed() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: appSupportURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    public func checkFreeDiskSpace() -> Int64 {
        do {
            let values = try appSupportURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        } catch {}
        return 500_000_000 // default fallback ~500MB
    }
}
