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
    @ObservedObject var calendarManager = CalendarManager.shared

    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Launch at Login section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Launch at Login")
                            .font(.system(size: 12, weight: .semibold))
                        
                        HStack {
                            Text("Open app when you log in to your Mac")
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: Bindable(launchManager).isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    
                    // Default view section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default View")
                            .font(.system(size: 12, weight: .semibold))
                        
                        HStack {
                            Text("Default View")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $defaultMode) {
                                Text("Today").tag("today")
                                Text("Calendar").tag("calendar")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 180)
                            .onChange(of: defaultMode) { _, new in
                                NotificationCenter.default.post(
                                    name: .didChangeDefaultViewMode,
                                    object: nil,
                                    userInfo: ["mode": new]
                                )
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    
                    // Calendar Update section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar Data")
                            .font(.system(size: 12, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Last updated")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    
                                    if let last = calendarManager.lastUpdated {
                                        Text(last, style: .date)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(last, style: .time)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Never")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        await calendarManager.fetchLatestCalendar()
                                    }
                                } label: {
                                    if calendarManager.isUpdating {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Update Now")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(calendarManager.isUpdating)
                            }
                            
                            if let error = calendarManager.updateError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    
                    // Quit button
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit Bhitte Patro")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Text("Settings")
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
