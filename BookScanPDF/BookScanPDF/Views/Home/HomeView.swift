//
//  HomeView.swift
//  BookScanPDF
//
//  Main project library screen. Provides project management, search, resume banners,
//  and entry points to camera series capture and photo library imports.
//

import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var showingOnboarding = !AppSettings.shared.hasCompletedOnboarding
    @State private var activeProjectForCamera: Project?
    @State private var activeProjectForReview: Project?
    @State private var isShowingPhotosPicker: Bool = false
    @State private var isShowingDocumentPicker: Bool = false
    @State private var pendingImportProject: Project?
    @ObservedObject private var importManager = ImportManager.shared
    
    // Adaptive grid column layout
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: Theme.spacingM)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.spacingM) {
                        // MARK: - Interrupted Session Banner
                        if let interrupted = viewModel.interruptedProject {
                            ResumeBanner(project: interrupted) {
                                activeProjectForReview = interrupted
                            }
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.top, Theme.spacingS)
                        }
                        
                        // MARK: - Projects Library
                        if viewModel.projects.isEmpty {
                            EmptyStateView(
                                title: "Scan Your First Book",
                                message: "Capture hundreds of pages offline with live alignment and export ultra-lightweight PDFs.",
                                systemImage: "books.vertical",
                                actionTitle: "Tap 'New Scan' Below"
                            )
                            .padding(.top, 40)
                        } else if viewModel.filteredProjects.isEmpty {
                            EmptyStateView(
                                title: "No Matching Scans",
                                message: "No projects match '\(viewModel.searchText)'. Try another search term.",
                                systemImage: "magnifyingglass"
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: Theme.spacingM) {
                                ForEach(viewModel.filteredProjects) { project in
                                    ProjectCardView(
                                        project: project,
                                        onTap: {
                                            activeProjectForReview = project
                                        },
                                        onRename: {
                                            viewModel.startRename(for: project)
                                        },
                                        onDuplicate: {
                                            viewModel.duplicateProject(project)
                                        },
                                        onDelete: {
                                            viewModel.deleteProject(project)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.spacingM)
                            .padding(.bottom, 96) // Space for floating button
                        }
                    }
                    .padding(.top, Theme.spacingS)
                }
                .searchable(text: $viewModel.searchText, prompt: "Search scanned books")
                
                // MARK: - Floating New Scan Action
                VStack {
                    Spacer()
                    PrimaryButton(
                        title: "New Scan",
                        icon: "plus.viewfinder",
                        variant: .accent
                    ) {
                        viewModel.isShowingNewScanSheet = true
                    }
                    .frame(maxWidth: 320)
                    .modifier(FloatingShadowModifier())
                    .padding(.bottom, Theme.spacingL)
                }
            }
            .navigationTitle("My Scans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.isShowingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.label)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewScanSheet) {
                NewScanActionSheet(
                    onSelectCamera: {
                        let newProj = viewModel.createNewProject()
                        activeProjectForCamera = newProj
                    },
                    onSelectPhotos: {
                        let newProj = viewModel.createNewProject()
                        pendingImportProject = newProj
                        isShowingPhotosPicker = true
                    },
                    onSelectFiles: {
                        let newProj = viewModel.createNewProject()
                        pendingImportProject = newProj
                        isShowingDocumentPicker = true
                    }
                )
            }
            .sheet(isPresented: $isShowingPhotosPicker) {
                if let proj = pendingImportProject {
                    PhotosPickerSheet(
                        onImagesPicked: { urls in
                            importManager.importFiles(urls: urls, into: proj, source: .photos) { _ in
                                activeProjectForReview = proj
                            }
                        },
                        onCancel: {}
                    )
                }
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                if let proj = pendingImportProject {
                    DocumentPickerSheet(
                        onDocumentsPicked: { urls in
                            importManager.importFiles(urls: urls, into: proj, source: .files) { _ in
                                activeProjectForReview = proj
                            }
                        },
                        onCancel: {}
                    )
                }
            }
            .overlay(
                ZStack {
                    if importManager.isImporting {
                        ImportProgressView {
                            importManager.cancel()
                        }
                    }
                }
            )
            .fullScreenCover(item: $activeProjectForCamera) { project in
                CameraView(project: project)
            }
            .fullScreenCover(item: $activeProjectForReview) { project in
                ReviewView(project: project)
            }
            .sheet(isPresented: $viewModel.isShowingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView(isPresented: $showingOnboarding)
            }
            .alert("Rename Scan", isPresented: $viewModel.isShowingRenameAlert) {
                TextField("Book title", text: $viewModel.renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    viewModel.commitRename()
                }
            } message: {
                Text("Enter a new title for this book scan.")
            }
            .onAppear {
                viewModel.fetchProjects()
                viewModel.checkForInterruptedSession()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Resume Banner Component
private struct ResumeBanner: View {
    let project: Project
    let onResume: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.spacingM) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Interrupted Session Found")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.label)
                
                Text("\(project.name) has unfinished pages.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryLabel)
            }
            
            Spacer()
            
            Button("Resume", action: onResume)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.accent)
                .clipShape(Capsule())
        }
        .padding(Theme.spacingM)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct FloatingShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        Theme.floatingShadow(content)
    }
}
