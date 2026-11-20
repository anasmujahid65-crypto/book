//
//  PDFPreviewView.swift
//  BookScanPDF
//
//  Wraps PDFKit's PDFView in a SwiftUI UIViewRepresentable for high-fidelity in-app PDF preview.
//

import SwiftUI
import PDFKit

public struct PDFPreviewView: UIViewRepresentable {
    public let documentURL: URL
    
    public init(documentURL: URL) {
        self.documentURL = documentURL
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: documentURL)
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != documentURL {
            uiView.document = PDFDocument(url: documentURL)
        }
    }
}
