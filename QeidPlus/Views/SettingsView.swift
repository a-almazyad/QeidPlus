import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notifications = NotificationManager.shared

    @State private var reminderTime: Date = {
        let mgr = NotificationManager.shared
        var comps = DateComponents()
        comps.hour   = mgr.reminderHour
        comps.minute = mgr.reminderMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Notifications
                Section {
                    Toggle(LocalizedStringKey("settings_notifications"), isOn: Binding(
                        get: { notifications.reminderEnabled },
                        set: { _ in notifications.toggleReminder() }
                    ))

                    if notifications.reminderEnabled {
                        DatePicker(
                            LocalizedStringKey("settings_reminder_time"),
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                            notifications.updateTime(
                                hour:   comps.hour   ?? 21,
                                minute: comps.minute ?? 0
                            )
                        }
                    }

                    if !notifications.isAuthorized && !notifications.reminderEnabled {
                        Text(LocalizedStringKey("settings_notifications_denied"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(LocalizedStringKey("settings_notifications_header"))
                }

                // MARK: Language
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey("settings_language"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("settings_language_header"))
                }

                // MARK: About
                Section {
                    HStack {
                        Text(LocalizedStringKey("settings_version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(LocalizedStringKey("settings_about_header"))
                }
            }
            .navigationTitle(LocalizedStringKey("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("settings_done", comment: "")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                await notifications.refreshAuthorizationStatus()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
