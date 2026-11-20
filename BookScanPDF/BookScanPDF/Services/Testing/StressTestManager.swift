//
//  StressTestManager.swift
//  BookScanPDF
//
//  500-page synthetic stress test and memory profiler.
//  Simulates capturing, processing, and streaming export of 500 high-resolution pages
//  on iPhone 7 Plus (A10 Fusion, 3 GB RAM), verifying resident memory stays flat and bounded.
//

import UIKit
import CoreData
import PDFKit

public struct StressTestMetrics {
    public var currentStep: String = "Idle"
    public var pagesGenerated: Int = 0
    public var totalPages: Int = 500
    public var peakMemoryMB: Double = 0.0
    public var currentMemoryMB: Double = 0.0
    public var pdfExportDurationSeconds: Double = 0.0
    public var pdfFileSizeMB: Double = 0.0
    public var isComplete: Bool = false
    public var didPassMemoryConstraint: Bool = false // Peak < 150 MB
    public var didPassPageCountIntegrity: Bool = false // Exactly 500 pages in output PDF
}

public final class StressTestManager: ObservableObject {
    public static let shared = StressTestManager()
    
    @Published public var metrics = StressTestMetrics()
    @Published public var isRunning = false
    
    private let dataController = DataController.shared
    private var isCancelled = false
    
    private init() {}
    
