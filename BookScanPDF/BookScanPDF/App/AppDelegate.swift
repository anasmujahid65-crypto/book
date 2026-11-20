//
//  AppDelegate.swift
//  BookScanPDF
//

import UIKit

public class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Optimize image cache limits for 3GB RAM devices
        URLCache.shared.memoryCapacity = 10_000_000 // 10MB
        URLCache.shared.diskCapacity = 50_000_000    // 50MB
        
        // Reconcile and resume any interrupted session or background operations
        DispatchQueue.global(qos: .background).async {
            SessionRestorationManager.shared.reconcileOnLaunch()
        }
        return true
    }
    
    public func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("[AppDelegate] Critical Memory Warning received from iOS! Flushing caches.")
        NotificationCenter.default.post(name: .appDidReceiveMemoryWarningNotification, object: nil)
    }
}

extension Notification.Name {
    public static let appDidReceiveMemoryWarningNotification = Notification.Name("appDidReceiveMemoryWarningNotification")
}
