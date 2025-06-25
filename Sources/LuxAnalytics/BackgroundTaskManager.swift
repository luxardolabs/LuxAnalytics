import Foundation
import BackgroundTasks
#if canImport(UIKit)
import UIKit
#endif

/// Manages background task scheduling for analytics
@MainActor
public final class BackgroundTaskManager {
    
    /// Background task identifier
    public static let taskIdentifier = "com.luxardolabs.LuxAnalytics.flush"
    
    /// Shared instance
    public static let shared = BackgroundTaskManager()
    
    private init() {}
    
    /// Register background tasks (call from AppDelegate)
    public func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task)
        }
    }
    
    /// Schedule a background task
    public func scheduleBackgroundFlush() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Try to run within the next hour
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            SecureLogger.log("Failed to schedule background task: \(error)", category: .error, level: .error)
        }
    }
    
    /// Cancel pending background tasks
    public func cancelBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }
    
    private func handleBackgroundTask(_ task: BGTask) {
        // Schedule next background task
        scheduleBackgroundFlush()
        
        // Create a background task for analytics flush
        let flushTask = Task {
            await LuxAnalytics.flushAsync()
            task.setTaskCompleted(success: true)
        }
        
        // Handle expiration
        task.expirationHandler = {
            flushTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - App Lifecycle Integration

extension BackgroundTaskManager {
    
    /// Setup background task handling (call from AppDelegate)
    public func setupBackgroundHandling() {
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Register background tasks
        registerBackgroundTasks()
    }
    
    @objc private func appDidEnterBackground() {
        // Schedule background task when app enters background
        scheduleBackgroundFlush()
    }
}

// MARK: - Background Processing

extension LuxAnalytics {
    
    /// Enable background task processing
    @MainActor
    public static func enableBackgroundProcessing() {
        BackgroundTaskManager.shared.setupBackgroundHandling()
    }
}