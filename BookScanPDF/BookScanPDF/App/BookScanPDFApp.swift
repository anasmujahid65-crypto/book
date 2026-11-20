//
//  BookScanPDFApp.swift
//  BookScanPDF
//
//  Application entry point targeting iOS 15.0+.
//

import SwiftUI

@main
struct BookScanPDFApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataController = DataController.shared
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, dataController.viewContext)
                .preferredColorScheme(settings.themeMode.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .appDidReceiveMemoryWarningNotification)) { _ in
                    handleMemoryWarning()
                }
        }
    }
    
    private func handleMemoryWarning() {
        // Clear in-memory caches promptly
        URLCache.shared.removeAllCachedResponses()
    }
}
