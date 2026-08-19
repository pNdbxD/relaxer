import CoreGraphics
import Foundation

enum IdleTime {
    /// `kCGAnyInputEventType` — any HID event, not just mouse-move / key-down.
    private static let anyInput = CGEventType(rawValue: .max)!

    static func secondsSinceLastInput() -> TimeInterval {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)

        // Inaccessible or stale values — treat as active
        guard idle.isFinite, idle < 86400 else { return 0 }
        return idle
    }
}
