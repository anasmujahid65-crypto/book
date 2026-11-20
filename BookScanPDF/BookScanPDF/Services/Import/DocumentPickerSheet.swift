//
//  DocumentPickerSheet.swift
//  BookScanPDF
//
//  Wraps UIDocumentPickerViewController for importing book page scans from iCloud and Files.
//

import SwiftUI
import UniformTypeIdentifiers

public struct DocumentPickerSheet: UIViewControllerRepresentable {
    public let onDocumentsPicked: ([URL]) -> Void
    public let onCancel: () -> Void
    
    public init(onDocumentsPicked: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
        self.onDocumentsPicked = onDocumentsPicked
        self.onCancel = onCancel
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .jpeg, .png]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerSheet
        
        init(_ parent: DocumentPickerSheet) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
