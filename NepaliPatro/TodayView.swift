//
//  TodayView.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 16/03/2026.
//

import SwiftUI

struct TodayView: View {
    // The current AD date to compute today's BS date
    var currentDate: Date

    // Optional title (defaults to "आज")
    var title: String = "आज"

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
        VStack {
            Text(title)
                .font(.title2)
                .bold()

            Spacer()

            // Show today's date with tithi and holiday (if present)
            VStack(alignment: .center, spacing: 4) {
                Text(nepaliDay)
                    .font(.system(size: 64))
                    .foregroundColor(.white)

                Text(nepaliMonthYear)
                    .font(.system(size: 24))

                if let holiday = holidayText, !holiday.isEmpty {
                    Text(holiday)
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }

                if let tithi = tithiText, !tithi.isEmpty {
                    Text(tithi)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
