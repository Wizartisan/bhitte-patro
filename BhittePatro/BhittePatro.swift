//
//  BhittePatro.swift
//  BhittePatro
//
//  Created by Pranab Kc on 21/03/2026.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Models
struct BSDate: Equatable, Codable {
    var year: Int
    var month: Int
    var day: Int
}

struct CalendarData: Codable {
    let monthDaysData: [String: [Int]]
    let holidays: [String: [String: [String: [String]]]]
    let tithi: [String: [String: [Int]]]
}

// MARK: - Calendar Engine
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
    private var isLoaded = false

    private init() {}

    private func ensureLoaded() {
        if isLoaded { return }
        loadCalendarData()
        isLoaded = true
    }

    func loadCalendarData() {
        guard let url = Bundle.main.url(forResource: "calendar", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(CalendarData.self, from: data)
            for (yearStr, days) in decodedData.monthDaysData { if let year = Int(yearStr) { self.monthDaysData[year] = days } }
            for (yearStr, months) in decodedData.holidays {
                if let year = Int(yearStr) {
                    var yearHolidays: [Int: [Int: [String]]] = [:]
                    for (monthStr, days) in months {
                        if let month = Int(monthStr) {
                            var monthHolidays: [Int: [String]] = [:]
                            for (dayStr, names) in days { if let day = Int(dayStr) { monthHolidays[day] = names } }
                            yearHolidays[month] = monthHolidays
                        }
                    }
                    self.holidays[year] = yearHolidays
                }
            }
            for (yearStr, months) in decodedData.tithi {
                if let year = Int(yearStr) {
                    var yearTithi: [Int: [Int]] = [:]
                    for (monthStr, days) in months { if let month = Int(monthStr) { yearTithi[month] = days } }
                    self.tithi[year] = yearTithi
                }
            }
        } catch { print("Error loading calendar.json: \(error)") }
    }

    func holidayText(year: Int, month: Int, day: Int) -> String? {
        ensureLoaded()
        guard let names = holidays[year]?[month]?[day], !names.isEmpty else { return nil }
        return names.joined(separator: " / ")
    }

    func tithiText(year: Int, month: Int, day: Int) -> String? {
        ensureLoaded()
        guard let monthTithis = tithi[year]?[month], day > 0 && day <= monthTithis.count else { return nil }
        let val = monthTithis[day - 1]
        return (val >= 1 && val <= 15) ? tithiNames[val] : nil
    }

    func convertToBSDate(from date: Date) -> BSDate? {
        ensureLoaded()
        let calendar = Calendar(identifier: .gregorian)
        var anchorComps = DateComponents(); anchorComps.year = 2003; anchorComps.month = 4; anchorComps.day = 14
        guard let anchorDate = calendar.date(from: anchorComps) else { return nil }
        let d1 = calendar.startOfDay(for: anchorDate), d2 = calendar.startOfDay(for: date)
        guard let daysDiff = calendar.dateComponents([.day], from: d1, to: d2).day, daysDiff >= 0 else { return nil }
        var year = anchorYear, month = anchorMonth, day = anchorDay, remaining = daysDiff
        while remaining > 0 {
            let dim = daysInMonth(year: year, month: month), left = dim - day
            if remaining <= left { day += remaining; remaining = 0 }
            else { remaining -= (left + 1); day = 1; month += 1; if month > 12 { month = 1; year += 1 } }
            if monthDaysData[year] == nil { return nil }
        }
        return BSDate(year: year, month: month, day: day)
    }

    func daysInMonth(year: Int, month: Int) -> Int {
        ensureLoaded()
        return monthDaysData[year]?[month - 1] ?? 30
    }

    func firstWeekday(year: Int, month: Int) -> Int {
        ensureLoaded()
        var total = 0
        for y in anchorYear..<year { total += monthDaysData[y]?.reduce(0, +) ?? 365 }
        for m in 1..<month { total += daysInMonth(year: year, month: m) }
        return (anchorWeekday + total) % 7
    }

    func toNepaliDigits(_ number: Int) -> String {
        String(number).compactMap { char in
            if let d = char.wholeNumberValue { return nepaliNumbers[d] }
            return String(char)
        }.joined()
    }
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), todayBS: BSDate(year: 2083, month: 1, day: 6))
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let today = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2083, month: 1, day: 6)
        completion(SimpleEntry(date: Date(), todayBS: today))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let date = Date()
        let today = NepaliCalendar.shared.convertToBSDate(from: date) ?? BSDate(year: 2083, month: 1, day: 6)
        completion(Timeline(entries: [SimpleEntry(date: date, todayBS: today)], policy: .atEnd))
    }
}

