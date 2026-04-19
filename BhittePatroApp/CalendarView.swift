//
//  CalendarView.swift
//  BhittePatroApp
//
//  Created by Pranab Kc on 16/03/2026.
//

import SwiftUI

struct CalendarView: View {
    @Binding var displayYear: Int
    @Binding var displayMonth: Int
    @Binding var selectedDate: BSDate?
    @Binding var today: BSDate?
    @Binding var adDate: Date
    @Binding var bsDate: BSDate
    @Binding var viewMode: CalendarViewMode
    
    @EnvironmentObject var noteManager: PatroNoteManager
    @State private var showNoteEditor: Bool = false
    @State private var popoverDate: BSDate? = nil

    private let rowSpacing: CGFloat = 2
    private let cellCornerRadius: CGFloat = 6
    private let numberOfRows = 6  // Always show 6 rows
    
    @State private var monthTransitionPhase: Double = 0

    private var displayMonthName: String {
        NepaliCalendar.shared.months[displayMonth - 1]
    }

    private var displayYearText: String {
        NepaliCalendar.shared.toNepaliDigits(displayYear)
    }

    private var englishMonthLabel: String? {
        let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)
        guard
            let startDate = NepaliCalendar.shared.convertToADDate(from: BSDate(year: displayYear, month: displayMonth, day: 1)),
            let endDate = NepaliCalendar.shared.convertToADDate(from: BSDate(year: displayYear, month: displayMonth, day: daysInMonth))
        else {
            return nil
        }

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM"

        let yearFormatter = DateFormatter()
        yearFormatter.locale = Locale(identifier: "en_US_POSIX")
        yearFormatter.dateFormat = "yyyy"

        let startMonth = monthFormatter.string(from: startDate)
        let endMonth = monthFormatter.string(from: endDate)
        let startYear = yearFormatter.string(from: startDate)
        let endYear = yearFormatter.string(from: endDate)

        if startMonth == endMonth && startYear == endYear {
            return "\(startMonth) \(startYear)"
        }
        if startYear == endYear {
            return "\(startMonth)-\(endMonth) \(startYear)"
        }
        return "\(startMonth) \(startYear)-\(endMonth) \(endYear)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showNoteEditor, let sel = selectedDate {
                NoteEditorView(date: sel, noteManager: _noteManager.wrappedValue) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNoteEditor = false
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                        .frame(height: 38)
                        .padding(.bottom, 10)

                    // Weekday headers
                    weekdaySection
                        .frame(height: 32)

                    // Calendar grid with directional slide animation
                    calendarGridSection
                        .animation(.easeInOut(duration: 0.25), value: displayMonth)

