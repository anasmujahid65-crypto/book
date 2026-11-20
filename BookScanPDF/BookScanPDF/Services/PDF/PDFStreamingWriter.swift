//
//  PDFStreamingWriter.swift
//  BookScanPDF
//
//  Ultra-lightweight streaming PDF generator. Streams page by page directly to a FileHandle,
//  embedding raw JPEG bytes as /DCTDecode image XObjects without decoding or re-compressing.
//  Maintains strictly flat O(1) memory consumption for 500+ page book scans.
//

import Foundation
import CoreGraphics

public struct PDFPageMetadata {
    public let width: Int
    public let height: Int
    public let isGrayscale: Bool
}

public final class PDFStreamingWriter {
    private let destinationURL: URL
    private var fileHandle: FileHandle?
    private var currentOffset: UInt64 = 0
    private var objectOffsets: [UInt64] = []
    
    public init(destinationURL: URL) {
        self.destinationURL = destinationURL
    }
    
    // MARK: - JPEG SOF Header Parser
    
    /// Reads JPEG dimensions and channel count directly from SOF0/SOF2 markers without decoding pixel memory.
    public static func parseJPEGMetadata(data: Data) -> PDFPageMetadata? {
        var index = 0
        let count = data.count
        guard count > 4, data[0] == 0xFF, data[1] == 0xD8 else { return nil } // SOI check
        index += 2
        
        while index < count - 8 {
            guard data[index] == 0xFF else {
                index += 1
                continue
            }
            let marker = data[index + 1]
            
            // SOF0 (Baseline) or SOF2 (Progressive)
            if marker == 0xC0 || marker == 0xC2 {
                let height = Int(data[index + 5]) << 8 | Int(data[index + 6])
                let width = Int(data[index + 7]) << 8 | Int(data[index + 8])
                let components = Int(data[index + 9])
                return PDFPageMetadata(width: width, height: height, isGrayscale: components == 1)
            }
            
            // Skip marker segment
            let segmentLength = Int(data[index + 2]) << 8 | Int(data[index + 3])
            index += 2 + segmentLength
        }
        return nil
    }
    
    // MARK: - Streaming Generation
    
