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
import ImageIO

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
    
    // MARK: - JPEG Header Metadata Parser
    
    /// Reads exact JPEG dimensions and color space directly from the file header
    /// without decoding pixel bitmaps into memory, ensuring zero memory spikes.
    public static func parseJPEGMetadata(data: Data) -> PDFPageMetadata? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any] else {
            // Fallback manual SOF marker check if CGImageSource fails
            return fallbackParseSOF(data: data)
        }
        
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 1500
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 2000
        let colorModel = properties[kCGImagePropertyColorModel] as? String
        let isGray = (colorModel == (kCGImagePropertyColorModelGray as String))
        
        return PDFPageMetadata(width: width, height: height, isGrayscale: isGray)
    }
    
    private static func fallbackParseSOF(data: Data) -> PDFPageMetadata? {
        var index = 0
        let count = data.count
        guard count > 4, data[0] == 0xFF, data[1] == 0xD8 else { return nil }
        index += 2
        
        while index < count - 8 {
            guard data[index] == 0xFF else {
                index += 1
                continue
            }
            let marker = data[index + 1]
            if marker == 0xC0 || marker == 0xC1 || marker == 0xC2 {
                let height = Int(data[index + 5]) << 8 | Int(data[index + 6])
                let width = Int(data[index + 7]) << 8 | Int(data[index + 8])
                let components = Int(data[index + 9])
                return PDFPageMetadata(width: width, height: height, isGrayscale: components == 1)
            }
            if marker == 0xDA || marker == 0xD9 { break } // Stop at SOS/EOI
            let segmentLength = Int(data[index + 2]) << 8 | Int(data[index + 3])
            guard segmentLength >= 2 else { break }
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
        
        // 1. PDF Header: %PDF-1.4 followed by binary comment marker (> 127)
        let headerBytes: [UInt8] = [
            0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, // %PDF-1.4\n
            0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A                   // %âãÏÓ\n (binary comment)
        ]
        try writeData(Data(headerBytes))
        
        // Object IDs reservation:
        // Object 1: Catalog
        // Object 2: Pages Root
        // For each page i (1...N):
        //   Object (3 + (i-1)*3): Page Object
        //   Object (4 + (i-1)*3): Content Stream
        //   Object (5 + (i-1)*3): Image XObject
        
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
        try writeString("0000000000 65535 f \r\n")
        
        for i in 1...totalObjects {
            let offset = objectOffsets[i]
            let offsetFormatted = String(format: "%010llu 00000 n \r\n", offset)
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
        guard let data = string.data(using: .utf8) else { return }
        try writeData(data)
    }
    
    private func writeData(_ data: Data) throws {
        guard let handle = fileHandle else { return }
        try handle.write(contentsOf: data)
        currentOffset += UInt64(data.count)
    }
}
