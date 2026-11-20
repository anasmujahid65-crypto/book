//
//  AppSettings.swift
//  BookScanPDF
//
//  Central settings storage backing all user preferences via UserDefaults.
//

import Foundation
import SwiftUI
import CoreData

public enum FlashModeSetting: String, CaseIterable, Identifiable {
    case off = "off"
    case auto = "auto"
    case on = "on"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .auto: return "Auto"
        case .on: return "On"
        }
    }
}

public enum IndicatorSensitivity: String, CaseIterable, Identifiable {
    case relaxed = "relaxed"
    case normal = "normal"
    case strict = "strict"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .relaxed: return "Relaxed (±9°)"
        case .normal: return "Normal (±6°)"
        case .strict: return "Strict (±3°)"
        }
    }
    
    public var angleToleranceDegrees: Double {
        switch self {
        case .relaxed: return 9.0
        case .normal: return 6.0
        case .strict: return 3.0
        }
    }
}

public enum PerformanceMode: String, CaseIterable, Identifiable {
    case auto = "auto"
    case batterySaver = "batterySaver"
    case maxQuality = "maxQuality"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .auto: return "Auto (Balanced)"
        case .batterySaver: return "Battery Saver"
        case .maxQuality: return "Maximum Quality"
        }
    }
}

public enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Onboarding
    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    
    // MARK: - Auto-Apply (Headline Feature)
    @Published public var autoApplyPage1Settings: Bool {
        didSet { defaults.set(autoApplyPage1Settings, forKey: "autoApplyPage1Settings") }
    }
    
    @Published public var reusePage1CropArea: Bool {
        didSet { defaults.set(reusePage1CropArea, forKey: "reusePage1CropArea") }
    }
    
    // MARK: - Capture Preferences
    @Published public var flashDefault: FlashModeSetting {
        didSet { defaults.set(flashDefault.rawValue, forKey: "flashDefault") }
    }
    
    @Published public var gridDefault: Bool {
        didSet { defaults.set(gridDefault, forKey: "gridDefault") }
    }
    
    @Published public var shutterSoundEnabled: Bool {
        didSet { defaults.set(shutterSoundEnabled, forKey: "shutterSoundEnabled") }
    }
    
    @Published public var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    
    @Published public var indicatorSensitivity: IndicatorSensitivity {
        didSet { defaults.set(indicatorSensitivity.rawValue, forKey: "indicatorSensitivity") }
    }
    
    // MARK: - Processing Preferences
    @Published public var defaultFilter: FilterType {
        didSet { defaults.set(defaultFilter.rawValue, forKey: "defaultFilter") }
    }
    
    @Published public var autoDetectEdges: Bool {
        didSet { defaults.set(autoDetectEdges, forKey: "autoDetectEdges") }
    }
    
    @Published public var performanceMode: PerformanceMode {
        didSet { defaults.set(performanceMode.rawValue, forKey: "performanceMode") }
    }
    
    // MARK: - PDF Defaults
    @Published public var defaultPDFPreset: PDFPreset {
        didSet { defaults.set(defaultPDFPreset.rawValue, forKey: "defaultPDFPreset") }
    }
    
    @Published public var defaultPageSize: PageSizeOption {
        didSet { defaults.set(defaultPageSize.rawValue, forKey: "defaultPageSize") }
    }
    
    @Published public var ocrEnabledDefault: Bool {
        didSet { defaults.set(ocrEnabledDefault, forKey: "ocrEnabledDefault") }
    }
    
    // MARK: - Appearance & Storage
    @Published public var themeMode: AppThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: "themeMode") }
    }
    
    @Published public var deleteOriginalsAfterExport: Bool {
        didSet { defaults.set(deleteOriginalsAfterExport, forKey: "deleteOriginalsAfterExport") }
    }
    
    private init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        
        // Default autoApplyPage1Settings is true
        if defaults.object(forKey: "autoApplyPage1Settings") == nil {
            self.autoApplyPage1Settings = true
        } else {
            self.autoApplyPage1Settings = defaults.bool(forKey: "autoApplyPage1Settings")
        }
        
        self.reusePage1CropArea = defaults.bool(forKey: "reusePage1CropArea")
        
        let flashRaw = defaults.string(forKey: "flashDefault") ?? FlashModeSetting.auto.rawValue
        self.flashDefault = FlashModeSetting(rawValue: flashRaw) ?? .auto
        
        self.gridDefault = defaults.bool(forKey: "gridDefault")
        
        if defaults.object(forKey: "shutterSoundEnabled") == nil {
            self.shutterSoundEnabled = true
        } else {
            self.shutterSoundEnabled = defaults.bool(forKey: "shutterSoundEnabled")
        }
        
        if defaults.object(forKey: "hapticsEnabled") == nil {
            self.hapticsEnabled = true
        } else {
            self.hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
        }
        
        let sensitivityRaw = defaults.string(forKey: "indicatorSensitivity") ?? IndicatorSensitivity.normal.rawValue
        self.indicatorSensitivity = IndicatorSensitivity(rawValue: sensitivityRaw) ?? .normal
        
        let filterRaw = defaults.string(forKey: "defaultFilter") ?? FilterType.blackAndWhite.rawValue
        self.defaultFilter = FilterType(rawValue: filterRaw) ?? .blackAndWhite
        
        if defaults.object(forKey: "autoDetectEdges") == nil {
            self.autoDetectEdges = true
        } else {
            self.autoDetectEdges = defaults.bool(forKey: "autoDetectEdges")
        }
        
        let perfRaw = defaults.string(forKey: "performanceMode") ?? PerformanceMode.auto.rawValue
        self.performanceMode = PerformanceMode(rawValue: perfRaw) ?? .auto
        
        let presetRaw = defaults.string(forKey: "defaultPDFPreset") ?? PDFPreset.balanced.rawValue
        self.defaultPDFPreset = PDFPreset(rawValue: presetRaw) ?? .balanced
        
        let pageSizeRaw = defaults.string(forKey: "defaultPageSize") ?? PageSizeOption.fit.rawValue
        self.defaultPageSize = PageSizeOption(rawValue: pageSizeRaw) ?? .fit
        
        self.ocrEnabledDefault = defaults.bool(forKey: "ocrEnabledDefault")
        
        let themeRaw = defaults.string(forKey: "themeMode") ?? AppThemeMode.system.rawValue
        self.themeMode = AppThemeMode(rawValue: themeRaw) ?? .system
        
        self.deleteOriginalsAfterExport = defaults.bool(forKey: "deleteOriginalsAfterExport")
    }
    
    /// Re-applies the default filter to any pages that haven't been manually customized by the user.
    @discardableResult
    public func applyDefaultFilterToUnmodifiedPages() -> Int {
        let bgContext = DataController.shared.newBackgroundContext()
        var updatedCount = 0
        bgContext.performAndWait {
            let request: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
            if let entities = try? bgContext.fetch(request) {
                for entity in entities {
                    var edit = PageEdit.decode(from: entity.editData)
                    if !edit.isUserModified {
                        edit.filter = self.defaultFilter
                        entity.editData = edit.encodeToData()
                        entity.status = PageStatus.pending.rawValue
                        let pid = entity.projectId
                        ProcessingQueue.shared.enqueue(pageId: entity.id, projectId: pid, isPriority: true)
                        updatedCount += 1
                    }
                }
                DataController.shared.save(context: bgContext)
            }
        }
        return updatedCount
    }
}