    /// Writes complete PDF by reading page JPEG files one-by-one from disk.
    public func writePDF(
        pageURLs: [URL],
        pageSizeOption: PageSizeOption,
        ocrEnabled: Bool = false,
        progress: @escaping (Int, Int) -> Void
    ) async throws {
        // Create fresh file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
        let handle = try FileHandle(forWritingTo: destinationURL)
        self.fileHandle = handle
        self.currentOffset = 0
        self.objectOffsets = [0] // 0-index unused in PDF xref
        
        let totalPages = pageURLs.count
        
        // 1. PDF Header
        try writeString("%PDF-1.4\n%\u{00E2}\u{00E3}\u{00CF}\u{00D3}\n")
        
        // Object IDs reservation:
        // Object 1: Catalog
        // Object 2: Pages Root
        // For each page i (1...N):
        //   Object (3 + (i-1)*3): Page Object
        //   Object (4 + (i-1)*3): Content Stream
        //   Object (5 + (i-1)*3): Image XObject
        
        // Placeholder for Catalog and Pages tree
        recordObjectOffset(objectNumber: 1)
        try writeString("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        
        // Write Pages Root
        recordObjectOffset(objectNumber: 2)
        var kidsString = ""
        for i in 1...totalPages {
            let pageObjNum = 3 + (i - 1) * 3
            kidsString += "\(pageObjNum) 0 R "
        }
        try writeString("2 0 obj\n<< /Type /Pages /Kids [\(kidsString)] /Count \(totalPages) >>\nendobj\n")
        
        // 2. Stream Page Objects & Direct JPEG Image Streams
        for (index, pageURL) in pageURLs.enumerated() {
            let pageIndex = index + 1
            let pageObjNum = 3 + (pageIndex - 1) * 3
            let contentObjNum = pageObjNum + 1
            let imageObjNum = pageObjNum + 2
            
            // Read raw JPEG bytes from disk
            let jpegData = try Data(contentsOf: pageURL, options: .alwaysMapped)
            let metadata = Self.parseJPEGMetadata(data: jpegData) ?? PDFPageMetadata(width: 1500, height: 2000, isGrayscale: false)
            
            let imgW = CGFloat(metadata.width)
            let imgH = CGFloat(metadata.height)
            
            // Calculate PDF Page MediaBox & Image Placement
            let (pageW, pageH, drawX, drawY, drawW, drawH) = computeLayout(
                imageWidth: imgW,
                imageHeight: imgH,
                option: pageSizeOption
            )
            
            // Page Object
            let fontResource = ocrEnabled ? "/Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> " : ""
            recordObjectOffset(objectNumber: pageObjNum)
            try writeString(
                "\(pageObjNum) 0 obj\n" +
                "<< /Type /Page /Parent 2 0 R " +
                "/MediaBox [0 0 \(String(format: "%.2f %.2f", pageW, pageH))] " +
                "/Contents \(contentObjNum) 0 R " +
                "/Resources << /XObject << /Im0 \(imageObjNum) 0 R >> \(fontResource)>> >>\n" +
                "endobj\n"
            )
            
            // Content Stream Object (places and scales image on the page)
            var contentCommands = String(
                format: "q\n%.2f 0 0 %.2f %.2f %.2f cm\n/Im0 Do\nQ\n",
                drawW, drawH, drawX, drawY
            )
            
            // Append invisible searchable OCR text layer if enabled
            if ocrEnabled {
                let recognizedLines = await OCREngine.shared.recognizeText(in: pageURL)
                let textCommands = OCREngine.generateInvisibleTextOperators(
                    lines: recognizedLines,
                    pageWidth: pageW,
                    pageHeight: pageH
                )
                contentCommands += textCommands
            }
            
            let contentData = contentCommands.data(using: .utf8) ?? contentCommands.data(using: .ascii)!
            
            recordObjectOffset(objectNumber: contentObjNum)
            try writeString(
                "\(contentObjNum) 0 obj\n" +
                "<< /Length \(contentData.count) >>\n" +
                "stream\n"
            )
            try writeData(contentData)
            try writeString("\nendstream\nendobj\n")
            
            // Image XObject with raw DCTDecode (Direct JPEG Byte Passthrough)
            let colorSpaceString = metadata.isGrayscale ? "/DeviceGray" : "/DeviceRGB"
            recordObjectOffset(objectNumber: imageObjNum)
            try writeString(
                "\(imageObjNum) 0 obj\n" +
                "<< /Type /XObject /Subtype /Image " +
                "/Width \(metadata.width) /Height \(metadata.height) " +
                "/ColorSpace \(colorSpaceString) /BitsPerComponent 8 " +
                "/Filter /DCTDecode /Length \(jpegData.count) >>\n" +
                "stream\n"
            )
            try writeData(jpegData)
            try writeString("\nendstream\nendobj\n")
            
            progress(pageIndex, totalPages)
        }
        
        // 3. Cross-Reference Table (xref)
        let startXref = currentOffset
        let totalObjects = 2 + totalPages * 3
        try writeString("xref\n0 \(totalObjects + 1)\n")
        try writeString("0000000000 65535 f \n")
        
        for i in 1...totalObjects {
            let offset = objectOffsets[i]
            let offsetFormatted = String(format: "%010llu 00000 n \n", offset)
            try writeString(offsetFormatted)
        }
        
        // 4. Trailer & EOF
        try writeString(
            "trailer\n" +
            "<< /Size \(totalObjects + 1) /Root 1 0 R >>\n" +
            "startxref\n" +
            "\(startXref)\n" +
            "%%EOF\n"
        )
        
        try handle.close()
        self.fileHandle = nil
    }
    
    // MARK: - Geometry Computation
    
    private func computeLayout(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        option: PageSizeOption
    ) -> (pageW: CGFloat, pageH: CGFloat, drawX: CGFloat, drawY: CGFloat, drawW: CGFloat, drawH: CGFloat) {
        switch option {
        case .fit:
            // Normalize to ~150 DPI PDF points (72 / 150 = 0.48 scale)
            let scale: CGFloat = 72.0 / 150.0
            let pw = imageWidth * scale
            let ph = imageHeight * scale
            return (pw, ph, 0, 0, pw, ph)
            
        case .a4, .letter:
            let dims = option.dimensions ?? (595.28, 841.89)
            let pw = dims.width
            let ph = dims.height
            
            let scaleX = pw / imageWidth
            let scaleY = ph / imageHeight
            let scale = min(scaleX, scaleY) * 0.94 // 3% margin around page
            
            let dw = imageWidth * scale
            let dh = imageHeight * scale
            let dx = (pw - dw) / 2.0
            let dy = (ph - dh) / 2.0
            
            return (pw, ph, dx, dy, dw, dh)
        }
    }
    
    // MARK: - Byte Writing Primitives
    
    private func recordObjectOffset(objectNumber: Int) {
        while objectOffsets.count <= objectNumber {
            objectOffsets.append(0)
        }
        objectOffsets[objectNumber] = currentOffset
    }
    
    private func writeString(_ string: String) throws {
        guard let data = string.data(using: .ascii) else { return }
        try writeData(data)
    }
    
    private func writeData(_ data: Data) throws {
        guard let handle = fileHandle else { return }
        try handle.write(contentsOf: data)
        currentOffset += UInt64(data.count)
    }
}
