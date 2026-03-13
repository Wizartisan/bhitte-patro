//
//  NepaliPatroApp.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 12/03/2026.
//
import SwiftUI

// --- 1. Nepali Localization Helper ---
struct NepaliCalendarHelper {
    static let nepaliNumbers = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
    static let daysOfWeek = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
    static let months = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज", "कात्तिक", "मंसिर", "पुष", "माघ", "फागुन", "चैत"]

    // Anchor: BS 2060 Baisakh 1 = AD 2003 April 14, which was a Monday (weekday index 1 in Sun=0 system)
    static let anchorYear = 2060
    static let anchorMonth = 1
    static let anchorDay = 1
    static let anchorWeekday = 1 // Monday

    // MARK: - Fixed: Absolute day counter from BS epoch (2060/01/01)
    private static func absoluteDays(year: Int, month: Int, day: Int) -> Int {
        var total = 0
        // Sum all days in complete years before this year
        for y in 2060..<year {
            total += yearTotalDays(y)
        }
        // Sum all days in complete months before this month (monthDays is 0-indexed)
        for m in 0..<(month - 1) {
            total += monthDays[year]?[m] ?? 30
        }
        // Add the day itself
        total += day
        return total
    }

    // MARK: - Fixed: firstWeekdayOfMonth using absolute day diff
    static func firstWeekdayOfMonth(year: Int, month: Int) -> Int {
        let anchorAbsolute = absoluteDays(year: anchorYear, month: anchorMonth, day: anchorDay)
        let targetAbsolute = absoluteDays(year: year, month: month, day: 1)
        let diff = targetAbsolute - anchorAbsolute
        // Use +7 guard to prevent negative modulo on any edge case
        return ((anchorWeekday + diff) % 7 + 7) % 7
    }

    private static func yearTotalDays(_ year: Int) -> Int {
        monthDays[year]?.reduce(0, +) ?? 355
    }

    /// Converts a Gregorian Date to a BS (Bikram Sambat) date tuple (year, month, day).
    /// Returns nil if the date falls outside the supported range.
    static func toBSDate(from gregorianDate: Date) -> (year: Int, month: Int, day: Int)? {
        // Anchor: BS 2060/01/01 = AD 2003/04/14
        let calendar = Calendar(identifier: .gregorian)
        var anchorComponents = DateComponents()
        anchorComponents.year = 2003
        anchorComponents.month = 4
        anchorComponents.day = 14
        guard let anchorGregorianDate = calendar.date(from: anchorComponents) else { return nil }

        let daysDiff = calendar.dateComponents([.day], from: anchorGregorianDate, to: gregorianDate).day ?? 0
        if daysDiff < 0 { return nil }

        var remaining = daysDiff
        var bsYear = anchorYear
        var bsMonth = anchorMonth
        var bsDay = anchorDay

        // Walk forward day by day using BS month lengths
        while remaining > 0 {
            let daysInCurrentMonth = monthDays[bsYear]?[bsMonth - 1] ?? 30
            let daysLeftInMonth = daysInCurrentMonth - bsDay

            if remaining <= daysLeftInMonth {
                bsDay += remaining
                remaining = 0
            } else {
                remaining -= (daysLeftInMonth + 1) // +1 to move to next month's day 1
                bsDay = 1
                bsMonth += 1
                if bsMonth > 12 {
                    bsMonth = 1
                    bsYear += 1
                }
                // Guard: outside known range
                if monthDays[bsYear] == nil { return nil }
            }
        }

        return (bsYear, bsMonth, bsDay)
    }

    /// Converts English Int to Nepali String (e.g., 2082 -> २०८२)
    static func toNepaliDigits(_ number: Int) -> String {
        let str = String(number)
        return str.compactMap { ch in
            if let digit = Int(String(ch)) { return nepaliNumbers[digit] }
            return String(ch)
        }.joined()
    }

