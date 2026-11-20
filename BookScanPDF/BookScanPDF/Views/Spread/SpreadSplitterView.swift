//
//  SpreadSplitterView.swift
//  BookScanPDF
//
//  Interactive two-page spread splitter with auto-gutter detection,
//  draggable vertical dividing crease, and Right-to-Left (Urdu/Arabic/Hebrew) reading order.
//

import SwiftUI
import CoreData

public struct SpreadSplitterView: View {
    public let page: Page
    public let project: Project
    public let onSplitComplete: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var spreadImage: UIImage? = nil
    @State private var splitX: CGFloat = 0.50
    @State private var isRightToLeft: Bool = false
    @State private var isSplitting: Bool = false
    
    private let dataController = DataController.shared
    
    public init(page: Page, project: Project, onSplitComplete: @escaping () -> Void) {
        self.page = page
        self.project = project
        self.onSplitComplete = onSplitComplete
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Top Bar
                    HStack {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        
                        Spacer()
                        
                        Text("Split Two-Page Spread")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: executeSplit) {
                            if isSplitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                            } else {
                                Text("Split")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .disabled(isSplitting || spreadImage == nil)
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 8 : 16)
                    
                    // MARK: - Interactive Spread Canvas
                    ZStack {
                        if let image = spreadImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    GeometryReader { imgGeo in
                                        let w = imgGeo.size.width
                                        let h = imgGeo.size.height
                                        let splitPos = splitX * w
                                        
                                        ZStack {
                                            // Vertical Seam Divider Line
                                            Path { path in
                                                path.move(to: CGPoint(x: splitPos, y: 0))
                                                path.addLine(to: CGPoint(x: splitPos, y: h))
                                            }
                                            .stroke(
                                                Theme.accent,
                                                style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                                            )
                                            
                                            // Draggable Center Seam Handle
                                            ZStack {
                                                Circle()
                                                    .fill(Theme.accent)
                                                    .frame(width: 38, height: 38)
                                                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                                                
                                                Image(systemName: "arrow.left.and.right")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            .position(x: splitPos, y: h / 2)
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        let newX = value.location.x / w
                                                        splitX = max(0.25, min(0.75, newX))
                                                    }
                                            )
                                            
                                            // Page Index Preview Badges
                                            VStack {
                                                HStack {
                                                    // Left Page Badge
                                                    Text(isRightToLeft ? "Page \(page.orderIndex + 2)" : "Page \(page.orderIndex + 1)")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(Color.black.opacity(0.7))
                                                        .clipShape(Capsule())
                                                        .padding(10)
                                                    
                                                    Spacer()
                                                    
                                                    // Right Page Badge
                                                    Text(isRightToLeft ? "Page \(page.orderIndex + 1)" : "Page \(page.orderIndex + 2)")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(Color.black.opacity(0.7))
                                                        .clipShape(Capsule())
                                                        .padding(10)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                )
                                .padding(Theme.spacingM)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // MARK: - Reading Order & Controls Dock
                    VStack(spacing: Theme.spacingM) {
                        Toggle(isOn: $isRightToLeft) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Right-to-Left Book Order")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Right page is read first (Urdu, Arabic, Hebrew, Manga)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.secondaryLabel)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        
                        PrimaryButton(
                            title: "Split into 2 Pages",
                            icon: "arrow.triangle.split",
                            variant: .accent,
                            isLoading: isSplitting
                        ) {
                            executeSplit()
                        }
                    }
                    .padding(Theme.spacingL)
                    .background(Color.black.opacity(0.85).ignoresSafeArea())
                }
            }
        }
        .onAppear {
            loadWorkingImage()
        }
    }
    
