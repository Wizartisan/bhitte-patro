//
//  NepaliPatroApp.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 12/03/2026.
//

import SwiftUI

// MARK: - Models
struct BSDate: Equatable {
    var year: Int
    var month: Int
    var day: Int
}

// MARK: - Calendar Engine
class NepaliCalendar {
    static let shared = NepaliCalendar()
    
    let nepaliNumbers = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
    let weekDays = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
    let months = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज", "कात्तिक", "मंसिर", "पुष", "माघ", "फागुन", "चैत"]
    
    // Anchor: 2060/01/01 BS = 2003/04/14 AD (Monday = 1)
    private let anchorYear = 2060
    private let anchorMonth = 1
    private let anchorDay = 1
    private let anchorWeekday = 1
    
    private let monthDaysData: [Int: [Int]] = [
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
    
    func convertToBSDate(from date: Date) -> BSDate? {
        let calendar = Calendar(identifier: .gregorian)
        var anchorComps = DateComponents()
        anchorComps.year = 2003; anchorComps.month = 4; anchorComps.day = 14
        guard let anchorDate = calendar.date(from: anchorComps) else { return nil }
        
        let d1 = calendar.startOfDay(for: anchorDate)
        let d2 = calendar.startOfDay(for: date)
        guard let daysDiff = calendar.dateComponents([.day], from: d1, to: d2).day, daysDiff >= 0 else { return nil }
        
        var year = anchorYear, month = anchorMonth, day = anchorDay, remaining = daysDiff
        while remaining > 0 {
            let dim = daysInMonth(year: year, month: month)
            let left = dim - day
            if remaining <= left { day += remaining; remaining = 0 }
            else { remaining -= (left + 1); day = 1; month += 1; if month > 12 { month = 1; year += 1 } }
            if monthDaysData[year] == nil { return nil }
        }
        return BSDate(year: year, month: month, day: day)
    }
    
    func daysInMonth(year: Int, month: Int) -> Int {
        return monthDaysData[year]?[month - 1] ?? 30
    }
    
    func firstWeekday(year: Int, month: Int) -> Int {
        var total = 0
        for y in anchorYear..<year { total += monthDaysData[y]?.reduce(0, +) ?? 365 }
        for m in 1..<month { total += daysInMonth(year: year, month: m) }
        return (anchorWeekday + total) % 7
    }
    
    func toNepaliDigits(_ number: Int) -> String {
        return String(number).compactMap { char in
            if let d = char.wholeNumberValue { return nepaliNumbers[d] }
            return String(char)
        }.joined()
    }
}

// MARK: - App
@main
struct NepaliPatroApp: App {
    var body: some Scene {
        MenuBarExtra {
            VCenterView()
        } label: {
            HStack {
                Image(systemName: "calendar")
                if let today = NepaliCalendar.shared.convertToBSDate(from: Date()) {
                    Text(NepaliCalendar.shared.toNepaliDigits(today.day))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - View
struct VCenterView: View {
    @State private var displayYear: Int
    @State private var displayMonth: Int
    private let today: BSDate?
    
    init() {
        let bsNow = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
        _displayYear = State(initialValue: bsNow.year)
        _displayMonth = State(initialValue: bsNow.month)
        self.today = bsNow
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Header
            HStack {
                Text("\(NepaliCalendar.shared.months[displayMonth - 1]) \(NepaliCalendar.shared.toNepaliDigits(displayYear))")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { navigate(-1) }) { Image(systemName: "chevron.left") }
                    Button(action: { navigate(1) })  { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 5)

            // Days of week
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(NepaliCalendar.shared.weekDays, id: \.self) { day in
                    Text(day).font(.caption2).fontWeight(.black).foregroundColor(.secondary)
                }
            }

            // Grid Logic
            let firstWeekday = NepaliCalendar.shared.firstWeekday(year: displayYear, month: displayMonth)
            let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)

            // Previous month info for leading placeholders
            let prevMonth = displayMonth == 1 ? 12 : displayMonth - 1
            let prevYear  = displayMonth == 1 ? displayYear - 1 : displayYear
            let daysInPrevMonth = NepaliCalendar.shared.daysInMonth(year: prevYear, month: prevMonth)

            // Always use exactly 35 cells; expand to 42 only when content overflows
            let totalNeeded    = firstWeekday + daysInMonth
            let totalGridCells = totalNeeded > 35 ? 42 : 35
            let trailingCount  = totalGridCells - totalNeeded   // always >= 0

            // Build a flat array of (label, isCurrentMonth, isToday) so ForEach never
            // receives an empty range like 1...0
            let cells: [(String, Bool, Bool)] = {
                var result: [(String, Bool, Bool)] = []

                // Leading days from previous month
                for i in 0..<firstWeekday {
                    let day = daysInPrevMonth - (firstWeekday - 1) + i
                    result.append((NepaliCalendar.shared.toNepaliDigits(day), false, false))
                }

                // Current month days
                for day in 1...daysInMonth {
                    let isToday = today?.day == day &&
                                  today?.month == displayMonth &&
                                  today?.year == displayYear
                    result.append((NepaliCalendar.shared.toNepaliDigits(day), true, isToday))
                }

                // Trailing days from next month
                for day in 1...max(1, trailingCount) where day <= trailingCount {
                    result.append((NepaliCalendar.shared.toNepaliDigits(day), false, false))
                }

                return result
            }()

            let columns = Array(repeating: GridItem(.fixed(32), spacing: 8), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    let (label, isCurrent, isToday) = cell
                    Text(label)
                        .font(isCurrent ? .system(size: 14, design: .rounded) : .caption2)
                        .frame(width: 32, height: 32)
                        .background(isToday ? Color.orange : Color.clear)
                        .foregroundColor(
                            isToday   ? .white :
                            isCurrent ? .primary :
                                        .secondary.opacity(0.4)
                        )
                        .clipShape(Circle())
                }
            }

            Divider()

            HStack {
                Button("Quit App") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link).foregroundColor(.red)
                Spacer()
                Text("BS Calendar").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func navigate(_ delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if m < 1 { m = 12; y -= 1 }
        else if m > 12 { m = 1; y += 1 }
        if NepaliCalendar.shared.daysInMonth(year: y, month: m) > 0 {
            displayMonth = m; displayYear = y
        }
    }
}
