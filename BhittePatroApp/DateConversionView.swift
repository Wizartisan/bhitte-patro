//  DateConversionView.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 16/03/2026.
//

import SwiftUI

struct DateConversionView: View {
    @Binding var adDate: Date
    @Binding var bsDate: BSDate
    @Binding var viewMode: CalendarViewMode

    @State private var dayText: String = ""
    @State private var monthText: String = ""
    @State private var yearText: String = ""

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Converter")
                    .font(.title3)
                    .bold()
                Spacer()
                Button {
                    // Open the standalone Settings window instead of inline settings
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            // ── BS Date (Hero) ───────────────────────────────────────────
            VStack(spacing: 4) {
                Text(NepaliCalendar.shared.months[bsDate.month - 1])
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Text(NepaliCalendar.shared.toNepaliDigits(bsDate.year))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NepaliCalendar.shared.toNepaliDigits(bsDate.day))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

            // ── Divider arrow ────────────────────────────────────────────
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 12)

            // ── AD Date Input ─────────────────────────────────────────────
            HStack(spacing: 8) {
                Label("AD", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                // Day
                ADField(text: $dayText, placeholder: "DD", maxLength: 2)
                    .onChange(of: dayText) { _, _ in commitDate() }

                Text("/").foregroundStyle(.tertiary)

                // Month
                ADField(text: $monthText, placeholder: "MM", maxLength: 2)
                    .onChange(of: monthText) { _, _ in commitDate() }

                Text("/").foregroundStyle(.tertiary)

                // Year
                ADField(text: $yearText, placeholder: "YYYY", maxLength: 4, width: 54)
                    .onChange(of: yearText) { _, _ in commitDate() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
        .onAppear { syncFromDate(adDate) }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private func syncFromDate(_ date: Date) {
        let comps = calendar.dateComponents([.day, .month, .year], from: date)
        dayText   = String(format: "%02d", comps.day   ?? 1)
        monthText = String(format: "%02d", comps.month ?? 1)
        yearText  = String(comps.year ?? 2025)
    }

    private func commitDate() {
        guard
            let d = Int(dayText),   (1...31).contains(d),
            let m = Int(monthText), (1...12).contains(m),
            let y = Int(yearText),  y > 999
        else { return }

        var comps        = DateComponents()
        comps.day        = d
        comps.month      = m
        comps.year       = y
        comps.hour       = 12
        comps.minute     = 0
        comps.second     = 0

        guard let date = calendar.date(from: comps) else { return }
        adDate = date
        if let bs = NepaliCalendar.shared.convertToBSDate(from: date) {
            bsDate = bs
        }
    }
}

// ── Tiny reusable text field ──────────────────────────────────────────────

private struct ADField: View {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int
    var width: CGFloat = 36

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(width: width)
            .onChange(of: text) { _, new in
                // digits only, capped at maxLength
                let filtered = String(new.filter(\.isNumber).prefix(maxLength))
                if filtered != new { text = filtered }
            }
    }
}
