//
//  ReviewView.swift
//  BookScanPDF
//
//  Workspace for organizing, reordering, multi-selecting, batch adjusting,
//  and adding pages to the ongoing book scan before PDF generation.
//

import SwiftUI

public struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Adaptive multi-column grid
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: Theme.spacingM)
    ]
    
    public init(project: Project) {
        _viewModel = StateObject(wrappedValue: ReviewViewModel(project: project))
    }
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Toast Banner
                    if let toast = viewModel.toastMessage {
                        ToastPill(message: toast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 8)
                    }
                    
                    // MARK: - Pages Grid
                    if viewModel.pages.isEmpty {
                        EmptyStateView(
                            title: "No Pages Yet",
                            message: "Tap 'Add Pages' to scan pages into this book.",
                            systemImage: "doc.badge.plus",
                            actionTitle: "Open Camera",
                            action: { viewModel.isShowingCamera = true }
                        )
                        .padding(.top, 60)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: Theme.spacingM) {
                                ForEach(viewModel.pages) { page in
                                    PageThumbnailCell(
                                        page: page,
                                        isSelected: viewModel.selectedPageIds.contains(page.id),
                                        isSelectMode: viewModel.isSelectMode,
                                        onTap: {
                                            if viewModel.isSelectMode {
                                                viewModel.toggleSelection(for: page.id)
                                            } else {
                                                viewModel.selectedPageForEditor = page
                                            }
                                        },
                                        onRotate: {
                                            viewModel.batchRotateSelected()
                                        },
                                        onDelete: {
                                            viewModel.deletePage(page)
                                        },
                                        onRetry: {
                                            viewModel.retryFailedPage(page)
                                        },
                                        onRetake: {
                                            viewModel.retakePageId = page.id
                                            viewModel.isShowingCamera = true
                                        },
                                        onSplitSpread: {
                                            viewModel.selectedPageForSpreadSplit = page
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.top, Theme.spacingM)
                            .padding(.bottom, 120) // Clearance for bottom bar
                        }
                    }
                }
                
                // MARK: - Multi-Select Batch Actions Bar
                if viewModel.isSelectMode && !viewModel.selectedPageIds.isEmpty {
                    BatchActionBar(
                        selectedCount: viewModel.selectedPageIds.count,
                        onRotate: { viewModel.batchRotateSelected() },
                        onFilter: { filter in viewModel.batchApplyFilter(filter) },
                        onApplyPage1: { viewModel.applyPage1SettingsToAll() },
                        onDelete: { viewModel.deleteSelectedPages() }
                    )
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, 80)
                }
                
                // MARK: - Bottom Primary Action Bar
                VStack {
                    Spacer()
                    BottomReviewBar(
                        pageCount: viewModel.pages.count,
                        onAddMore: { viewModel.isShowingCamera = true },
                        onExport: { viewModel.isShowingExport = true }
                    )
                }
            }
            .navigationTitle(viewModel.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.primaryLight)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(viewModel.isSelectMode ? "Cancel" : "Select") {
                            withAnimation {
                                viewModel.isSelectMode.toggle()
                                if !viewModel.isSelectMode {
                                    viewModel.selectedPageIds.removeAll()
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        
                        Menu {
                            Button(action: { viewModel.isShowingPhotosImport = true }) {
                                Label("Import from Photos", systemImage: "photo.on.rectangle")
                            }
                            Button(action: { viewModel.isShowingDocumentImport = true }) {
                                Label("Import from Files", systemImage: "folder.badge.plus")
                            }
                            Divider()
                            Button(action: { viewModel.isShowingRenameAlert = true }) {
                                Label("Rename Scan", systemImage: "pencil")
                            }
                            Button(action: { viewModel.applyPage1SettingsToAll() }) {
                                Label("Apply Page 1 to All", systemImage: "wand.and.stars")
                            }
                            Button(action: { viewModel.selectAll() }) {
                                Label(viewModel.selectedPageIds.count == viewModel.pages.count ? "Deselect All" : "Select All", systemImage: "checklist")
                            }
                            Divider()
                            Button(action: { viewModel.isShowingSettings = true }) {
                                Label("Scan Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.label)
                        }
                    }
                }
            }
            .fullScreenCover(item: $viewModel.selectedPageForEditor) { page in
                PageEditorView(page: page, project: viewModel.project) {
                    viewModel.fetchPages()
                }
            }
            .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
                CameraView(project: viewModel.project)
            }
            .sheet(item: $viewModel.selectedPageForSpreadSplit) { page in
                SpreadSplitterView(page: page, project: viewModel.project) {
                    viewModel.fetchPages()
                }
            }
            .sheet(isPresented: $viewModel.isShowingPhotosImport) {
                PhotosPickerSheet(
                    onImagesPicked: { urls in
                        ImportManager.shared.importFiles(urls: urls, into: viewModel.project, source: .photos) { _ in
                            viewModel.fetchPages()
                        }
                    },
                    onCancel: {}
                )
            }
            .sheet(isPresented: $viewModel.isShowingDocumentImport) {
                DocumentPickerSheet(
                    onDocumentsPicked: { urls in
                        ImportManager.shared.importFiles(urls: urls, into: viewModel.project, source: .files) { _ in
                            viewModel.fetchPages()
                        }
                    },
                    onCancel: {}
                )
            }
            .sheet(isPresented: $viewModel.isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $viewModel.isShowingExport) {
                ExportView(project: viewModel.project)
            }
            .overlay(
                ZStack {
                    if ImportManager.shared.isImporting {
                        ImportProgressView {
                            ImportManager.shared.cancel()
                        }
                    }
                }
            )
            .alert("Rename Scan", isPresented: $viewModel.isShowingRenameAlert) {
                TextField("Book Title", text: $viewModel.renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    viewModel.commitRename()
                }
            }
            .onAppear {
                viewModel.fetchPages()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Bottom Review Navigation Bar
private struct BottomReviewBar: View {
    let pageCount: Int
    let onAddMore: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.spacingM) {
            // Add More Pages Button (Continues Series)
            Button(action: onAddMore) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 16, weight: .bold))
                    Text("Add Pages")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(Theme.label)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }
            
            // Export PDF Primary CTA
            Button(action: onExport) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Export PDF")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(pageCount > 0 ? Theme.accent : Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            }
            .disabled(pageCount == 0)
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.vertical, Theme.spacingM)
        .background(
            Theme.background
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -4)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Batch Action Bar Component
private struct BatchActionBar: View {
    let selectedCount: Int
    let onRotate: () -> Void
    let onFilter: (FilterType) -> Void
    let onApplyPage1: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(selectedCount) Selected")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.label)
            
            Spacer()
            
            Button(action: onRotate) {
                Image(systemName: "rotate.right")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.label)
            }
            
            Menu {
                ForEach(FilterType.allCases) { filter in
                    Button(action: { onFilter(filter) }) {
                        Label(filter.displayName, systemImage: filter.iconName)
                    }
                }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.label)
            }
            
            Button(action: onApplyPage1) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.label)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.errorRed)
            }
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.vertical, 12)
        .background(Theme.secondaryBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, Theme.spacingM)
    }
}

// MARK: - Toast Pill Component
private struct ToastPill: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.successGreen)
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
    }
}