    static let monthDays: [Int: [Int]] = [
        2060: [31,31,32,32,31,30,30,29,30,29,30,30],
        2061: [31,32,31,32,31,30,30,30,29,29,30,31],
        2062: [31,31,31,32,31,31,29,30,29,30,29,31],
        2063: [31,31,32,31,31,31,30,29,30,29,30,30],
        2064: [31,31,32,32,31,30,30,29,30,29,30,30],
        2065: [31,32,31,32,31,30,30,30,29,29,30,31],
        2066: [31,31,31,32,31,31,29,30,30,29,29,31],
        2067: [31,31,32,31,31,31,30,29,30,29,30,30],
        2068: [31,31,32,32,31,30,30,29,30,29,30,30],
        2069: [31,32,31,32,31,30,30,30,29,29,30,31],
        2070: [31,31,31,32,31,31,29,30,30,29,30,30],
        2071: [31,31,32,31,31,31,30,29,30,29,30,30],
        2072: [31,32,31,32,31,30,30,29,30,29,30,30],
        2073: [31,32,31,32,31,30,30,30,29,29,30,31],
        2074: [31,31,31,32,31,31,30,29,30,29,30,30],
        2075: [31,31,32,31,31,31,30,29,30,29,30,30],
        2076: [31,32,31,32,31,30,30,30,29,29,30,30],
        2077: [31,32,31,32,31,30,30,30,29,30,29,31],
        2078: [31,31,31,32,31,31,30,29,30,29,30,30],
        2079: [31,31,32,31,31,31,30,29,30,29,30,30],
        2080: [31,32,31,32,31,30,30,30,29,29,30,30],
        2081: [31,32,31,32,31,30,30,30,29,30,29,31],
        2082: [31,31,32,31,31,30,30,30,29,30,30,30],
        2083: [31,31,32,31,31,30,30,30,29,30,30,30],
        2084: [31,31,32,31,31,30,30,30,29,30,30,30],
        2085: [31,32,31,32,30,31,30,30,29,30,30,30],
    ]
}


// --- 2. Main App Entry ---
@main
struct NepaliPatroApp: App {
    // Derive today's BS date once at launch
    private var todayBS: (year: Int, month: Int, day: Int) {
        NepaliCalendarHelper.toBSDate(from: Date()) ?? (2082, 1, 1)
    }

    var body: some Scene {
        MenuBarExtra {
            VCenterView()
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text(NepaliCalendarHelper.toNepaliDigits(todayBS.day))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// --- 3. The Calendar View ---
struct VCenterView: View {
    // Derive today's BS date
    private var todayBS: (year: Int, month: Int, day: Int) {
        NepaliCalendarHelper.toBSDate(from: Date()) ?? (2082, 1, 1)
    }

    @State private var displayYear: Int = NepaliCalendarHelper.toBSDate(from: Date())?.year ?? 2082
    @State private var displayMonth: Int = NepaliCalendarHelper.toBSDate(from: Date())?.month ?? 1

    private var firstDayOfMonthWeekday: Int {
        NepaliCalendarHelper.firstWeekdayOfMonth(year: displayYear, month: displayMonth)
    }

    private var daysInMonth: Int {
        NepaliCalendarHelper.monthDays[displayYear]?[displayMonth - 1] ?? 30
    }

    var body: some View {
        VStack(spacing: 15) {
            // Header
            HStack {
                Text("\(NepaliCalendarHelper.months[displayMonth - 1]) \(NepaliCalendarHelper.toNepaliDigits(displayYear))")
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { navigateMonth(by: -1) }) { Image(systemName: "chevron.left") }
                    Button(action: { navigateMonth(by: 1) })  { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 5)

            // Days of the week header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(NepaliCalendarHelper.daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.secondary)
                }
            }

            let columns = Array(repeating: GridItem(.fixed(32), spacing: 8), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {

                // MARK: - Fixed: Use clear placeholder instead of "X"
                ForEach(0..<firstDayOfMonthWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(width: 32, height: 32)
                }

                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    let isToday =
                        day == todayBS.day &&
                        displayMonth == todayBS.month &&
                        displayYear == todayBS.year

                    Text(NepaliCalendarHelper.toNepaliDigits(day))
                        .font(.system(size: 14, design: .rounded))
                        .frame(width: 32, height: 32)
                        .background(isToday ? Color.orange : Color.clear)
                        .foregroundColor(isToday ? .white : .primary)
                        .clipShape(Circle())
                }
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .foregroundColor(.red)

                Spacer()

                Text("BS Calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            let today = todayBS
            displayYear = today.year
            displayMonth = today.month
        }
    }

    private func navigateMonth(by delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1;  y += 1 }
        // Only navigate if the year is in our supported range
        if NepaliCalendarHelper.monthDays[y] != nil {
            displayMonth = m
            displayYear = y
        }
    }
}
