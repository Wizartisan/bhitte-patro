//
//  SettingsView.swift
//  BhittePatroApp
//
//  Created by Gemini on 20/03/2026.
//

import SwiftUI
import Foundation

extension Notification.Name {
    static let didChangeDefaultViewMode = Notification.Name("didChangeDefaultViewMode")
}

struct SettingsView: View {
    @AppStorage("DefaultCalendarViewMode") private var defaultMode: String = "calendar"
    @State private var launchManager = LaunchAtLoginManager.shared

    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 8)

            headerSection
                .frame(height: 38)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    settingsRow(
                        icon: "switch.2",
                        title: "Launch at Login",
                        subtitle: "Open automatically when you sign in"
                    ) {
                        Toggle("", isOn: Bindable(launchManager).isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }

                    settingsRow(
                        icon: "rectangle.on.rectangle",
                        title: "Default View",
                        subtitle: "Choose what you see first"
                    ) {
                        Picker("", selection: $defaultMode) {
                            Text("Today").tag("today")
                            Text("Calendar").tag("calendar")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: defaultMode) { _, new in
                            NotificationCenter.default.post(
                                name: .didChangeDefaultViewMode,
                                object: nil,
                                userInfo: ["mode": new]
                            )
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                            Text("Quit App")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Settings Row
    @ViewBuilder
    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)

            Text("Settings")
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, 14)
    }
}
