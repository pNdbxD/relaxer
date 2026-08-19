import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: TimerMonitor
    @State private var idleText = ""
    @State private var reminderText = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Idle reset (seconds)") {
                    TextField("1–500", text: $idleText)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitIdle() }
                        .onChange(of: idleText) { applyIdleIfValid() }
                }

                LabeledContent("Remind after (minutes)") {
                    TextField("1–500", text: $reminderText)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitReminder() }
                        .onChange(of: reminderText) { applyReminderIfValid() }
                }
            } footer: {
                Text("The timer resets when your Mac sleeps, the lid closes, you log out, or you stay idle for the idle period.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 180)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            syncFromMonitor()
        }
        .onDisappear {
            commitIdle()
            commitReminder()
        }
    }

    private func syncFromMonitor() {
        idleText = String(monitor.idleResetSeconds)
        reminderText = String(monitor.reminderMinutes)
    }

    private func applyIdleIfValid() {
        guard let value = parseValue(idleText) else { return }
        monitor.idleResetSeconds = value
        monitor.saveSettings()
    }

    private func applyReminderIfValid() {
        guard let value = parseValue(reminderText) else { return }
        monitor.reminderMinutes = value
        monitor.saveSettings()
    }

    private func commitIdle() {
        guard let value = parseValue(idleText) else {
            idleText = String(monitor.idleResetSeconds)
            return
        }
        idleText = String(value)
        monitor.idleResetSeconds = value
        monitor.saveSettings()
    }

    private func commitReminder() {
        guard let value = parseValue(reminderText) else {
            reminderText = String(monitor.reminderMinutes)
            return
        }
        reminderText = String(value)
        monitor.reminderMinutes = value
        monitor.saveSettings()
    }

    private func parseValue(_ text: String) -> Int? {
        guard !text.isEmpty, text.allSatisfy(\.isNumber), let value = Int(text), (1...500).contains(value) else {
            return nil
        }
        return value
    }
}