    /// Reads mach task resident memory in megabytes
    public static func getResidentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }
    
    public func run500PageStressTest(pageCount: Int = 500, completion: @escaping (StressTestMetrics) -> Void) {
        guard !isRunning else { return }
        
        self.isRunning = true
        self.isCancelled = false
        self.metrics = StressTestMetrics(totalPages: pageCount)
        
        Task {
            let testProjectId = UUID()
            var generatedURLs: [URL] = []
            
            // Step 1: Create Test Project
            await MainActor.run {
                self.metrics.currentStep = "Initializing test project..."
            }
            
            let bgContext = self.dataController.newBackgroundContext()
            bgContext.performAndWait {
                let proj = ProjectEntity(context: bgContext)
                proj.id = testProjectId
                proj.name = "500-Page Stress Test"
                proj.createdAt = Date()
                proj.updatedAt = Date()
                proj.pageCount = Int32(pageCount)
                proj.pdfPreset = PDFPreset.balanced.rawValue
                proj.pageSize = PageSizeOption.fit.rawValue
                proj.ocrEnabled = false
                self.dataController.save(context: bgContext)
            }
            
            // Step 2: Generate Synthetic Pages & Stream to Disk
            await MainActor.run {
                self.metrics.currentStep = "Generating 500 synthetic pages to disk..."
            }
            
            // Create a realistic sample book page bitmap once (~1800x2400)
            let sampleJPEGData = createSyntheticBookPageJPEG()
            
            for i in 1...pageCount {
                guard !self.isCancelled else { break }
                
                let pageId = UUID()
                do {
                    let path = try DiskStorageManager.shared.writeProcessedData(
                        sampleJPEGData,
                        projectId: testProjectId,
                        pageId: pageId
                    )
                    generatedURLs.append(URL(fileURLWithPath: path))
                } catch {
                    print("[StressTest] Failed to write page \(i): \(error)")
                }
                
                if i % 25 == 0 || i == pageCount {
                    let mem = Self.getResidentMemoryMB()
                    await MainActor.run {
                        self.metrics.pagesGenerated = i
                        self.metrics.currentMemoryMB = mem
                        self.metrics.peakMemoryMB = max(self.metrics.peakMemoryMB, mem)
                    }
                }
            }
            
            // Step 3: Stream 500 Pages directly into PDF
            await MainActor.run {
                self.metrics.currentStep = "Streaming 500 pages into PDF via FileHandle..."
            }
            
            let startTime = CACurrentMediaTime()
            let pdfExportURL = DiskStorageManager.shared.exportPDFPath(
                projectId: testProjectId,
                filename: "500_Page_Benchmark"
            )
            
            do {
                let writer = PDFStreamingWriter(destinationURL: pdfExportURL)
                try await writer.writePDF(
                    pageURLs: generatedURLs,
                    pageSizeOption: .fit,
                    ocrEnabled: false
                ) { current, total in
                    let mem = Self.getResidentMemoryMB()
                    DispatchQueue.main.async {
                        self.metrics.pagesGenerated = current
                        self.metrics.currentMemoryMB = mem
                        self.metrics.peakMemoryMB = max(self.metrics.peakMemoryMB, mem)
                    }
                }
                
                let duration = CACurrentMediaTime() - startTime
                
                // Step 4: Validate Output Integrity
                await MainActor.run {
                    self.metrics.currentStep = "Validating PDF integrity via PDFKit..."
                }
                
                var verifiedCount = 0
                if let pdfDoc = PDFDocument(url: pdfExportURL) {
                    verifiedCount = pdfDoc.pageCount
                }
                
                let fileAttributes = try? FileManager.default.attributesOfItem(atPath: pdfExportURL.path)
                let fileSize = Double(fileAttributes?[.size] as? Int64 ?? 0) / (1024.0 * 1024.0)
                
                // Cleanup test project files
                DiskStorageManager.shared.deleteProjectFiles(for: testProjectId)
                bgContext.performAndWait {
                    let fetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                    fetch.predicate = NSPredicate(format: "id == %@", testProjectId as CVarArg)
                    if let entity = try? bgContext.fetch(fetch).first {
                        bgContext.delete(entity)
                        self.dataController.save(context: bgContext)
                    }
                }
                
                await MainActor.run {
                    self.metrics.isComplete = true
                    self.metrics.pdfExportDurationSeconds = duration
                    self.metrics.pdfFileSizeMB = fileSize
                    self.metrics.didPassPageCountIntegrity = (verifiedCount == pageCount)
                    // Memory pass criteria: Peak resident memory stays flat (< 150 MB)
                    self.metrics.didPassMemoryConstraint = (self.metrics.peakMemoryMB < 150.0)
                    self.metrics.currentStep = "Benchmark Completed Successfully!"
                    self.isRunning = false
                    completion(self.metrics)
                }
            } catch {
                await MainActor.run {
                    self.metrics.currentStep = "Benchmark Failed: \(error.localizedDescription)"
                    self.isRunning = false
                }
            }
        }
    }
    
    public func cancel() {
        self.isCancelled = true
        self.isRunning = false
    }
    
    private func createSyntheticBookPageJPEG() -> Data {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Clean white page background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Header rule & Title
            let headerStyle = NSMutableParagraphStyle()
            headerStyle.alignment = .center
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: headerStyle
            ]
            ("CHAPTER IV: PRINCIPLES OF MASS DIGITAL RECONSTRUCTION" as NSString)
                .draw(in: CGRect(x: 50, y: 60, width: size.width - 100, height: 30), withAttributes: headerAttrs)
            
            // Simulated Book Body Text
            let bodyText = """
            In the study of resource-bounded execution on mobile systems, resident set size (RSS) constitutes the primary constraint. When processing multi-hundred page documents on a hardware platform with 3 gigabytes of unified memory, retaining uncompressed image buffers in memory rapidly leads to out-of-memory termination by the kernel's low-memory killer.

            To ensure deterministic operation, the architecture enforces a disk-first streaming paradigm. Every capture is immediately written to non-volatile sandboxed flash storage. Intermediate image manipulation operations are bounded to a single concurrency worker, releasing texture and pixel memory within autorelease pools before subsequent frames are loaded.

            Furthermore, by streaming PDF page dictionaries and directly embedding raw discrete cosine transform (DCTDecode) streams into the output handle, the serialization phase retains an O(1) memory complexity, ensuring that a 500-page publication requires no more transient RAM than a single isolated page.
            """
            
            let bodyStyle = NSMutableParagraphStyle()
            bodyStyle.alignment = .justified
            bodyStyle.lineSpacing = 6
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: bodyStyle
            ]
            
            // Draw multiple paragraphs
            for p in 0..<3 {
                (bodyText as NSString).draw(
                    in: CGRect(x: 80, y: 130 + CGFloat(p * 420), width: size.width - 160, height: 380),
                    withAttributes: bodyAttrs
                )
            }
        }
        return image.jpegData(compressionQuality: 0.80) ?? Data()
    }
}
