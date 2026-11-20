//
//  ProcessingQueue.swift
//  BookScanPDF
//
//  Bounded background processing queue manager. Adapts concurrency to device physical RAM
//  (strictly 1 concurrent job on iPhone 7 Plus 3 GB) to prevent memory spikes during rapid shutter bursts.
//

import Foundation
import UIKit
import CoreData

public final class ProcessingQueue: ObservableObject {
    public static let shared = ProcessingQueue()
    
    private let operationQueue = OperationQueue()
    
    @Published public var pendingCount: Int = 0
    @Published public var isProcessing: Bool = false
    
    private init() {
        operationQueue.name = "com.bookscan.processing.queue"
        operationQueue.qualityOfService = .userInitiated
        
        configureAdaptiveConcurrency()
        setupMemoryWarningObserver()
    }
    
    /// Adapt concurrency strictly to device RAM:
    /// - 3 GB RAM devices (iPhone 7 Plus, ~3.0 GB): max 1 concurrent job
    /// - 4 GB+ RAM devices: max 2 concurrent jobs
    private func configureAdaptiveConcurrency() {
        let totalRamBytes = ProcessInfo.processInfo.physicalMemory
        let threeGB: UInt64 = 3_221_225_472 // ~3 GB
        
        if totalRamBytes <= threeGB || AppSettings.shared.performanceMode == .batterySaver {
            operationQueue.maxConcurrentOperationCount = 1
        } else {
            operationQueue.maxConcurrentOperationCount = 2
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: .appDidReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("[ProcessingQueue] Received memory warning! Forcing concurrency to 1.")
            self.operationQueue.maxConcurrentOperationCount = 1
        }
    }
    
    // MARK: - Enqueue Operations
    
    public func enqueue(pageId: UUID, projectId: UUID, isPriority: Bool = false) {
        let operation = ProcessingOperation(pageId: pageId, projectId: projectId)
        if isPriority {
            operation.queuePriority = .high
        } else {
            operation.queuePriority = .normal
        }
        
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatus()
            }
        }
        
        operationQueue.addOperation(operation)
        updateStatus()
    }
    
    public func cancelOperations(for projectId: UUID) {
        for op in operationQueue.operations {
            if let procOp = op as? ProcessingOperation, procOp.projectId == projectId {
                procOp.cancel()
            }
        }
        updateStatus()
    }
    
    public func resumePendingPages(dataController: DataController = .shared) {
        let context = dataController.viewContext
        let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "status == %@ OR status == %@",
            PageStatus.pending.rawValue,
            PageStatus.processing.rawValue
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PageEntity.orderIndex, ascending: true)]
        
        if let pages = try? context.fetch(request) {
            for page in pages {
                enqueue(pageId: page.id, projectId: page.projectId)
            }
        }
    }
    
    private func updateStatus() {
        let count = operationQueue.operationCount
        self.pendingCount = count
        self.isProcessing = count > 0
    }
}
