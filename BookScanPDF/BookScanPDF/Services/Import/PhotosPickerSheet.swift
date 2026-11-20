//
//  PhotosPickerSheet.swift
//  BookScanPDF
//
//  Wraps PHPickerViewController (iOS 15.0 compatible) for multi-image selection.
//  Uses loadFileRepresentation rather than loading UIImages to prevent 3 GB memory crashes.
//

import SwiftUI
import PhotosUI

public struct PhotosPickerSheet: UIViewControllerRepresentable {
    public let onImagesPicked: ([URL]) -> Void
    public let onCancel: () -> Void
    
    public init(onImagesPicked: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
        self.onImagesPicked = onImagesPicked
        self.onCancel = onCancel
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0 // 0 = unlimited multi-select
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPickerSheet
        
        init(_ parent: PhotosPickerSheet) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else {
                parent.onCancel()
                return
            }
            
            // Extract file representations to temporary sandbox asynchronously
            let group = DispatchGroup()
            var temporaryURLs: [URL] = []
            let queue = DispatchQueue(label: "com.bookscan.import.load")
            
            for result in results {
                let provider = result.itemProvider
                if provider.hasItemConformingToTypeIdentifier("public.image") {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                        defer { group.leave() }
                        guard let sourceURL = url, error == nil else { return }
                        
                        // Copy to unique temp file before PHPicker clears its sandboxed copy
                        let tempDest = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension)
                        
                        do {
                            try FileManager.default.copyItem(at: sourceURL, to: tempDest)
                            queue.async {
                                temporaryURLs.append(tempDest)
                            }
                        } catch {
                            print("[PhotosPicker] Failed to copy imported file: \(error)")
                        }
                    }
                }
            }
            
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.parent.onImagesPicked(temporaryURLs)
            }
        }
    }
}
