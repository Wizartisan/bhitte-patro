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
struct BSDate: Equatable, Hashable, Identifiable {
    var year: Int
    var month: Int
    var day: Int
    
    var id: String { "\(year)-\(month)-\(day)" }
}

// MARK: - Calendar Engine
struct CalendarData: Codable {
    let monthDaysData: [String: [Int]]
    let holidays: [String: [String: [String: [String]]]]
    let tithi: [String: [String: [Int]]]
}



class NepaliCalendar: ObservableObject {
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

    // Cache for Nepali number conversions
    private var nepaliNumberCache: [Int: String] = [:]
    private let nepaliNumberCacheLock = NSLock()
    
    
    init() {
        loadCalendarData()
    }
    
    func nextHoliday(from year: Int, month: Int, day: Int)
    -> (text: String, daysAway: Int, date: BSDate)? {

        let current = BSDate(year: year, month: month, day: day)

        for i in 1...60 {
            if let next = addDays(to: current, days: i) {
                if let holiday = holidayText(year: next.year, month: next.month, day: next.day) {
                    return (holiday, i, next)
                }
            }
        }
        return nil
    }
    
    func addDays(to date: BSDate, days: Int) -> BSDate? {
        var y = date.year
        var m = date.month
        var d = date.day + days
        
        // Ensure starting year data exists
        guard monthDaysData[y] != nil else { return nil }
        
        while true {
            guard let dim = monthDaysData[y]?[m - 1] else { return nil }
            if d <= dim {
                break
            } else {
                d -= dim
                m += 1
                if m > 12 {
                    m = 1
                    y += 1
                    // Stop if beyond known data range
                    if monthDaysData[y] == nil { return nil }
                }
            }
        }
        return BSDate(year: y, month: m, day: d)
    }
    
    func loadCalendarData() {
        var data: Data? = CalendarManager.shared.getLocalCalendarData()
        
        if data == nil {
            guard let url = Bundle.main.url(forResource: "calendar", withExtension: "json") ??
                            Bundle.main.url(forResource: "calendar", withExtension: "json", subdirectory: "data") else {
                print("Failed to find calendar.json in bundle")
                return
            }
            data = try? Data(contentsOf: url)
        }
        
        guard let data = data else { return }
        
        do {
            let decodedData = try JSONDecoder().decode(CalendarData.self, from: data)
            
            // Reset existing data
            self.monthDaysData = [:]
            self.holidays = [:]
            self.tithi = [:]

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
        let day = anchorDay         // e.g., 1

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
        // Check cache first
        if let cached = nepaliNumberCacheLock.withLock({ nepaliNumberCache[number] }) {
            return cached
        }
        
        let result = String(number).compactMap { char in
            if let d = char.wholeNumberValue { return nepaliNumbers[d] }
            return String(char)
        }.joined()
        
        // Cache the result
        nepaliNumberCacheLock.withLock { nepaliNumberCache[number] = result }
        return result
    }
    
    func findNextHoliday(matching synonyms: [String]?) -> (name: String, date: BSDate)? {
        guard let today = convertToBSDate(from: Date()) else { return nil }
        
        for i in 0...365 {
            if let date = addDays(to: today, days: i) {
                if let holidayNames = holidays[date.year]?[date.month]?[date.day], !holidayNames.isEmpty {
                    let mainHoliday = holidayNames[0]
                    
                    if let synonyms = synonyms, !synonyms.isEmpty {
                        for synonym in synonyms {
                            if mainHoliday.caseInsensitiveCompare(synonym) == .orderedSame {
                                return (mainHoliday, date)
                            }
                        }
                    } else { // Generic search
                        return (mainHoliday, date)
                    }
                }
            }
        }
        return nil
    }

    func daysBetween(from: BSDate, to: BSDate) -> Int? {
        guard let fromAD = convertToADDate(from: from), let toAD = convertToADDate(from: to) else {
            return nil
        }
        let calendar = Calendar(identifier: .gregorian)
        let fromDate = calendar.startOfDay(for: fromAD)
        let toDate = calendar.startOfDay(for: toAD)
        
        let components = calendar.dateComponents([.day], from: fromDate, to: toDate)
        return components.day
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
    case today
    case calendar
    case settings
    case ai
    
    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .calendar: return "calendar"
        case .settings: return "gearshape"
        case .ai: return "sparkle"
        }
    }
    
    var title: String {
        switch self {
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .settings: return "Settings"
        case .ai: return "AI Chat"
        }
    }
    
    static let defaultsKey = "DefaultCalendarViewMode"
    
    static func loadDefault() -> CalendarViewMode {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let mode = CalendarViewMode(rawValue: raw) else {
            return .calendar
        }
        return mode
    }

    static func saveDefault(_ mode: CalendarViewMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }
}



// MARK: - App
@main
struct BhittePatroApp: App {
    @StateObject private var dateUpdater = DateUpdater()
    @StateObject private var noteManager = PatroNoteManager.shared