struct SimpleEntry: TimelineEntry, Codable {
    let date: Date
    let todayBS: BSDate
}

// MARK: - Views
struct CalendarCell: Identifiable {
    let id: String
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

func buildCalendarCells(displayYear: Int, displayMonth: Int, firstWeekday: Int, daysInMonth: Int, today: BSDate) -> [CalendarCell] {
    var cells: [CalendarCell] = []
    let prevMonth = displayMonth == 1 ? 12 : displayMonth - 1
    let prevYear = displayMonth == 1 ? displayYear - 1 : displayYear
    let daysInPrevMonth = NepaliCalendar.shared.daysInMonth(year: prevYear, month: prevMonth)
    for i in 0..<firstWeekday {
        let day = daysInPrevMonth - (firstWeekday - 1) + i
        cells.append(CalendarCell(id: "prev-\(prevYear)-\(prevMonth)-\(day)", day: day, isCurrentMonth: false, isToday: false))
    }
    for day in 1...daysInMonth {
        let isToday = today.year == displayYear && today.month == displayMonth && today.day == day
        cells.append(CalendarCell(id: "curr-\(displayYear)-\(displayMonth)-\(day)", day: day, isCurrentMonth: true, isToday: isToday))
    }
    let remaining = 42 - cells.count
    if remaining > 0 {
        let nextMonth = displayMonth == 12 ? 1 : displayMonth + 1
        let nextYear = displayMonth == 12 ? displayYear + 1 : displayYear
        for day in 1...remaining {
            cells.append(CalendarCell(id: "next-\(nextYear)-\(nextMonth)-\(day)", day: day, isCurrentMonth: false, isToday: false))
        }
    }
    return cells
}

struct CalendarCellView: View {
    let cell: CalendarCell
    let isToday: Bool
    var fontSize: CGFloat = 14
    var padding: CGFloat = 4
    var body: some View {
        ZStack {
            if isToday { Circle().fill(Color.red).aspectRatio(1, contentMode: .fit).padding(padding) }
            Text(NepaliCalendar.shared.toNepaliDigits(cell.day))
                .font(.system(size: cell.isCurrentMonth ? fontSize : fontSize * 0.8, weight: cell.isCurrentMonth ? .semibold : .regular))
                .foregroundColor(isToday ? .white : (cell.isCurrentMonth ? .primary : .secondary))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SmallWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        VStack(spacing: 4) {
            Text("आज").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
            Text(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.day)).font(.system(size: 42, weight: .bold, design: .rounded))
            Text("\(NepaliCalendar.shared.months[entry.todayBS.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.year))").font(.caption).foregroundStyle(.secondary)
            if let holiday = NepaliCalendar.shared.holidayText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day) {
                Text(holiday).font(.caption2).foregroundColor(.red).lineLimit(2).multilineTextAlignment(.center)
            }
        }
    }
}