    private func loadWorkingImage() {
        let path = page.processedPath ?? page.originalPath
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            if let img = ImageDownsampler.downsample(imageAt: url, maxDimension: 1800) {
                let detectedSplit = GutterDetector.detectGutterSeam(in: img)
                DispatchQueue.main.async {
                    self.spreadImage = img
                    self.splitX = detectedSplit
                }
            }
        }
    }
    
    private func executeSplit() {
        isSplitting = true
        let parentPageId = page.id
        let origPath = page.originalPath
        let currentOrder = page.orderIndex
        let splitValue = splitX
        let rtl = isRightToLeft
        let parentEdit = page.edit
        
        let bgContext = dataController.newBackgroundContext()
        bgContext.performAndWait {
            // Delete original spread page entity
            let fetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", parentPageId as CVarArg)
            if let parentEntity = try? bgContext.fetch(fetch).first {
                bgContext.delete(parentEntity)
            }
            
            // Define left and right quads
            let leftQuad = NormalizedQuad(
                topLeft: CGPoint(x: 0.0, y: 1.0),
                topRight: CGPoint(x: splitValue, y: 1.0),
                bottomRight: CGPoint(x: splitValue, y: 0.0),
                bottomLeft: CGPoint(x: 0.0, y: 0.0)
            )
            
            let rightQuad = NormalizedQuad(
                topLeft: CGPoint(x: splitValue, y: 1.0),
                topRight: CGPoint(x: 1.0, y: 1.0),
                bottomRight: CGPoint(x: 1.0, y: 0.0),
                bottomLeft: CGPoint(x: splitValue, y: 0.0)
            )
            
            // Determine reading order
            let (firstQuad, secondQuad) = rtl ? (rightQuad, leftQuad) : (leftQuad, rightQuad)
            
            // Child 1
            let child1 = PageEntity(context: bgContext)
            child1.id = UUID()
            child1.projectId = self.project.id
            child1.orderIndex = Int32(currentOrder)
            child1.originalPath = origPath
            child1.status = PageStatus.pending.rawValue
            child1.source = CaptureSource.camera.rawValue
            child1.isSplitChild = true
            child1.createdAt = Date()
            
            var edit1 = parentEdit
            edit1.cropCorners = firstQuad
            edit1.isUserModified = true
            child1.editData = edit1.encodeToData()
            
            // Child 2
            let child2 = PageEntity(context: bgContext)
            child2.id = UUID()
            child2.projectId = self.project.id
            child2.orderIndex = Int32(currentOrder + 1)
            child2.originalPath = origPath
            child2.status = PageStatus.pending.rawValue
            child2.source = CaptureSource.camera.rawValue
            child2.isSplitChild = true
            child2.createdAt = Date().addingTimeInterval(0.1)
            
            var edit2 = parentEdit
            edit2.cropCorners = secondQuad
            edit2.isUserModified = true
            child2.editData = edit2.encodeToData()
            
            // Shift subsequent pages' orderIndex up by 1
            let subsequentFetch: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            subsequentFetch.predicate = NSPredicate(
                format: "projectId == %@ AND orderIndex > %d AND id != %@ AND id != %@",
                self.project.id as CVarArg,
                currentOrder,
                child1.id as CVarArg,
                child2.id as CVarArg
            )
            if let laterPages = try? bgContext.fetch(subsequentFetch) {
                for later in laterPages {
                    later.orderIndex += 1
                }
            }
            
            // Update project page count
            let projFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projFetch.predicate = NSPredicate(format: "id == %@", self.project.id as CVarArg)
            if let projEntity = try? bgContext.fetch(projFetch).first {
                projEntity.pageCount += 1
                projEntity.updatedAt = Date()
                child1.project = projEntity
                child2.project = projEntity
            }
            
            self.dataController.save(context: bgContext)
            
            // Queue both new pages for perspective correction & thumbnail rendering
            ProcessingQueue.shared.enqueue(pageId: child1.id, projectId: self.project.id, isPriority: true)
            ProcessingQueue.shared.enqueue(pageId: child2.id, projectId: self.project.id, isPriority: true)
        }
        
        DispatchQueue.main.async {
            self.isSplitting = false
            self.onSplitComplete()
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}
