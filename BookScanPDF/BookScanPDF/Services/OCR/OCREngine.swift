//
//  OCREngine.swift
//  BookScanPDF
//
//  On-device optical character recognition using Vision (VNRecognizeTextRequest).
//  Generates invisible text rendering commands (PDF render mode 3 Tr) placed at exact bounding box coordinates.
//
//  Platform Note: Vision on iOS 15 provides robust on-device offline OCR for Latin-script languages
//  (English, Spanish, French, German, Italian, Portuguese). Non-Latin scripts (e.g. Urdu/Arabic)
//  are not supported by offline Vision on iOS 15.
//

import Foundation
import Vision
import CoreGraphics

public struct RecognizedTextLine {
    public let text: String
    public let boundingBox: CGRect // Normalized (0.0 - 1.0), bottom-left origin
}

public final class OCREngine {
    public static let shared = OCREngine()
    
    private init() {}
    
    /// Performs on-device text recognition on a processed page image.
    public func recognizeText(in imageURL: URL) async -> [RecognizedTextLine] {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var lines: [RecognizedTextLine] = []
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    lines.append(
                        RecognizedTextLine(
                            text: topCandidate.string,
                            boundingBox: observation.boundingBox
                        )
                    )
                }
                continuation.resume(returning: lines)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Generates PDF content stream operators for an invisible searchable text layer.
    /// Uses PDF text rendering mode 3 (3 Tr = Neither fill nor stroke text, invisible but searchable).
    public static func generateInvisibleTextOperators(
        lines: [RecognizedTextLine],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> String {
        guard !lines.isEmpty else { return "" }
        
        var commands = "\nBT\n/F1 10 Tf\n3 Tr\n" // Begin text, Font /F1 10pt, Render mode 3 (Invisible)
        
        for line in lines {
            // Escape special PDF string characters: \, (, )
            let escapedText = line.text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "(", with: "\\(")
                .replacingOccurrences(of: ")", with: "\\)")
            
            // Map normalized coordinates to page point dimensions
            let x = line.boundingBox.origin.x * pageWidth
            let y = line.boundingBox.origin.y * pageHeight
            let fontSize = max(6.0, line.boundingBox.size.height * pageHeight * 0.85)
            
            // Position text at baseline and draw
            commands += String(
                format: "/F1 %.2f Tf\n1 0 0 1 %.2f %.2f Tm\n(%@) Tj\n",
                fontSize, x, y, escapedText
            )
        }
        
        commands += "ET\n" // End text
        return commands
    }
}
