//
//  BhittePatro.swift
//  BhittePatro
//
//  Created by Pranab Kc on 21/03/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Models (copied for widget)
struct BSDate: Equatable {
    var year: Int
    var month: Int
    var day: Int
}

// MARK: - Calendar Data Model
struct CalendarData: Codable {
    let monthDaysData: [String: [Int]]
    let holidays: [String: [String: [String: [String]]]]
    let tithi: [String: [String: [Int]]]
}

// MARK: - Calendar Engine (Widget Version)
class NepaliCalendar {
    static let shared = NepaliCalendar()

    let nepaliNumbers = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
    let weekDays = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
    let months = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज", "कात्तिक", "मंसिर", "पुष", "माघ", "फागुन", "चैत"]
    let tithiNames = ["", "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी", "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "पूर्णिमा/औँसी"]

    private let anchorYear = 2060
    private let anchorMonth = 1
    private let anchorDay = 1
    private let anchorWeekday = 1

    private var monthDaysData: [Int: [Int]] = [:]
    private var holidays: [Int: [Int: [Int: [String]]]] = [:]
    private var tithi: [Int: [Int: [Int]]] = [:]

    init() {
        loadCalendarData()
    }

    private func loadCalendarData() {
        guard let url = Bundle.main.url(forResource: "calendar", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(CalendarData.self, from: data)

            for (yearStr, days) in decodedData.monthDaysData {
                if let year = Int(yearStr) {
                    self.monthDaysData[year] = days
                }
            }

            for (yearStr, months) in decodedData.holidays {
                if let year = Int(yearStr) {
                    var yearHolidays: [Int: [Int: [String]]] = [:]
                    for (monthStr, days) in months {
                        if let month = Int(monthStr) {
                            var monthHolidays: [Int: [String]] = [:]
                            for (dayStr, names) in days {
                                if let day = Int(dayStr) {
                                    monthHolidays[day] = names
                                }
                            }
                            yearHolidays[month] = monthHolidays
                        }
                    }
                    self.holidays[year] = yearHolidays
                }
            }

            for (yearStr, months) in decodedData.tithi {
                if let year = Int(yearStr) {
                    var yearTithi: [Int: [Int]] = [:]
                    for (monthStr, days) in months {
                        if let month = Int(monthStr) {
                            yearTithi[month] = days
                        }
                    }
                    self.tithi[year] = yearTithi
                }
            }
        } catch {
            print("Error loading calendar.json in widget: \(error)")
        }
    }

    func holidayText(year: Int, month: Int, day: Int) -> String? {
        guard let names = holidays[year]?[month]?[day], !names.isEmpty else { return nil }
        return names.joined(separator: " / ")
    }

    func tithiText(year: Int, month: Int, day: Int) -> String? {
        guard let monthTithis = tithi[year]?[month], day > 0 && day <= monthTithis.count else { return nil }
        let val = monthTithis[day - 1]
        if val >= 1 && val <= 15 {
            return tithiNames[val]
        }
        return nil
    }

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

    func convertToADDate(from bsDate: BSDate) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var anchorComps = DateComponents()
        anchorComps.year = 2003
        anchorComps.month = 4
        anchorComps.day = 14
        guard let anchorADDate = calendar.date(from: anchorComps) else { return nil }

        var year = anchorYear
        var month = anchorMonth
        let day = anchorDay
        var totalDays = 0

        while year < bsDate.year {
            for m in 1...12 {
                totalDays += daysInMonth(year: year, month: m)
            }
            year += 1
        }

        while month < bsDate.month {
            totalDays += daysInMonth(year: year, month: month)
            month += 1
        }

        totalDays += (bsDate.day - day)
        guard let adDate = calendar.date(byAdding: .day, value: totalDays, to: anchorADDate) else { return nil }
        return adDate
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

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), todayBS: BSDate(year: 2081, month: 1, day: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let today = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
        completion(SimpleEntry(date: Date(), todayBS: today))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let currentDate = Date()
        let todayBS = NepaliCalendar.shared.convertToBSDate(from: currentDate) ?? BSDate(year: 2081, month: 1, day: 1)

        // Create timeline entries for next few hours
        var entries: [SimpleEntry] = []
        for hourOffset in 0..<5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, todayBS: todayBS)
            entries.append(entry)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let todayBS: BSDate
}