struct MediumWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                let displayYear = entry.todayBS.year
                let displayMonth = entry.todayBS.month
                let firstWeekday = NepaliCalendar.shared.firstWeekday(year: displayYear, month: displayMonth)
                let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)
                let cells = buildCalendarCells(displayYear: displayYear, displayMonth: displayMonth, firstWeekday: firstWeekday, daysInMonth: daysInMonth, today: entry.todayBS)
                
                HStack {
                    Text(NepaliCalendar.shared.months[displayMonth - 1]).font(.system(size: 14, weight: .bold))
                    Text(NepaliCalendar.shared.toNepaliDigits(displayYear)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
                HStack(spacing: 0) {
                    ForEach(["आइ", "सो", "मं", "बु", "बि", "शु", "श"], id: \.self) { day in
                        Text(day).font(.system(size: 8, weight: .bold)).foregroundColor(day == "श" ? .red : .secondary).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 4).padding(.bottom, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(cells, id: \.id) { cell in CalendarCellView(cell: cell, isToday: cell.isToday, fontSize: 9, padding: 1).aspectRatio(1, contentMode: .fit) }
                }.padding(.horizontal, 4).padding(.bottom, 4)
            }.frame(maxWidth: .infinity)
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1).padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 6) {
                Text("आज").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.day)).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(.red)
                    let weekdayIndex = (NepaliCalendar.shared.firstWeekday(year: entry.todayBS.year, month: entry.todayBS.month) + entry.todayBS.day - 1) % 7
                    Text(NepaliCalendar.shared.weekDays[weekdayIndex]).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                }
                Text("\(NepaliCalendar.shared.months[entry.todayBS.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.year))").font(.system(size: 11, weight: .semibold))
                if let holiday = NepaliCalendar.shared.holidayText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day) {
                    Text(holiday).font(.system(size: 12, weight: .bold)).foregroundColor(.red).lineLimit(3)
                }
                Spacer()
            }.padding(12).frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct LargeWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        VStack(spacing: 0) {
            let displayYear = entry.todayBS.year
            let displayMonth = entry.todayBS.month
            let firstWeekday = NepaliCalendar.shared.firstWeekday(year: displayYear, month: displayMonth)
            let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)
            let cells = buildCalendarCells(displayYear: displayYear, displayMonth: displayMonth, firstWeekday: firstWeekday, daysInMonth: daysInMonth, today: entry.todayBS)
            
            HStack {
                HStack(spacing: 8) {
                    Text(NepaliCalendar.shared.months[displayMonth - 1]).font(.system(size: 18, weight: .bold)).foregroundStyle(.primary)
                    Text(NepaliCalendar.shared.toNepaliDigits(displayYear)).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("आज: \(NepaliCalendar.shared.toNepaliDigits(entry.todayBS.day))").font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
            }.padding(.horizontal, 16).padding(.vertical, 8)
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
            HStack(spacing: 1) {
                ForEach(NepaliCalendar.shared.weekDays, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).foregroundColor(day == "शनि" ? .red : .secondary).frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 8).padding(.vertical, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(cells, id: \.id) { cell in CalendarCellView(cell: cell, isToday: cell.isToday, fontSize: 12, padding: 2).aspectRatio(1, contentMode: .fit) }
            }.padding(.horizontal, 8).padding(.bottom, 2)
            Spacer(minLength: 0)
            if let text = NepaliCalendar.shared.holidayText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day) {
                footerView(text: text, footerColor: .red)
            } else if let tithi = NepaliCalendar.shared.tithiText(year: entry.todayBS.year, month: entry.todayBS.month, day: entry.todayBS.day) {
                footerView(text: tithi, footerColor: .secondary)
            }
        }
    }
    private func footerView(text: String, footerColor: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundColor(footerColor).lineLimit(1).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8).padding(.horizontal, 16)
        }
    }
}

// MARK: - Main Widget
@main
struct BhittePatro: Widget {
    let kind: String = "NepaliPatroWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetContentView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Bhitte Patro")
        .description("Nepali Calendar Widget")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetContentView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        default: LargeWidgetView(entry: entry)
        }
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) { BhittePatro() } timeline: { SimpleEntry(date: .now, todayBS: BSDate(year: 2083, month: 1, day: 6)) }
#Preview(as: .systemMedium) { BhittePatro() } timeline: { SimpleEntry(date: .now, todayBS: BSDate(year: 2083, month: 1, day: 6)) }
#Preview(as: .systemLarge) { BhittePatro() } timeline: { SimpleEntry(date: .now, todayBS: BSDate(year: 2083, month: 1, day: 6)) }