    var body: some Scene {
        // Menu bar extra remains your primary UI
        MenuBarExtra {
            VCenterView()
                .environmentObject(dateUpdater)
                .environmentObject(noteManager)
                .onAppear {
                    CalendarManager.shared.checkAndAutoUpdate()
                }
        } label: {
            HStack {
                Image(systemName: "calendar")
                if let today = NepaliCalendar.shared.convertToBSDate(from: dateUpdater.currentDate) {
                    Text(NepaliCalendar.shared.toNepaliDigits(today.day))
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Settings command for menu bar (opens inline settings in the menu bar window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(
                        name: .didChangeDefaultViewMode,
                        object: nil,
                        userInfo: ["mode": "settings"]
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
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
    @AppStorage("DefaultCalendarViewMode") private var defaultMode: String = "calendar"

    @State private var displayYear: Int
    @State private var displayMonth: Int
    @State private var selectedDate: BSDate?
    @State private var today: BSDate?
    @State private var adDate = Date()
    @State private var bsDate = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
    @State private var viewMode: CalendarViewMode
    @State private var previousMode: CalendarViewMode = .calendar
    @State private var selectionTimer: Timer? = nil

    private var primaryMode: CalendarViewMode {
        CalendarViewMode(rawValue: defaultMode) ?? .calendar
    }
    
    init() {
        let bsNow = NepaliCalendar.shared.convertToBSDate(from: Date()) ?? BSDate(year: 2081, month: 1, day: 1)
        _displayYear = State(initialValue: bsNow.year)
        _displayMonth = State(initialValue: bsNow.month)
        _today = State(initialValue: bsNow)
        _selectedDate = State(initialValue: nil) // Default to no explicit selection
        
        let initialMode = CalendarViewMode.loadDefault()
        _viewMode = State(initialValue: initialMode)
        _previousMode = State(initialValue: initialMode)
    }

    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            switch viewMode {
                case .calendar:
                    CalendarView(displayYear: $displayYear, displayMonth: $displayMonth, selectedDate: $selectedDate, today: $today, adDate: $adDate, bsDate: $bsDate, viewMode: $viewMode)
                case .today:
                    TodayView(currentDate: dateUpdater.currentDate, viewMode: $viewMode)
                case .settings:
                    SettingsView(onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = primaryMode
                        }
                    })
                case .ai:
                    AIChatView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .calendar
                        }
                    }
            }
        }
        .frame(width: viewMode == .today ? 210 : viewMode == .settings ? 390 : viewMode == .ai ? 370 : 330, height: viewMode == .today ? 220 : viewMode == .settings ? 520 : 470)
        .animation(.easeInOut(duration: 0.2), value: viewMode)
        .onReceive(NotificationCenter.default.publisher(for: .didChangeDefaultViewMode)) { notification in
            if let mode = notification.userInfo?["mode"] as? String {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if mode == "settings" {
                        viewMode = .settings
                    } else if let newMode = CalendarViewMode(rawValue: mode) {
                        viewMode = newMode
                    }
                }
            }
        }
        .onChange(of: defaultMode) { _, newValue in
            if let newMode = CalendarViewMode(rawValue: newValue), newMode != .settings {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = newMode
                }
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            selectionTimer?.invalidate()
            selectionTimer = nil
            
            if let selected = newValue, let t = today, selected != t {
                selectionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                    withAnimation {
                        selectedDate = t
                        displayYear = t.year
                        displayMonth = t.month
                    }
                }
            }
        }
        .onAppear {
            adDate = dateUpdater.currentDate
            if let bsToday = NepaliCalendar.shared.convertToBSDate(from: dateUpdater.currentDate) {
                bsDate = bsToday
                today = bsToday
                if selectedDate == nil {
                    selectedDate = bsToday
                }
            }
        }
        .onReceive(dateUpdater.$currentDate) { newDate in
            let oldToday = self.today
            adDate = newDate
            if let newBsToday = NepaliCalendar.shared.convertToBSDate(from: newDate) {
                // Update today and bsDate first
                self.today = newBsToday
                self.bsDate = newBsToday

                // If selection was nil, or was equal to the previous "today", or equals the new today, set selection to new today
                if selectedDate == nil ||
                   (oldToday != nil && selectedDate?.year == oldToday?.year && selectedDate?.month == oldToday?.month && selectedDate?.day == oldToday?.day) ||
                   (selectedDate?.year == newBsToday.year && selectedDate?.month == newBsToday.month && selectedDate?.day == newBsToday.day) {
                    selectedDate = newBsToday
                }
            }
        }
        .onDisappear {
            selectionTimer?.invalidate()
            selectionTimer = nil
        }
    }

    private func navigate(_ delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if m < 1 { m = 12; y -= 1 }
        else if m > 12 { m = 1; y += 1 }
        guard y >= 2060 && y <= 2085 else { return }
        if NepaliCalendar.shared.daysInMonth(year: y, month: m) > 0 {
            displayMonth = m; displayYear = y
            // keep selection within new month if possible
            if let sel = selectedDate, sel.year == y, sel.month == m {
                selectedDate = sel
            } else if let today = today, today.year == y, today.month == m {
                selectedDate = today
            } else {
                selectedDate = nil
            }
        }
    }
    
    private func otherModes(for current: CalendarViewMode) -> [CalendarViewMode] {
        // We only show functional modes in the footer (Today, Calendar).
        // Settings is now a standalone button on the left.
        
        let primary = primaryMode
        
        if current == primary {
            // If in primary mode (Today or Calendar), show the other one
            return primary == .today ? [.calendar] : [.today]
        } else {
            // In settings or other, show the primary
            return [primary]
        }
    }
}

#Preview("Menu Content") {
    VCenterView()
        .frame(width: 280)
        .padding()
}
