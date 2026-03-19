//
//  NepaliPatroApp.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 12/03/2026.
//

import SwiftUI
import Combine
import Foundation


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
    
    func convertToADDate(from bsDate: BSDate) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        
        // Anchor AD date corresponding to BS anchor
        var anchorComps = DateComponents()
        anchorComps.year = 2003   // AD year of BS anchor
        anchorComps.month = 4
        anchorComps.day = 14
        guard let anchorADDate = calendar.date(from: anchorComps) else { return nil }
        
        // Anchor BS date components
        var year = anchorYear       // e.g., 2060
        var month = anchorMonth     // e.g., 1
        var day = anchorDay         // e.g., 1
        
        // Calculate number of days from anchor BS date to target BS date
        var totalDays = 0
        
        // First, sum full years
        while year < bsDate.year {
            for m in 1...12 {
                totalDays += daysInMonth(year: year, month: m)
            }
            year += 1
        }
        
        // Then sum months in current year
        while month < bsDate.month {
            totalDays += daysInMonth(year: year, month: month)
            month += 1
        }
        
        // Then add days in current month
        totalDays += (bsDate.day - day)
        
        // Add totalDays to anchor AD date
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


// Persistable modes with raw values for UserDefaults
enum CalendarViewMode: String, CaseIterable {
    case calendar
    case dateConversion
    case somethingElse
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .dateConversion: return "arrow.2.squarepath"
        case .somethingElse: return "sun.max"
        }
    }
    
    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .dateConversion: return "Converter"
        case .somethingElse: return "Today"
        }
    }
    
    static let defaultsKey = "DefaultCalendarViewMode"
    
    static func loadDefault() -> CalendarViewMode? {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        return CalendarViewMode(rawValue: raw)
    }
    
    static func saveDefault(_ mode: CalendarViewMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
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
                    .frame(width: 32, height: 32)
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
                    .frame(width: 32, height: 32)
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
    @State private var today: BSDate?
    @State private var adDate = Date()
    @State private var bsDate = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
    @State private var viewMode: CalendarViewMode = .calendar

    
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
            switch viewMode {
                case .dateConversion:
                    DateConversionView(adDate: $adDate, bsDate: $bsDate)
                case .calendar:
                    CalendarView(displayYear: $displayYear, displayMonth: $displayMonth, selectedDate: $selectedDate, today: $today, adDate: $adDate, bsDate: $bsDate)
                case .somethingElse:
                    TodayView(currentDate: dateUpdater.currentDate)
            }
            
            Divider()
            
            HStack {
                // Quit icon button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .foregroundStyle(Color(.red.opacity(0.6)))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Quit App")
                
                Spacer()
                
                // Only two options shown: the "other" modes, icon-only
                HStack(spacing: 8) {
                    ForEach(otherModes(for: viewMode), id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = mode
                            }
                        } label: {
                            Image(systemName: icon(for: mode))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, height: 28)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(title(for: mode))
                        .help(title(for: mode))
                    }
                }
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear {
            // Ensure both AD and BS are synced to "today" when the menu opens
            adDate = dateUpdater.currentDate
            if let bsToday = NepaliCalendar.shared.convertToBSDate(from: dateUpdater.currentDate) {
                bsDate = bsToday
                today = bsToday
                // keep calendar pointed at today on first open
                displayMonth = bsToday.month
                displayYear = bsToday.year
                selectedDate = bsToday
            }
        }
        .onReceive(dateUpdater.$currentDate) { newDate in
            // Always keep AD and BS dates synced to today's date
            adDate = newDate
            if let bsToday = NepaliCalendar.shared.convertToBSDate(from: newDate) {
                let wasShowingToday = (today?.month == displayMonth && today?.year == displayYear)
                
                self.today = bsToday
                self.bsDate = bsToday
    
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
        // Prevent navigation beyond 2060-2085 range
        guard y >= 2060 && y <= 2085 else { return }
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
    
    private func otherModes(for current: CalendarViewMode) -> [CalendarViewMode] {
        switch current {
        case .calendar:
            return [.somethingElse, .dateConversion] // Today, Converter
        case .dateConversion:
            return [.somethingElse, .calendar] // Today, Calendar
        case .somethingElse:
            return [.calendar, .dateConversion] // Calendar, Converter
        }
    }
    
    private func title(for mode: CalendarViewMode) -> String {
        switch mode {
        case .calendar: return "Calendar"
        case .dateConversion: return "Converter"
        case .somethingElse: return "Today"
        }
    }
    
    private func icon(for mode: CalendarViewMode) -> String {
        switch mode {
        case .calendar: return "calendar"
        case .dateConversion: return "arrow.2.squarepath"
        case .somethingElse: return "sun.max"
        }
    }
}

#Preview("Menu Content") {
    VCenterView()
        .frame(width: 280)
        .padding()
}
