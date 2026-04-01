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

    private let rowSpacing: CGFloat = 2
    private let cellCornerRadius: CGFloat = 6
    private let numberOfRows = 6  // Always show 6 rows
    
    @State private var monthTransitionPhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
                .frame(height: 56)

            // Weekday headers
            weekdaySection
                .frame(height: 32)

            // Calendar grid with directional slide animation
            calendarGridSection
                .animation(.easeInOut(duration: 0.25), value: displayMonth)

            // Selected date info
            selectedDateSection
        }
        .padding(16)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 8) {
            // Month and Year selector (left side)
            HStack(spacing: 4) {
                Button(action: { navigate(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)

                // Month selector
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button(action: { displayMonth = month }) {
                            HStack {
                                Text(NepaliCalendar.shared.months[month - 1])
                                if displayMonth == month {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Color.clear
                        Text(NepaliCalendar.shared.months[displayMonth - 1])
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 120, height: 32)
                }
                .menuStyle(.borderlessButton)
                .contentTransition(.numericText())

                // Year selector
                Menu {
                    ForEach(2060...2085, id: \.self) { year in
                        Button(action: { displayYear = year }) {
                            HStack {
                                Text(NepaliCalendar.shared.toNepaliDigits(year))
                                if displayYear == year {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Color.clear
                        Text(NepaliCalendar.shared.toNepaliDigits(displayYear))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 65, height: 32)
                }
                .menuStyle(.borderlessButton)
                .contentTransition(.numericText())

                Button(action: { navigate(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // Right side controls: आज button (only if not in current month) + Settings
            HStack(spacing: 4) {
                // आज button (only if not in current month)
                if let today = today, !(today.year == displayYear && today.month == displayMonth) {
                    Button("आज") {
                        withAnimation {
                            displayYear = today.year
                            displayMonth = today.month
                            selectedDate = today
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .buttonStyle(.plain)
                }

                // Settings button -> use SettingsLink to open Settings scene
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
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
                    .onTapGesture {
                        handleCellTap(cell: cell)
                    }
                }
            }
            .frame(height: CGFloat(numberOfRows) * cellHeight + CGFloat(numberOfRows - 1) * rowSpacing)
        }
        .animation(.easeInOut(duration: 0.2), value: displayMonth)
    }

    // MARK: - Selected Date Section
    private var selectedDateSection: some View {
        Group {
               if let sel = selectedDate {

                   let isToday = today?.year == sel.year && today?.month == sel.month && today?.day == sel.day
                   
                   let upcoming = isToday ? NepaliCalendar.shared.nextHoliday(
                       from: sel.year,
                       month: sel.month,
                       day: sel.day
                   ) : nil

                   VStack(alignment: .leading, spacing: 6) {

                       HStack {
                           if isToday {
                               Text("Today")
                                   .font(.system(size: 12, weight: .semibold))
                                   .foregroundStyle(.secondary)
                               Text("\(NepaliCalendar.shared.months[sel.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(sel.day))")
                                   .font(.system(size: 12, weight: .semibold))
                                   .foregroundStyle(.secondary)
                           } else {
                               Text("\(NepaliCalendar.shared.months[sel.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(sel.day))")
                                   .font(.system(size: 12, weight: .semibold))
                                   .foregroundStyle(.secondary)
                           }

                           Spacer()

                           if isToday {
                               Text("Upcoming")
                                   .font(.system(size: 12, weight: .semibold))
                                   .foregroundStyle(.secondary)
                           }
                       }

                       HStack {
                           // LEFT SIDE
                           HStack(spacing: 6) {
                               if let hText = NepaliCalendar.shared.holidayText(
                                   year: sel.year,
                                   month: sel.month,
                                   day: sel.day
                               ) {
                                   Text(hText)
                                       .foregroundStyle(.red)
                               }

                               if let tithi = NepaliCalendar.shared.tithiText(
                                   year: sel.year,
                                   month: sel.month,
                                   day: sel.day
                               ) {
                                   Text(tithi)
                                       .foregroundStyle(.secondary)
                               }
                           }
                           .font(.system(size: 13, weight: .medium))
                           .lineLimit(1)

                           Spacer()

                           // RIGHT SIDE (Upcoming)
                           if let upcoming = upcoming {
                               Text("\(upcoming.text) \(NepaliCalendar.shared.toNepaliDigits(upcoming.daysAway)) दिन पछि ")
                                   .font(.system(size: 13, weight: .medium))
                                   .foregroundStyle(.blue)
                                   .lineLimit(1)
                           }
                       }
                   }
                   .frame(maxWidth: .infinity, alignment: .leading)
                   .padding(.horizontal, 12)
                   .padding(.vertical, 8)
                   .background(
                       Color.secondary.opacity(0.05),
                       in: RoundedRectangle(cornerRadius: 8)
                   )
               }
            else {
                // Placeholder when no date selected
                Text("Select a date")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helper Methods
    private func handleCellTap(cell: CellModel) {
        let tapped = BSDate(year: cell.bsYear, month: cell.bsMonth, day: cell.bsDay)

        if cell.bsYear == displayYear && cell.bsMonth == displayMonth {
            selectedDate = tapped
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayYear = cell.bsYear
                displayMonth = cell.bsMonth
                selectedDate = tapped
            }
        }
    }

    private func navigate(_ delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if m < 1 { m = 12; y -= 1 }
        else if m > 12 { m = 1; y += 1 }
        guard y >= 2060 && y <= 2085 else { return }
        if NepaliCalendar.shared.daysInMonth(year: y, month: m) > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayMonth = m
                displayYear = y
                if selectedDate == nil {
                    selectedDate = today
                }
            }
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

    @State private var isCurrentMonth = false

    private let cellCornerRadius: CGFloat = 6

    var body: some View {
        let isSelected: Bool = {
            if let sel = selectedDate {
                return sel.year == cell.bsYear && sel.month == cell.bsMonth && sel.day == cell.bsDay
            }
            return false
        }()

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

