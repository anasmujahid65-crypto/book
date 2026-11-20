# BookScan PDF — Offline iOS Book-to-PDF Scanner

> **Target Device:** iPhone 7 Plus (A10 Fusion, 3 GB RAM, 5.5" display, Home button, dual 12 MP camera)  
> **Deployment Target:** iOS 15.0+ (compatible with iOS 15.8.x through latest iOS)  
> **Architecture:** 100% Offline, Disk-First, Bounded Memory Pipeline, Zero Shutter Lag  

---

## 1. Project Overview & Philosophy

**BookScan PDF** is an offline, privacy-first iOS app engineered to scan full-length books (300–500+ pages) into ultra-lightweight, high-resolution PDFs without intermediate editor interruptions or out-of-memory crashes.

Unlike general-purpose scanning apps that force the user into an editor after every capture and inflate memory by keeping raw 48 MB bitmaps in RAM, BookScan PDF:
1. **Keeps the camera continuously live:** Shoot Page 1 through Page 500+ without the camera closing once.
2. **Features a real-time smart indicator:** Turns vivid green only when the book page is fully inside, level, unskewed, and large enough in frame.
3. **Persists disk-first with bounded processing:** Immediately flushes captures to disk and bounds background perspective correction to keep peak memory flat under 150 MB even on a 3 GB RAM device.
4. **Applies Page 1 settings across the series:** Filter, rotation, brightness, and contrast configured for Page 1 automatically cascade across all subsequent pages (controlled via Settings).
5. **Generates streamed, 100% identical PDFs:** Directly injects compressed JPEG bytes (`DCTDecode`) into the PDF output stream page-by-page, avoiding memory bloat and preserving 1:1 image fidelity.

---

## 2. macOS & Xcode Distribution Requirements

### Prerequisites
- **Computer:** Apple Mac (Apple Silicon or Intel) running macOS Monterey 12.0 or later.
- **IDE:** Xcode 13.0 or newer (configured with iOS 15.0 Deployment Target).
- **Physical Device:** iPhone 7 Plus (or any iPhone/iPad running iOS 15.0+).

### Apple ID Signing Options
1. **Free Personal Apple ID (7-day Self-Signing):**
   - In Xcode: `Settings > Accounts > + > Apple ID`.
   - In Project Settings: Select `BookScanPDF` target > `Signing & Capabilities` > check `Automatically manage signing` > choose your Personal Team.
   - Change `Bundle Identifier` to a unique suffix (e.g., `com.yourname.BookScanPDF`).
   - Run on your connected iPhone 7 Plus.
   - On the iPhone: Go to `Settings > General > VPN & Device Management` > tap your developer profile > select **Trust**.
   - *Note:* Apps signed with a free Apple ID remain active on the device for **7 days**. After 7 days, re-connect to Xcode and tap Run.
2. **Paid Apple Developer Account ($99/year):**
   - Provides **1-year certificate validity**, TestFlight distribution, and App Store submission capabilities.

---

## 3. Directory Structure

```
BookScanPDF/
├── BookScanPDF.xcodeproj/
│   └── project.pbxproj               # Xcode 13/14/15 compatible project file
└── BookScanPDF/
    ├── App/
    │   ├── BookScanPDFApp.swift       # SwiftUI App entry point
    │   └── AppDelegate.swift          # Memory warning handler & cache flushing
    ├── Models/
    │   ├── CoreData/
    │   │   ├── BookScanModel.swift    # Programmatic NSManagedObjectModel (No compiler traps)
    │   │   ├── ProjectEntity+CoreDataClass.swift
    │   │   ├── PageEntity+CoreDataClass.swift
    │   │   └── DataController.swift   # Persistent store & background context manager
    │   └── Domain/
    │       ├── Enums.swift            # FilterType, PDFPreset, PageSizeOption, PageStatus
    │       ├── PageEdit.swift         # NormalizedQuad, PageEdit model with Codable serialization
    │       ├── Project.swift          # Clean domain struct for Project
    │       └── Page.swift             # Clean domain struct for Page
    ├── Services/
    │   ├── Storage/
    │   │   ├── DiskStorageManager.swift # Sandboxed disk storage & iCloud backup exclusion
    │   │   └── ImageDownsampler.swift   # CGImageSource thumbnail downsampler (Memory shield)
    │   └── Settings/
    │       └── AppSettings.swift      # UserDefaults persistence for auto-apply and defaults
    ├── DesignSystem/
    │   ├── Theme.swift                # Palette, fonts, spacing, shadows
    │   └── Components/
    │       ├── PrimaryButton.swift    # Standardized rounded action button
    │       ├── StatusBadge.swift      # Capsule status indicator
    │       ├── EmptyStateView.swift   # Elegant fallback graphic
    │       └── ShimmerView.swift      # Processing placeholder animation
    ├── Views/
    │   ├── Home/
    │   │   ├── HomeViewModel.swift    # Core Data fetch, project CRUD, resume detection
    │   │   ├── ProjectCardView.swift  # Grid card with downsampled thumbnail & context menu
    │   │   ├── NewScanActionSheet.swift # Source selection (Camera / Photos / Files)
    │   │   └── HomeView.swift         # Main library with search & resume banners
    │   ├── Onboarding/
    │   │   └── OnboardingView.swift   # 3-card onboarding carousel
    │   └── Settings/
    │       └── SettingsView.swift     # Dedicated settings screen with Auto-Apply toggle
    └── Resources/
        ├── Info.plist                 # Camera & photo permissions, orientation locks
        └── Assets.xcassets/           # AppIcon & AccentColor catalog
```

---

## 4. Phase-by-Phase Roadmap

- [x] **Phase 1: Foundation & Data Architecture**
  - Programmatic Core Data model (`ProjectEntity`, `PageEntity`)
  - Disk storage manager with sandboxed subdirectories (`originals`, `processed`, `thumbs`, `exports`)
  - `ImageDownsampler` memory shield preventing 48 MB RAM bitmap spikes
  - Design system, adaptive theme, and onboarding flow
  - Home screen with project cards, search, context actions, and session recovery banner
  - Dedicated Settings screen with headline "Apply Page 1 settings to all pages" toggle
- [x] **Phase 2: Live Camera & Vision/Core Motion Indicator**
  - AVFoundation continuous capture session with zero shutter lag
  - Real-time `VNDetectRectanglesRequest` (8–12 Hz) + Core Motion gravity pitch/roll evaluation
  - Smooth 4-state indicator (green / amber / red) with low-pass corner smoothing
  - Disk-first background capture handler and instant page counter pop
  - Interactive horizon level bubble, rule-of-thirds grid, and tap-to-focus
  - Hardware torch/flash controls, pinch-to-zoom, and exit confirmation dialog
- [x] **Phase 3: Image Processing Pipeline & Auto-Apply Queue**
  - Shared Metal-backed `CIContext` with disabled intermediate caching
  - Core Image perspective correction (`CIPerspectiveCorrection`)
  - Filters: Original, Enhanced Color, Grayscale, and Black & White document binarization
  - Single-channel 8-bit `DeviceGray` rendering for Grayscale and B&W
  - Bounded concurrency `ProcessingQueue` (1 worker on 3 GB iPhone 7 Plus, 2 on 4 GB+)
  - `AutoApplyManager` cascading Page 1 parameters across 500+ subsequent pages
  - Complete `autoreleasepool` execution loop preventing memory creep
- [x] **Phase 4: Review Workspace & Page Editor**
  - Adaptive thumbnail grid with page numbering, shimmer states, and failure retries
  - Multi-select mode for batch deletion, rotation, and filter cascading
  - "Add More Pages" button continuing series sequence directly in the camera
  - Interactive crop overlay with 4 draggable corner handles and crosshair `CropLoupeView`
  - Fine straightening (\(\pm 10^\circ\)), 90° rotation, and real-time brightness/contrast sliders
  - Live 60fps filter previews operating on downsampled memory-safe working buffers
  - Page 1 cascade alert prompt syncing adjustments across the book
- [x] **Phase 5: Multi-Source Import & Spread Splitter**
  - `PHPickerViewController` multi-select (selection limit 0 = unlimited, zero permission prompt)
  - `loadFileRepresentation` memory-safe file streaming preventing RAM inflation
  - `UIDocumentPickerViewController` supporting iCloud Drive & Files imports
  - Real-time `ImportProgressView` with cancel support and atomic Core Data batching
  - `GutterDetector` automatic binding seam identification via column-intensity profiling
  - `SpreadSplitterView` with draggable crease divider and Right-to-Left (Urdu/Arabic/Hebrew) order
  - Atomic insertion of split children with order index re-normalization
- [x] **Phase 6: Streaming PDF Engine & Export**
  - Custom `PDFStreamingWriter` streaming page-by-page directly to `FileHandle`
  - Direct JPEG `DCTDecode` embedding guaranteeing 100% fidelity without re-compression
  - Lightweight JPEG SOF marker parser extracting dimensions without memory decoding
  - PDF layout geometry (Fit to Image, A4, and US Letter) with aspect ratio protection
  - `PDFExportManager` with background execution token and screen idle timer management
  - Full post-generation integrity validation via `PDFKit` `PDFDocument`
  - `ExportView` with quality presets, estimated file sizes, in-app `PDFView` preview, system share sheet, and Save to Files
- [x] **Phase 7: Searchable OCR & Resumable Safety**
  - On-device `OCREngine` utilizing Vision `VNRecognizeTextRequest` (.accurate, Latin-script)
  - Invisible searchable text layer (`3 Tr` mode with `/Helvetica`) placed at bounding box coordinates
  - `SessionRestorationManager` persistent manifest (`session_manifest.json`) protecting against termination
  - VoiceOver accessibility labels across camera controls, review grid, and editor sliders
  - Full Dark Mode, Dynamic Type, and iPad split-layout responsiveness
- [x] **Phase 8: Instruments Profiling, 500-Page Stress Test & CI/CD**
  - Thread-safe disk-first storage engine (`DiskStorageManager`) with zero deadlock hazard
  - `StressTestManager` mach resident memory profiler (`mach_task_basic_info`)
  - 500-page synthetic book generation & streamed PDF benchmark maintaining flat resident memory (< 150 MB ceiling)
  - `StressTestView` developer benchmark dashboard accessible from Settings
  - Full GitHub Actions CI/CD automation workflow (`build-ipa.yml`) generating unsigned `.ipa` for sideloading

