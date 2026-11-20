//
//  SettingsView.swift
//  BookScanPDF
//
//  Dedicated Settings screen housing the "Apply Page 1 settings to all pages" toggle,
//  capture parameters, processing defaults, storage analytics, and offline privacy details.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var storageUsedBytes: Int64 = 0
    @State private var isClearingCache: Bool = false
    @State private var showCacheClearedAlert: Bool = false
    @State private var showStressTest: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                // MARK: - Auto-Apply Section (Headline Feature)
                Section {
                    Toggle(isOn: $settings.autoApplyPage1Settings) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apply Page 1 Edits to All Pages")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.label)
                            Text("Automatically cascades filter, rotation, brightness, and contrast from Page 1 to all subsequent captures.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Theme.secondaryLabel)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    
                    if settings.autoApplyPage1Settings {
                        Toggle(isOn: $settings.reusePage1CropArea) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reuse Page 1 Crop Rectangle")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Best when shooting with a stationary tripod or book stand.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Theme.secondaryLabel)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.primaryLight))
                    }
                } header: {
                    Text("Auto-Apply Pipeline")
                } footer: {
                    Text("Pages that you manually fine-tune in the editor are marked as custom and will never be overwritten by automatic cascades.")
                }
                
                // MARK: - Capture Options
                Section(header: Text("Camera & Viewfinder")) {
                    Picker("Default Flash", selection: $settings.flashDefault) {
                        ForEach(FlashModeSetting.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    Toggle("Show Alignment Grid", isOn: $settings.gridDefault)
                    Toggle("Shutter Audio Sound", isOn: $settings.shutterSoundEnabled)
                    Toggle("Haptic Feedback on Green", isOn: $settings.hapticsEnabled)
                    
                    Picker("Indicator Sensitivity", selection: $settings.indicatorSensitivity) {
                        ForEach(IndicatorSensitivity.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                }
                
                // MARK: - Processing Options
                Section(header: Text("Image Processing Engine")) {
                    Picker("Default Filter", selection: $settings.defaultFilter) {
                        ForEach(FilterType.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    
                    Toggle("Auto-Detect Page Edges", isOn: $settings.autoDetectEdges)
                    
                    Picker("Performance Profile", selection: $settings.performanceMode) {
                        ForEach(PerformanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                // MARK: - PDF Defaults
                Section(header: Text("PDF Generation Defaults")) {
                    Picker("Quality Preset", selection: $settings.defaultPDFPreset) {
                        ForEach(PDFPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    
                    Picker("Default Page Size", selection: $settings.defaultPageSize) {
                        ForEach(PageSizeOption.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    
                    Toggle("Enable OCR Searchable Text Layer", isOn: $settings.ocrEnabledDefault)
                }
                
                // MARK: - Appearance
                Section(header: Text("Appearance")) {
                    Picker("App Theme", selection: $settings.themeMode) {
                        ForEach(AppThemeMode.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                
                // MARK: - Storage & Cache
                Section(header: Text("Storage & Cache")) {
                    HStack {
                        Text("App Storage Used")
                        Spacer()
                        Text(formattedBytes(storageUsedBytes))
                            .foregroundColor(Theme.secondaryLabel)
                    }
                    
                    Toggle("Delete Originals After PDF Export", isOn: $settings.deleteOriginalsAfterExport)
                    
                    Button(action: clearTemporaryCaches) {
                        HStack {
                            Text("Clear Temporary Cache")
                                .foregroundColor(Theme.errorRed)
                            if isClearingCache {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isClearingCache)
                }
                
                // MARK: - Diagnostics & Benchmarks
                Section(header: Text("Diagnostics & Hardware Benchmarks")) {
                    Button(action: { showStressTest = true }) {
                        Label("Run 500-Page Stress Benchmark", systemImage: "gauge.badge.plus")
                            .foregroundColor(Theme.accent)
                    }
                }
                
                // MARK: - About & Offline Privacy
                Section(header: Text("Privacy & Device Architecture")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(Theme.secondaryLabel)
                    }
                    
                    HStack {
                        Text("Architecture Target")
                        Spacer()
                        Text("iOS 15.0+ / A10 Fusion 3GB")
                            .foregroundColor(Theme.secondaryLabel)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("100% Offline by Design", systemImage: "shield.checkerboard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.successGreen)
                        
                        Text("BookScan PDF has zero networking code, zero tracking, and zero remote analytics. All page detection, perspective correction, filtering, OCR, and PDF assembly execute strictly on your device.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Theme.secondaryLabel)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.primaryLight)
                }
            }
            .onAppear {
                calculateStorage()
            }
            .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Temporary cache files have been freed.")
            }
            .sheet(isPresented: $showStressTest) {
                StressTestView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func calculateStorage() {
        DispatchQueue.global(qos: .utility).async {
            let used = DiskStorageManager.shared.calculateStorageUsed()
            DispatchQueue.main.async {
                self.storageUsedBytes = used
            }
        }
    }
    
    private func clearTemporaryCaches() {
        isClearingCache = true
        DispatchQueue.global(qos: .utility).async {
            // Clears any unreferenced temp files in tmp/ directory
            let tmpDir = FileManager.default.temporaryDirectory
            if let urls = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
                for url in urls {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            let used = DiskStorageManager.shared.calculateStorageUsed()
            DispatchQueue.main.async {
                self.storageUsedBytes = used
                self.isClearingCache = false
                self.showCacheClearedAlert = true
            }
        }
    }
    
    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
