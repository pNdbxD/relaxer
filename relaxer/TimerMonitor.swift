import AppKit
import UserNotifications

@MainActor
@Observable
final class TimerMonitor {
    private(set) var activeTime: TimeInterval = 0
    private(set) var progressFillLevel: Int = 0

    private var pollTimer: Timer?
    private var isRunning = false
    private var lastPollDate = Date()
    private var lastSleepCheckDate = Date()
    private var lastSleepCheckUptime = ProcessInfo.processInfo.systemUptime
    private var hasNotified = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?

    private static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")
    private static let fullFillLeadTime: TimeInterval = 300

    var idleResetSeconds: Int

    var reminderMinutes: Int {
        didSet {
            hasNotified = false
            updateProgressFillLevel()
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if let seconds = defaults.object(forKey: "idleResetSeconds") as? Int {
            idleResetSeconds = seconds
        } else if let minutes = defaults.object(forKey: "idleResetMinutes") as? Int {
            idleResetSeconds = minutes * 60
        } else {
            idleResetSeconds = 300
        }

        if let minutes = defaults.object(forKey: "reminderMinutes") as? Int {
            reminderMinutes = minutes
        } else if let hours = defaults.object(forKey: "reminderHours") as? Double {
            reminderMinutes = Int(hours * 60)
        } else {
            reminderMinutes = 120
        }

        saveSettings()
    }

    func saveSettings() {
        UserDefaults.standard.set(idleResetSeconds, forKey: "idleResetSeconds")
        UserDefaults.standard.set(reminderMinutes, forKey: "reminderMinutes")
        UserDefaults.standard.removeObject(forKey: "idleResetMinutes")
        UserDefaults.standard.removeObject(forKey: "reminderHours")
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let now = Date()
        lastPollDate = now
        lastSleepCheckDate = now
        lastSleepCheckUptime = ProcessInfo.processInfo.systemUptime
        registerSleepObservers()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor in
                monitor.tick()
            }
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    func stop() {
        isRunning = false
        pollTimer?.invalidate()
        pollTimer = nil

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspaceCenter.removeObserver($0) }
        workspaceObservers.removeAll()

        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
        }
        lockObserver = nil
    }

    func resetTimer() {
        activeTime = 0
        hasNotified = false
        let now = Date()
        lastPollDate = now
        lastSleepCheckDate = now
        lastSleepCheckUptime = ProcessInfo.processInfo.systemUptime
        updateProgressFillLevel()
    }

    var formattedActiveTime: String {
        let total = Int(currentActiveTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var formattedRemainingUntilReminder: String {
        let remaining = max(0, TimeInterval(reminderMinutes * 60) - currentActiveTime)
        let total = Int(remaining)
        let minutes = total / 60
        let seconds = total % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s left"
        }
        return "\(seconds)s left"
    }

    private var currentActiveTime: TimeInterval {
        if IdleTime.secondsSinceLastInput() >= TimeInterval(idleResetSeconds) {
            return activeTime
        }
        return activeTime + Date().timeIntervalSince(lastPollDate)
    }

    private func tick() {
        if detectSleep() { return }

        if IdleTime.secondsSinceLastInput() >= TimeInterval(idleResetSeconds) {
            resetTimer()
            return
        }

        let now = Date()
        activeTime += now.timeIntervalSince(lastPollDate)
        lastPollDate = now
        updateProgressFillLevel()

        let reminderSeconds = TimeInterval(reminderMinutes * 60)
        if !hasNotified && activeTime >= reminderSeconds {
            hasNotified = true
            Task { await sendNotification() }
        }
    }

    private func updateProgressFillLevel() {
        let goal = TimeInterval(reminderMinutes * 60)
        guard goal > 0 else {
            progressFillLevel = 0
            return
        }

        let active = currentActiveTime
        let preFullFillGoal = max(goal - Self.fullFillLeadTime, goal * 0.9)

        if active >= preFullFillGoal {
            progressFillLevel = 10
            return
        }

        guard preFullFillGoal > 0 else {
            progressFillLevel = 0
            return
        }

        // Levels 0–9 span 0% to ~90% of the goal; level 10 is the last 5 minutes
        progressFillLevel = min(9, Int((active / preFullFillGoal) * 9))
    }

    @discardableResult
    private func detectSleep() -> Bool {
        let now = Date()
        let wallDelta = now.timeIntervalSince(lastSleepCheckDate)
        let uptime = ProcessInfo.processInfo.systemUptime
        let uptimeDelta = uptime - lastSleepCheckUptime

        lastSleepCheckDate = now
        lastSleepCheckUptime = uptime

        if wallDelta > 60 && wallDelta - uptimeDelta > 30 {
            resetTimer()
            return true
        }
        return false
    }

    private func registerSleepObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceObservers = [
            workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                guard let monitor = self else { return }
                Task { @MainActor in
                    monitor.resetTimer()
                }
            },
            workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let monitor = self else { return }
                Task { @MainActor in
                    monitor.resetTimer()
                }
            },
            workspaceCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let monitor = self else { return }
                Task { @MainActor in
                    monitor.resetTimer()
                }
            },
        ]

        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.screenLockedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor in
                monitor.resetTimer()
            }
        }
    }

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func sendNotification() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to relax"
        content.body = "You've been active for \(reminderMinutes) minutes. Take a break!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
