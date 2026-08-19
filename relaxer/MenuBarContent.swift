import SwiftUI

struct MenuBarContent: View {
    let monitor: TimerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active: \(monitor.formattedActiveTime)")
                .font(.headline)

            Text("Resets after \(monitor.idleResetSeconds)s idle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Reminds after \(monitor.reminderMinutes) min · \(monitor.formattedRemainingUntilReminder)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Reset Timer") {
                monitor.resetTimer()
            }

            SettingsLink {
                Text("Settings…")
            }

            Divider()

            Button("Quit") {
                AppServices.menuBarController?.stop()
                monitor.stop()
                NSApplication.shared.terminate(nil)
            }

            Text(Self.versionLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 240)
    }

    private static var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
