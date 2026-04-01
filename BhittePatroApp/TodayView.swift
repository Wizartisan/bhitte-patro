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

    private var tithiText: String? {
        NepaliCalendar.shared.tithiText(year: todayBS.year, month: todayBS.month, day: todayBS.day)
    }

    private var holidayText: String? {
        NepaliCalendar.shared.holidayText(year: todayBS.year, month: todayBS.month, day: todayBS.day)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .frame(height: 44)

            // Divider
            Divider()

            // Main content
            VStack(spacing: 6) {
                Spacer(minLength: 0)

                // Day number
                Text(nepaliDay)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Month and year
                Text(nepaliMonthYear)
                    .font(.system(size: 18, weight: .medium))

                // Holiday
                if let holiday = holidayText, !holiday.isEmpty {
                    Text(holiday)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Tithi
                if let tithi = tithiText, !tithi.isEmpty {
                    Text(tithi)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
        .padding(12)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        ZStack {
            Text("आज")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
            
            HStack {
                Spacer()
                
                // Settings button -> use SettingsLink to open Settings scene
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
