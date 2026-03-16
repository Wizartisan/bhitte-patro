//
//  NepaliPatroApp.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 12/03/2026.
//

import SwiftUI
import Combine

// MARK: - Models
struct BSDate: Equatable {
    var year: Int
    var month: Int
    var day: Int
}

// MARK: - Calendar Engine
struct CalendarData: Codable {
    let monthDaysData: [String: [Int]]
    let holidays: [String: [String: [String: [String]]]]
    let tithi: [String: [String: [Int]]]
}

class NepaliCalendar {
    static let shared = NepaliCalendar()
    
    let nepaliNumbers = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
    let weekDays = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
    let months = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज", "कात्तिक", "मंसिर", "पुष", "माघ", "फागुन", "चैत"]
    let tithiNames = ["", "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी", "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "पूर्णिमा/औँसी"]
    
    // Anchor: 2060/01/01 BS = 2003/04/14 AD (Monday = 1)
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
        guard let url = Bundle.main.url(forResource: "calendar", withExtension: "json") ??
                        Bundle.main.url(forResource: "calendar", withExtension: "json", subdirectory: "data") else {
            print("Failed to find calendar.json in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(CalendarData.self, from: data)
            
            // Convert monthDaysData
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
            print("Error loading/decoding calendar.json: \(error)")
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

class DateUpdater: ObservableObject {
    @Published var currentDate = Date()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for midnight changes
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.currentDate = Date()
            }
            .store(in: &cancellables)
    }
}


// MARK: - App
@main
struct NepaliPatroApp: App {
    @StateObject private var dateUpdater = DateUpdater()
    
    var body: some Scene {
        MenuBarExtra {
            VCenterView()
                .environmentObject(dateUpdater)
        } label: {
            HStack {
                Image(systemName: "calendar")
                if let today = NepaliCalendar.shared.convertToBSDate(from: dateUpdater.currentDate) {
                    Text(NepaliCalendar.shared.toNepaliDigits(today.day))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct DateStepperRow: View {
    let label: String
    let font: Font
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDecrement) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)

            Text(label)
                .font(font)
                .frame(minWidth: 64, alignment: .center)
                .monospacedDigit()

            Button(action: { onIncrement() }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
// MARK: - View
struct VCenterView: View {
    @EnvironmentObject var dateUpdater: DateUpdater
    @State private var displayYear: Int
    @State private var displayMonth: Int
    @State private var selectedDate: BSDate?
    @State private var showDateConversion = false
    @State private var today: BSDate?
    @State private var adDate = Date()
    @State private var bsDate = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
    
    
    init() {
        let bsNow = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
        _displayYear = State(initialValue: bsNow.year)
        _displayMonth = State(initialValue: bsNow.month)
        _today = State(initialValue: bsNow)
        _selectedDate = State(initialValue: bsNow) // default to today
    }

    
    var body: some View {
        VStack(spacing: 15) {
            // Header
            if showDateConversion {
                HStack(alignment: .top, spacing: 0) {

                    // AD Date — custom stepper
                    VStack(alignment: .center, spacing: 10) {
                        Label("AD Date", systemImage: "calendar")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        // Month
                        DateStepperRow(
                            label: adDate.formatted(.dateTime.month(.wide)),
                            font: .subheadline,
                            onDecrement: { adDate = Calendar.current.date(byAdding: .month, value: -1, to: adDate) ?? adDate },
                            onIncrement: { adDate = Calendar.current.date(byAdding: .month, value:  1, to: adDate) ?? adDate }
                        )

                        // Year
                        DateStepperRow(
                            label: adDate.formatted(.dateTime.year()),
                            font: .title3.weight(.medium),
                            onDecrement: { adDate = Calendar.current.date(byAdding: .year, value: -1, to: adDate) ?? adDate },
                            onIncrement: { adDate = Calendar.current.date(byAdding: .year, value:  1, to: adDate) ?? adDate }
                        )

                        // Day
                        DateStepperRow(
                            label: adDate.formatted(.dateTime.day()),
                            font: .subheadline,
                            onDecrement: { adDate = Calendar.current.date(byAdding: .day, value: -1, to: adDate) ?? adDate },
                            onIncrement: { adDate = Calendar.current.date(byAdding: .day, value:  1, to: adDate) ?? adDate }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.leading, 16)
                    .onChange(of: adDate) { _, newValue in
                        if let converted = NepaliCalendar.shared.convertToBSDate(from: newValue) {
                            bsDate = converted
                        }
                    }


                    // BS Date — mirror layout, display only
                    VStack(alignment: .center, spacing: 10) {
                        Label("BS Date", systemImage: "sun.max.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(NepaliCalendar.shared.months[bsDate.month - 1])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(height: 26)

                        Text(NepaliCalendar.shared.toNepaliDigits(bsDate.year))
                            .font(.title2.weight(.medium))
                            .font(.title2.weight(.medium))
                            .frame(height: 26)

                        Text(NepaliCalendar.shared.toNepaliDigits(bsDate.day))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(height: 28)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator, lineWidth: 0.5))
            } else {
                HStack {
                    Text("\(NepaliCalendar.shared.months[displayMonth - 1]) \(NepaliCalendar.shared.toNepaliDigits(displayYear))")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    // show button take user to current month
                    Button("आज") {
                        if let today = today {
                            displayYear = today.year
                            displayMonth = today.month
                            selectedDate = today
                        }
                    }.foregroundStyle(Color(.red))
                    
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
                
                // Build a flat array of (label, isCurrentMonth, isToday, numericDay?, isHoliday)
                let cells: [(String, Bool, Bool, Int?, Bool)] = {
                    var result: [(String, Bool, Bool, Int?, Bool)] = []
                    
                    // Leading days from previous month
                    for i in 0..<firstWeekday {
                        let day = daysInPrevMonth - (firstWeekday - 1) + i
                        result.append((NepaliCalendar.shared.toNepaliDigits(day), false, false, nil, false))
                    }
                    
                    // Current month days
                    for day in 1...daysInMonth {
                        let isToday = today?.day == day &&
                        today?.month == displayMonth &&
                        today?.year == displayYear
                        let isHoliday = NepaliCalendar.shared.holidayText(year: displayYear, month: displayMonth, day: day) != nil
                        result.append((NepaliCalendar.shared.toNepaliDigits(day), true, isToday, day, isHoliday))
                    }
                    
                    // Trailing days from next month
                    for day in 1...max(1, trailingCount) where day <= trailingCount {
                        result.append((NepaliCalendar.shared.toNepaliDigits(day), false, false, nil, false))
                    }
                    
                    return result
                }()
                
                let columns = Array(repeating: GridItem(.fixed(32), spacing: 8), count: 7)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        let (label, isCurrent, isToday, numericDay, isHoliday) = cell
                        let isSelected: Bool = {
                            guard isCurrent, let d = numericDay, let sel = selectedDate else { return false }
                            return sel.year == displayYear && sel.month == displayMonth && sel.day == d
                        }()
                        
                        // Crimson-like color
                        let crimson = Color(.red)
                        
                        Text(label)
                            .font(isCurrent ? .system(size: 14, design: .rounded) : .caption2)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? crimson : (isToday ? Color.red : Color.clear))
                            .foregroundColor(
                                isSelected || isToday ? .white :
                                    (index % 7 == 6 || isHoliday) ? .red : // Saturday or holiday
                                    (isCurrent ? .primary : .secondary.opacity(0.4))
                            )
                            .clipShape(Circle())
                            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                            .contentShape(Rectangle()) // make the whole frame tappable
                            .onTapGesture {
                                guard isCurrent, let d = numericDay else { return }
                                selectedDate = BSDate(year: displayYear, month: displayMonth, day: d)
                            }
                    }
                }
                
                // Inline holiday/tithi text
                if let sel = selectedDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(NepaliCalendar.shared.months[sel.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(sel.day)), \(NepaliCalendar.shared.toNepaliDigits(sel.year))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            if let hText = NepaliCalendar.shared.holidayText(year: sel.year, month: sel.month, day: sel.day) {
                                Text(hText)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.primary)
                            }
                            
                            if let tithi = NepaliCalendar.shared.tithiText(year: sel.year, month: sel.month, day: sel.day) {
                                Text(tithi)
                                
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            Divider()
            
            HStack {
                Button("Quit App") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link).foregroundColor(.red)
                Spacer()
                
                Button(action: { showDateConversion.toggle() }) {
                    Image(systemName: "arrow.2.squarepath")
                        .imageScale(.medium)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(showDateConversion ? "Show BS Calendar" : "Show Date Conversion")
                .accessibilityLabel(showDateConversion ? "Show BS Calendar" : "Show Date Conversion")
            }
        }
        .padding()
        .frame(width: 280)
        .onReceive(dateUpdater.$currentDate) { newDate in
            if let bsToday = NepaliCalendar.shared.convertToBSDate(from: newDate) {
                // Check if the previous 'today' was the same as the month we were displaying
                let wasShowingToday = (today?.month == displayMonth && today?.year == displayYear)
                
                self.today = bsToday
                
                // If we were showing the month that just changed (and it's now a different month/year)
                // or if we want to force update the calendar view when the day changes
                if wasShowingToday {
                    displayMonth = bsToday.month
                    displayYear = bsToday.year
                    selectedDate = bsToday
                }
            }
        }
    }

    private func navigate(_ delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if m < 1 { m = 12; y -= 1 }
        else if m > 12 { m = 1; y += 1 }
        if NepaliCalendar.shared.daysInMonth(year: y, month: m) > 0 {
            displayMonth = m; displayYear = y
            // keep selection within new month if possible
            if let sel = selectedDate, sel.year == y, sel.month == m {
                selectedDate = sel
            } else if let today = today, today.year == y, today.month == m {
                selectedDate = today
            } else {
                selectedDate = BSDate(year: y, month: m, day: 1)
            }
        }
    }
    
}

#Preview("Menu Content") {
    VCenterView()
        .frame(width: 280)
        .padding()
}
