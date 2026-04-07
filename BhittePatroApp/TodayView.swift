//
//  TodayView.swift
//  BhittePatroApp
//
//  Created by Pranab Kc on 16/03/2026.
//

import SwiftUI

struct TodayView: View {
    var currentDate: Date
    @Binding var viewMode: CalendarViewMode

    private var todayBS: BSDate {
        NepaliCalendar.shared.convertToBSDate(from: currentDate) ?? BSDate(year: 2081, month: 1, day: 1)
    }

    private var nepaliDay: String {
        NepaliCalendar.shared.toNepaliDigits(todayBS.day)
    }

    private var nepaliMonthYear: String {
        let monthName = NepaliCalendar.shared.months[todayBS.month - 1]
        let year = NepaliCalendar.shared.toNepaliDigits(todayBS.year)
        return "\(monthName) \(year)"
    }

    private var englishDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: currentDate)
    }

    private var tithiText: String? {
        NepaliCalendar.shared.tithiText(year: todayBS.year, month: todayBS.month, day: todayBS.day)
    }

    private var holidayText: String? {
        NepaliCalendar.shared.holidayText(year: todayBS.year, month: todayBS.month, day: todayBS.day)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .frame(height: 30)

            VStack(spacing: 10) {
                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.18),
                                        Color.red.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.red.opacity(0.10))
                            )
                            .frame(width: 94, height: 94)

                        Text(nepaliDay)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    VStack(spacing: 4) {
                        Text(nepaliMonthYear)
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Text(englishDateText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if let holiday = holidayText, !holiday.isEmpty {
                    Text(holiday)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08), in: Capsule())
                }

                if let tithi = tithiText, !tithi.isEmpty {
                    Text(tithi)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
        }
        .padding(10)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .center) {
            HStack {
                Color.clear.frame(width: 28, height: 28)

                Spacer()

                Button {
                    NotificationCenter.default.post(
                        name: .didChangeDefaultViewMode,
                        object: nil,
                        userInfo: ["mode": "settings"]
                    )
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text("आज")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
