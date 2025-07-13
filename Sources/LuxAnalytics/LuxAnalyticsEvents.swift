import Foundation

/// Modern async event stream for monitoring analytics events
public struct LuxAnalyticsEvents: Sendable {
    
    /// Stream of analytics events as they occur
    public static var eventStream: AsyncStream<AnalyticsEventNotification> {
        AsyncStream { continuation in
            let observer = EventObserver { notification in
                continuation.yield(notification)
            }
            
            Task {
                await EventManager.shared.addObserver(observer)
            }
            
            continuation.onTermination = { _ in
                Task {
                    await EventManager.shared.removeObserver(observer)
                }
            }
        }
    }
}

/// Notification types for analytics events
public enum AnalyticsEventNotification: Sendable {
    case eventQueued(AnalyticsEvent)
    case eventsSent([AnalyticsEvent])
    case eventsFailed([AnalyticsEvent], error: LuxAnalyticsError)
    case eventsDropped(count: Int, reason: QueueOverflowStrategy)
    case eventsExpired([AnalyticsEvent])
}

/// Internal event manager
actor EventManager {
    static let shared = EventManager()
    
    private var observers: [EventObserver] = []
    
    func addObserver(_ observer: EventObserver) {
        observers.append(observer)
    }
    
    func removeObserver(_ observer: EventObserver) {
        observers.removeAll { $0.id == observer.id }
    }
    
    func notify(_ notification: AnalyticsEventNotification) {
        for observer in observers {
            observer.handler(notification)
        }
    }
}

/// Internal observer wrapper
final class EventObserver: Sendable {
    let id = UUID()
    let handler: @Sendable (AnalyticsEventNotification) -> Void
    
    init(handler: @escaping @Sendable (AnalyticsEventNotification) -> Void) {
        self.handler = handler
    }
}

/// Extension for internal notifications from LuxAnalytics
extension LuxAnalyticsEvents {
    internal static let shared = LuxAnalyticsEvents()
    
    func notifyQueued(_ event: AnalyticsEvent) async {
        await EventManager.shared.notify(.eventQueued(event))
    }
    
    func notifySent(_ event: AnalyticsEvent) async {
        await EventManager.shared.notify(.eventsSent([event]))
    }
    
    func notifyFailed(_ event: AnalyticsEvent, error: Error) async {
        let luxError = error as? LuxAnalyticsError ?? .networkError(error)
        await EventManager.shared.notify(.eventsFailed([event], error: luxError))
    }
    
    func notifyDropped(_ event: AnalyticsEvent, reason: String) async {
        // Convert reason to overflow strategy (default to dropOldest)
        await EventManager.shared.notify(.eventsDropped(count: 1, reason: .dropOldest))
    }
    
    func notifyExpired(_ event: AnalyticsEvent) async {
        await EventManager.shared.notify(.eventsExpired([event]))
    }
}

/// Public API for event notifications
extension LuxAnalytics {
    
    /// Monitor analytics events using async/await
    /// 
    /// Example:
    /// ```swift
    /// Task {
    ///     for await event in LuxAnalyticsEvents.eventStream {
    ///         switch event {
    ///         case .eventQueued(let event):
    ///             print("Event queued: \(event.name)")
    ///         case .eventsSent(let events):
    ///             print("Sent \(events.count) events")
    ///         default:
    ///             break
    ///         }
    ///     }
    /// }
    /// ```
    public static func notifyEventQueued(_ event: AnalyticsEvent) async {
        await EventManager.shared.notify(.eventQueued(event))
    }
    
    public static func notifyEventsSent(_ events: [AnalyticsEvent]) async {
        await EventManager.shared.notify(.eventsSent(events))
    }
    
    public static func notifyEventsFailed(_ events: [AnalyticsEvent], error: LuxAnalyticsError) async {
        await EventManager.shared.notify(.eventsFailed(events, error: error))
    }
    
    public static func notifyEventsDropped(count: Int, reason: QueueOverflowStrategy) async {
        await EventManager.shared.notify(.eventsDropped(count: count, reason: reason))
    }
    
    public static func notifyEventsExpired(_ events: [AnalyticsEvent]) async {
        await EventManager.shared.notify(.eventsExpired(events))
    }
    
    // Single event convenience methods
    public static func notifyEventDropped(_ event: AnalyticsEvent, reason: String) async {
        await EventManager.shared.notify(.eventsDropped(count: 1, reason: .dropOldest))
    }
    
    public static func notifyEventExpired(_ event: AnalyticsEvent) async {
        await EventManager.shared.notify(.eventsExpired([event]))
    }
}