import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        Task { @MainActor in
            guard let monitor = AppServices.monitor else { return }
            AppServices.menuBarController = MenuBarController(monitor: monitor)
            await monitor.requestNotificationPermission()
            monitor.start()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@MainActor
enum AppServices {
    static var monitor: TimerMonitor?
    static var menuBarController: MenuBarController?
}

@main
struct RelaxerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: TimerMonitor

    init() {
        let monitor = TimerMonitor()
        _monitor = State(initialValue: monitor)
        AppServices.monitor = monitor
    }

    var body: some Scene {
        Settings {
            SettingsView(monitor: monitor)
        }
    }
}