                    // Selected date info / Settings
                    footerSection
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .padding(16)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 0) {
            // Month/Year Navigation
            HStack(spacing: 12) {
                Button(action: { navigate(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button(action: { displayMonth = month }) {
                            Text(NepaliCalendar.shared.months[month - 1])
                        }
                    }
                } label: {
                    Text(displayMonthName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Menu {
                    ForEach(2060...2085, id: \.self) { year in
                        Button(action: { displayYear = year }) {
                            Text(NepaliCalendar.shared.toNepaliDigits(year))
                        }
                    }
                } label: {
                    Text(displayYearText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Button(action: { navigate(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                // "Today" Button
                if let today, !(today.year == displayYear && today.month == displayMonth) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayYear = today.year
                            displayMonth = today.month
                            selectedDate = today
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.2.squarepath")
                                .font(.system(size: 11, weight: .semibold))
                            Text("आज")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // AI Chat Button
                if let today, today.year == displayYear && today.month == displayMonth {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .ai
                        }
                    }) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.purple.gradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    // MARK: - Weekday Section
    private var weekdaySection: some View {
        HStack(spacing: 0) {
            ForEach(NepaliCalendar.shared.weekDays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(day == "शनि" ? .red : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Calendar Grid Section
    private var calendarGridSection: some View {
        let firstWeekday = NepaliCalendar.shared.firstWeekday(year: displayYear, month: displayMonth)
        let daysInMonth = NepaliCalendar.shared.daysInMonth(year: displayYear, month: displayMonth)
        let cells = buildCells(firstWeekday: firstWeekday, daysInMonth: daysInMonth)
        let cellHeight = CGFloat(45)

        return GeometryReader { geo in
            let totalWidth = geo.size.width
            let cellSize = (totalWidth - (6 * rowSpacing)) / 7

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: rowSpacing), count: 7),
                alignment: .center,
                spacing: rowSpacing
            ) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                    CalendarCellView(
                        cell: cell,
                        index: index,
                        cellSize: cellSize,
                        cellHeight: cellHeight,
                        selectedDate: selectedDate,
                        displayYear: displayYear,
                        displayMonth: displayMonth
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { handleCellTap(cell: cell) }
                    .popover(item: Binding(
                        get: { popoverDate == BSDate(year: cell.bsYear, month: cell.bsMonth, day: cell.bsDay) ? cell.toBSDate() : nil },
                        set: { if $0 == nil { popoverDate = nil } }
                    )) { date in
                        PopoverContentView(date: date, onEdit: {
                            popoverDate = nil
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNoteEditor = true
                            }
                        })
                    }
                }
            }
            .frame(height: CGFloat(numberOfRows) * cellHeight + CGFloat(numberOfRows - 1) * rowSpacing)
        }
        .animation(.easeInOut(duration: 0.2), value: displayMonth)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        HStack(alignment: .center) {
            // Selected date info
            Group {
                if let sel = selectedDate {
                    let isToday = today?.year == sel.year && today?.month == sel.month && today?.day == sel.day
                    let holiday = NepaliCalendar.shared.holidayText(year: sel.year, month: sel.month, day: sel.day)
                    let upcoming = isToday ? NepaliCalendar.shared.nextHoliday(from: sel.year, month: sel.month, day: sel.day) : nil
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("\(NepaliCalendar.shared.months[sel.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(sel.day))")
                                .font(.system(size: 9, weight: .bold))
                            
                            Text(getEnglishDay(year: sel.year, month: sel.month, day: sel.day))
                                .font(.system(size: 9, weight: .medium))
                                .opacity(0.6)
                        }
                        .foregroundStyle(.secondary)

                        Group {
                            if let holidayText = holiday {
                                Text(holidayText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.red)
                            } else if let upcomingHoliday = upcoming {
                                HStack(spacing: 4) {
                                    Text("\(NepaliCalendar.shared.toNepaliDigits(upcomingHoliday.daysAway)) दिन मा")
                                        .foregroundStyle(.white)
                                    Text(upcomingHoliday.text)
                                        .foregroundStyle(.red)
                                }
                                .font(.system(size: 10, weight: .medium))
                            } else {
                                Text(isToday ? "No upcoming holidays" : "No holiday")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("Select a date")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Settings Button
            Button {
                NotificationCenter.default.post(
                    name: .didChangeDefaultViewMode,
                    object: nil,
                    userInfo: ["mode": "settings"]
                )
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.secondary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // MARK: - Helper Methods
    private func handleCellTap(cell: CellModel) {
        let tapped = BSDate(year: cell.bsYear, month: cell.bsMonth, day: cell.bsDay)
        
        selectedDate = tapped
        
        if popoverDate == tapped {
            popoverDate = nil
        } else {
            popoverDate = tapped
        }
    }

    private func navigate(_ delta: Int) {
        var newMonth = displayMonth + delta
        var newYear = displayYear
        
        if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        } else if newMonth > 12 {
            newMonth = 1
            newYear += 1
        }
        
        guard newYear >= 2060 && newYear <= 2085 else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            displayMonth = newMonth
            displayYear = newYear
        }
    }

    private func buildCells(firstWeekday: Int, daysInMonth: Int) -> [CellModel] {
        let prevMonth = displayMonth == 1 ? 12 : displayMonth - 1
        let prevYear = displayMonth == 1 ? displayYear - 1 : displayYear
        let daysInPrevMonth = NepaliCalendar.shared.daysInMonth(year: prevYear, month: prevMonth)

        let nextMonth = displayMonth == 12 ? 1 : displayMonth + 1
        let nextYear = displayMonth == 12 ? displayYear + 1 : displayYear

        var result: [CellModel] = []

        // Previous month days
        for i in 0..<firstWeekday {
            let day = daysInPrevMonth - (firstWeekday - 1) + i
            let nepaliDay = NepaliCalendar.shared.toNepaliDigits(day)
            let englishDay = getEnglishDay(year: prevYear, month: prevMonth, day: day)
            result.append(CellModel(
                bsYear: prevYear, bsMonth: prevMonth, bsDay: day,
                isCurrent: false,
                isToday: false,
                isHoliday: false,
                englishDay: englishDay,
                nepaliDay: nepaliDay
            ))
        }

        // Current month days
        for day in 1...daysInMonth {
            let isToday = today?.day == day && today?.month == displayMonth && today?.year == displayYear
            let isHoliday = NepaliCalendar.shared.holidayText(year: displayYear, month: displayMonth, day: day) != nil
            let nepaliDay = NepaliCalendar.shared.toNepaliDigits(day)
            let englishDay = getEnglishDay(year: displayYear, month: displayMonth, day: day)
            result.append(CellModel(
                bsYear: displayYear, bsMonth: displayMonth, bsDay: day,
                isCurrent: true,
                isToday: isToday,
                isHoliday: isHoliday,
                englishDay: englishDay,
                nepaliDay: nepaliDay
            ))
        }

        // Next month days - fill remaining to always have 42 cells (6 rows x 7 days)
        let remainingCells = 42 - result.count
        for day in 1...remainingCells {
            let nepaliDay = NepaliCalendar.shared.toNepaliDigits(day)
            let englishDay = getEnglishDay(year: nextYear, month: nextMonth, day: day)
            result.append(CellModel(
                bsYear: nextYear, bsMonth: nextMonth, bsDay: day,
                isCurrent: false,
                isToday: false,
                isHoliday: false,
                englishDay: englishDay,
                nepaliDay: nepaliDay
            ))
        }

        return result
    }
    
    private func getEnglishDay(year: Int, month: Int, day: Int) -> String {
        guard let ad = NepaliCalendar.shared.convertToADDate(from: BSDate(year: year, month: month, day: day)) else {
            return ""
        }
        let calendarDay = Calendar(identifier: .gregorian).component(.day, from: ad)
        return String(calendarDay)
    }
}

// MARK: - Popover Content
struct PopoverContentView: View {
    let date: BSDate
    var onEdit: () -> Void
    @EnvironmentObject var noteManager: PatroNoteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tithi
            VStack(alignment: .leading, spacing: 2) {
                Text("तिथि")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Text(NepaliCalendar.shared.tithiText(year: date.year, month: date.month, day: date.day) ?? "-")
                    .font(.system(size: 12, weight: .semibold))
            }
            
            Divider()
            
            // Notes
            VStack(alignment: .leading, spacing: 4) {
                let dateString = "\(date.year)-\(String(format: "%02d", date.month))-\(String(format: "%02d", date.day))"
                let hasNote = noteManager.notes[dateString] != nil && !noteManager.notes[dateString]!.isEmpty
                
                HStack {
                    Text("NOTES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                if hasNote {
                    Text(noteManager.notes[dateString]!)
                        .font(.system(size: 11))
                        .lineLimit(4)
                }
                
                Button(action: onEdit) {
                    Label(hasNote ? "Edit Note" : "Add Note", systemImage: hasNote ? "pencil.line" : "plus")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

            }
        }
        .padding(12)
        .frame(width: 180)
    }
}

// MARK: - Cell Model
fileprivate struct CellModel: Equatable {
    let bsYear: Int
    let bsMonth: Int
    let bsDay: Int
    let isCurrent: Bool
    let isToday: Bool
    let isHoliday: Bool
    let englishDay: String
    let nepaliDay: String
    
    func toBSDate() -> BSDate {
        BSDate(year: bsYear, month: bsMonth, day: bsDay)
    }
    
    static func == (lhs: CellModel, rhs: CellModel) -> Bool {
        return lhs.bsYear == rhs.bsYear &&
               lhs.bsMonth == rhs.bsMonth &&
               lhs.bsDay == rhs.bsDay &&
               lhs.isCurrent == rhs.isCurrent &&
               lhs.isToday == rhs.isToday &&
               lhs.isHoliday == rhs.isHoliday
    }
}

// MARK: - Calendar Cell View
fileprivate struct CalendarCellView: View {
    let cell: CellModel
    let index: Int
    let cellSize: CGFloat
    let cellHeight: CGFloat
    let selectedDate: BSDate?
    let displayYear: Int
    let displayMonth: Int
    
    @EnvironmentObject var noteManager: PatroNoteManager

    @State private var isCurrentMonth = false

    private let cellCornerRadius: CGFloat = 6

    var body: some View {
        let isSelected: Bool = {
            if let sel = selectedDate {
                return sel.year == cell.bsYear && sel.month == cell.bsMonth && sel.day == cell.bsDay
            }
            return false
        }()
        
        let dateString = "\(cell.bsYear)-\(String(format: "%02d", cell.bsMonth))-\(String(format: "%02d", cell.bsDay))"
        let hasNote = noteManager.notes[dateString] != nil && !noteManager.notes[dateString]!.isEmpty

        let animationDelay = Double(index) * 0.003

        ZStack {
            // Background - only today gets highlighted
            if cell.isToday {
                RoundedRectangle(cornerRadius: cellCornerRadius)
                    .fill(Color.red)
            } else if isSelected {
                RoundedRectangle(cornerRadius: cellCornerRadius)
                    .fill(Color.secondary.opacity(0.15))
            }
            
            // Note indicator
            if hasNote {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 7))
                            .foregroundStyle(cell.isToday ? .white : .secondary)
                            .padding(4)
                    }
                    Spacer()
                }
            }

            // Content
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Nepali day number
                Text(cell.nepaliDay)
                    .font(.system(size: 18, weight: cell.isToday ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(
                        cell.isToday ? Color.white :
                        (cell.isCurrent && cell.isHoliday) ? Color.red :
                        (cell.isCurrent && index % 7 == 6) ? Color.red :
                        (isSelected ? Color.secondary :
                        (cell.isCurrent ? Color.primary : Color.gray.opacity(0.5)))
                    )

                Spacer(minLength: 0)

                // English day number
                HStack {
                    Spacer(minLength: 0)
                    if !cell.englishDay.isEmpty {
                        Text(cell.englishDay)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                cell.isToday ? Color.white.opacity(0.9) :
                                isSelected ? Color.secondary :
                                (cell.isCurrent ? Color.secondary : Color.gray.opacity(0.4))
                            )
                            .padding(.trailing, 3)
                            .padding(.bottom, 2)
                    }
                }
            }
        }
        .frame(width: cellSize, height: cellHeight)
        .opacity(cell.isCurrent ? (isCurrentMonth ? 1 : 0.5) : 0.6)
        .scaleEffect(cell.isCurrent ? (isCurrentMonth ? 1 : 0.85) : 1)
        .animation(.easeOut(duration: 0.25).delay(animationDelay), value: isCurrentMonth)
        .onChange(of: displayYear) { _, _ in
            if cell.isCurrent {
                withAnimation {
                    isCurrentMonth = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        isCurrentMonth = (cell.bsYear == displayYear && cell.bsMonth == displayMonth)
                    }
                }
            }
        }
        .onChange(of: displayMonth) { _, _ in
            if cell.isCurrent {
                withAnimation {
                    isCurrentMonth = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        isCurrentMonth = (cell.bsYear == displayYear && cell.bsMonth == displayMonth)
                    }
                }
            }
        }
        .onAppear {
            isCurrentMonth = (cell.bsYear == displayYear && cell.bsMonth == displayMonth)
        }
    }
}
