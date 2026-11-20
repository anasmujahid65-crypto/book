//
//  ExportDocumentPicker.swift
//  BookScanPDF
//
//  Wraps UIDocumentPickerViewController configured for exporting PDF files to iCloud Drive and Files.
//

import SwiftUI
import UniformTypeIdentifiers

public struct ExportDocumentPicker: UIViewControllerRepresentable {
    public let fileURL: URL
    public let onComplete: () -> Void
    
    public init(fileURL: URL, onComplete: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onComplete = onComplete
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ExportDocumentPicker
        
        init(_ parent: ExportDocumentPicker) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onComplete()
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onComplete()
        }
    }
}