// MARK: - Small Widget View (Today)
struct SmallWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let nepaliDay = NepaliCalendar.shared.toNepaliDigits(entry.todayBS.day)
        let nepaliMonthYear = "\(NepaliCalendar.shared.months[entry.todayBS.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.year))"
        let holidayText = NepaliCalendar.shared.holidayText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day)
        let tithiText = NepaliCalendar.shared.tithiText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day)

        VStack(spacing: 4) {
            Text("आज")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            Text(nepaliDay)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(nepaliMonthYear)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let holiday = holidayText, !holiday.isEmpty {
                Text(holiday)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if let tithi = tithiText, !tithi.isEmpty {
                Text(tithi)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Large Widget View (Calendar)
struct LargeWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let displayYear = entry.todayBS.year
        let displayMonth = entry.todayBS.month
        let today = entry.todayBS
        let firstWeekday = NepaliCalendar.shared.firstWeekday(year: displayYear, month: displayMonth)
        let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)
        let cells = buildCalendarCells(displayYear: displayYear, displayMonth: displayMonth, firstWeekday: firstWeekday, daysInMonth: daysInMonth, today: today)

        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text("\(NepaliCalendar.shared.months[displayMonth - 1])")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(NepaliCalendar.shared.toNepaliDigits(displayYear))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("आज: \(NepaliCalendar.shared.toNepaliDigits(today.day))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)

            // Weekday headers
            HStack(spacing: 1) {
                ForEach(NepaliCalendar.shared.weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(day == "आइत" || day == "शनि" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(cells, id: \.day) { cell in
                    CalendarCellView(cell: cell, isToday: cell.isToday)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Footer - Holiday/Tithi for today
            if let holiday = NepaliCalendar.shared.holidayText(year: today.year, month: today.month, day: today.day) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                Text(holiday)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            } else if let tithi = NepaliCalendar.shared.tithiText(year: today.year, month: today.month, day: today.day) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                Text(tithi)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func buildCalendarCells(displayYear: Int, displayMonth: Int, firstWeekday: Int, daysInMonth: Int, today: BSDate) -> [CalendarCell] {
        var cells: [CalendarCell] = []

        // Previous month days
        let prevMonth = displayMonth == 1 ? 12 : displayMonth - 1
        let prevYear = displayMonth == 1 ? displayYear - 1 : displayYear
        let daysInPrevMonth = NepaliCalendar.shared.daysInMonth(year: prevYear, month: prevMonth)

        for i in 0..<firstWeekday {
            let day = daysInPrevMonth - (firstWeekday - 1) + i
            cells.append(CalendarCell(day: day, isCurrentMonth: false, isToday: false))
        }

        // Current month days
        for day in 1...daysInMonth {
            let isToday = today.year == displayYear && today.month == displayMonth && today.day == day
            cells.append(CalendarCell(day: day, isCurrentMonth: true, isToday: isToday))
        }

        // Next month days to fill grid
        let totalCells = cells.count
        let remaining = totalCells % 7 == 0 ? 0 : 7 - (totalCells % 7)
        for day in 1...remaining {
            cells.append(CalendarCell(day: day, isCurrentMonth: false, isToday: false))
        }

        return cells
    }
}

struct CalendarCell: Identifiable {
    let id = UUID()
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

struct CalendarCellView: View {
    let cell: CalendarCell
    let isToday: Bool

    var body: some View {
        let nepaliDay = NepaliCalendar.shared.toNepaliDigits(cell.day)

        ZStack {
            if isToday {
                Circle()
                    .fill(Color.red)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(4)
            }

            Text(nepaliDay)
                .font(.system(size: cell.isCurrentMonth ? 14 : 11, weight: cell.isCurrentMonth ? .semibold : .regular))
                .foregroundColor(
                    isToday ? .white :
                    (cell.isCurrentMonth ? .primary : .secondary)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Main Widget
struct BhittePatro: Widget {
    let kind: String = "BhittePatro"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetContentView(entry: entry)
        }
        .configurationDisplayName("Bhitte Patro")
        .description("Nepali Calendar Widget - Small shows today, Large shows calendar")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct WidgetContentView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        if widgetFamily == .systemSmall {
            SmallWidgetView(entry: entry)
        } else {
            LargeWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    BhittePatro()
} timeline: {
    SimpleEntry(date: .now, todayBS: BSDate(year: 2081, month: 1, day: 15))
}

#Preview(as: .systemLarge) {
    BhittePatro()
} timeline: {
    SimpleEntry(date: .now, todayBS: BSDate(year: 2081, month: 1, day: 15))
}
