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

    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
                .frame(height: 56)

            // Weekday headers
            weekdaySection
                .frame(height: 32)

            // Calendar grid - always 6 rows
            calendarGridSection

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
                    HStack {
                        Spacer()
                        Text(NepaliCalendar.shared.months[displayMonth - 1])
                            .font(.system(sfrize: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(width: 140)
                }
                .menuStyle(.borderlessButton)

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
                    Text(NepaliCalendar.shared.toNepaliDigits(displayYear))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 65, alignment: .center)
                }
                .menuStyle(.borderlessButton)

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

                // Settings button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = .settings
                    }
                } label: {
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
                    .foregroundColor(day == "आइत" || day == "शनि" ? .red : .secondary)
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
                        selectedDate: selectedDate
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleCellTap(cell: cell)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: CGFloat(numberOfRows) * cellHeight + CGFloat(numberOfRows - 1) * rowSpacing)
        }
    }

    // MARK: - Selected Date Section
    private var selectedDateSection: some View {
        Group {
            if let sel = selectedDate {
                VStack(alignment: .leading, spacing: 4) {
                    // Date label
                    Text("\(NepaliCalendar.shared.months[sel.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(sel.day)), \(NepaliCalendar.shared.toNepaliDigits(sel.year))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    // Holiday and Tithi
                    HStack(alignment: .center, spacing: 8) {
                        if let hText = NepaliCalendar.shared.holidayText(year: sel.year, month: sel.month, day: sel.day) {
                            Text(hText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }

                        if let tithi = NepaliCalendar.shared.tithiText(year: sel.year, month: sel.month, day: sel.day) {
                            Text(tithi)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            } else {
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
            displayMonth = m
            displayYear = y
            if selectedDate == nil {
                selectedDate = today
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
            result.append(CellModel(
                bsYear: prevYear, bsMonth: prevMonth, bsDay: day,
                isCurrent: false,
                isToday: false,
                isHoliday: false
            ))
        }

        // Current month days
        for day in 1...daysInMonth {
            let isToday = today?.day == day && today?.month == displayMonth && today?.year == displayYear
            let isHoliday = NepaliCalendar.shared.holidayText(year: displayYear, month: displayMonth, day: day) != nil
            result.append(CellModel(
                bsYear: displayYear, bsMonth: displayMonth, bsDay: day,
                isCurrent: true,
                isToday: isToday,
                isHoliday: isHoliday
            ))
        }

        // Next month days - fill remaining to always have 42 cells (6 rows x 7 days)
        let totalCells = result.count
        let remainingCells = 42 - totalCells
        for day in 1...remainingCells {
            result.append(CellModel(
                bsYear: nextYear, bsMonth: nextMonth, bsDay: day,
                isCurrent: false,
                isToday: false,
                isHoliday: false
            ))
        }

        return result
    }
}

// MARK: - Cell Model
fileprivate struct CellModel {
    let bsYear: Int
    let bsMonth: Int
    let bsDay: Int
    let isCurrent: Bool
    let isToday: Bool
    let isHoliday: Bool
}

// MARK: - Calendar Cell View
fileprivate struct CalendarCellView: View {
    let cell: CellModel
    let index: Int
    let cellSize: CGFloat
    let cellHeight: CGFloat
    let selectedDate: BSDate?

    private let cellCornerRadius: CGFloat = 6

    var body: some View {
        let isSelected: Bool = {
            if let sel = selectedDate {
                return sel.year == cell.bsYear && sel.month == cell.bsMonth && sel.day == cell.bsDay
            }
            return false
        }()

        let nepaliLabel = NepaliCalendar.shared.toNepaliDigits(cell.bsDay)
        let englishDay: String = {
            if let ad = NepaliCalendar.shared.convertToADDate(from: BSDate(year: cell.bsYear, month: cell.bsMonth, day: cell.bsDay)) {
                let day = Calendar(identifier: .gregorian).component(.day, from: ad)
                return String(day)
            } else {
                return ""
            }
        }()

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
                Text(nepaliLabel)
                    .font(.system(size: 18, weight: cell.isToday ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(
                        cell.isToday ? Color.white :
                        isSelected ? Color.secondary :
                        (cell.isCurrent && (index % 7 == 6 || cell.isHoliday)) ? Color.red :
                        (cell.isCurrent ? Color.primary : Color.secondary.opacity(0.3))
                    )

                Spacer(minLength: 0)

                // English day number
                HStack {
                    Spacer(minLength: 0)
                    if !englishDay.isEmpty {
                        Text(englishDay)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                cell.isToday ? Color.white.opacity(0.9) :
                                isSelected ? Color.secondary :
                                (cell.isCurrent ? Color.secondary : Color.secondary.opacity(0.2))
                            )
                            .padding(.trailing, 3)
                            .padding(.bottom, 2)
                    }
                }
            }
        }
        .frame(width: cellSize, height: cellHeight)
    }
}
