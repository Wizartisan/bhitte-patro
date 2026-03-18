import Foundation
import MachO

// MARK: - Models (Copied from App)
struct BSDate: Equatable {
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

    init() {
        loadCalendarData()
    }

    private func loadCalendarData() {
        let jsonPath = "NepaliPatro/data/calendar.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let decodedData = try? JSONDecoder().decode(CalendarData.self, from: data) else {
            print("⚠️  Failed to load calendar.json")
            return
        }

        for (yearStr, days) in decodedData.monthDaysData {
            if let year = Int(yearStr) { self.monthDaysData[year] = days }
        }

        for (yearStr, months) in decodedData.holidays {
            if let year = Int(yearStr) {
                var yearHolidays: [Int: [Int: [String]]] = [:]
                for (monthStr, days) in months {
                    if let month = Int(monthStr) {
                        var monthHolidays: [Int: [String]] = [:]
                        for (dayStr, names) in days {
                            if let day = Int(dayStr) { monthHolidays[day] = names }
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
                    if let month = Int(monthStr) { yearTithi[month] = days }
                }
                self.tithi[year] = yearTithi
            }
        }
    }

    func holidayText(year: Int, month: Int, day: Int) -> String? {
        guard let names = holidays[year]?[month]?[day], !names.isEmpty else { return nil }
        return names.joined(separator: " / ")
    }

    func tithiText(year: Int, month: Int, day: Int) -> String? {
        guard let monthTithis = tithi[year]?[month], day > 0 && day <= monthTithis.count else { return nil }
        let val = monthTithis[day - 1]
        return (val >= 1 && val <= 15) ? tithiNames[val] : nil
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
        }
        return BSDate(year: year, month: month, day: day)
    }

    func convertToADDate(from bsDate: BSDate) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var anchorComps = DateComponents()
        anchorComps.year = 2003; anchorComps.month = 4; anchorComps.day = 14
        guard let anchorADDate = calendar.date(from: anchorComps) else { return nil }

        var year = anchorYear, month = anchorMonth, day = anchorDay
        var totalDays = 0

        while year < bsDate.year {
            for m in 1...12 { totalDays += daysInMonth(year: year, month: m) }
            year += 1
        }
        while month < bsDate.month {
            totalDays += daysInMonth(year: year, month: month)
            month += 1
        }
        totalDays += (bsDate.day - day)

        return calendar.date(byAdding: .day, value: totalDays, to: anchorADDate)
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

// MARK: - Memory Measurement
func getMemoryUsage() -> (residentMB: Double, virtualMB: Double) {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    guard kerr == KERN_SUCCESS else {
        return (0, 0)
    }
    
    return (
        Double(taskInfo.resident_size) / 1024.0 / 1024.0,
        Double(taskInfo.virtual_size) / 1024.0 / 1024.0
    )
}

func getPeakMemory() -> Double {
    var rusage = rusage()
    getrusage(RUSAGE_SELF, &rusage)
    return Double(rusage.ru_maxrss) / 1024.0 // Convert KB to MB on macOS
}

// MARK: - Performance Tests
func runPerformanceTests() {
    print("\n╔══════════════════════════════════════════════════════════╗")
    print("║     NEPALI PATRO - PERFORMANCE & MEMORY BENCHMARK       ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    
    let calendar = NepaliCalendar.shared
    
    // Baseline memory before any operations
    let (baselineResident, baselineVirtual) = getMemoryUsage()
    let baselinePeak = getPeakMemory()
    
    // Generate test dates (100 random dates across valid range)
    let testDates: [Date] = {
        var dates: [Date] = []
        let baseDate = DateComponents(calendar: .current, year: 2000, month: 1, day: 1).date!
        for i in 0..<100 {
            let daysOffset = i * 100 // Spread across ~27 years
            if let date = Calendar.current.date(byAdding: .day, value: daysOffset, to: baseDate) {
                dates.append(date)
            }
        }
        return dates
    }()
    
    // Generate test BS dates
    let testBSDates: [BSDate] = [
        BSDate(year: 2060, month: 1, day: 1),
        BSDate(year: 2070, month: 6, day: 15),
        BSDate(year: 2080, month: 12, day: 30),
        BSDate(year: 2085, month: 3, day: 10)
    ]
    
    // ──────────────────────────────────────────────────────────────
    // 1. BS Date Conversion Performance (AD → BS)
    // ──────────────────────────────────────────────────────────────
    print("📊 BS Date Conversion (AD → BS)")
    print("─────────────────────────────────────────────────────────")
    
    let bsIterations = 100_000
    let bsStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<bsIterations {
        for date in testDates {
            _ = calendar.convertToBSDate(from: date)
        }
    }
    let bsDiff = CFAbsoluteTimeGetCurrent() - bsStart
    let bsTotalConversions = bsIterations * testDates.count
    
    print("   • Total Conversions: \(bsTotalConversions)")
    print("   • Total Time: \(String(format: "%.4f", bsDiff)) seconds")
    print("   • Avg per Conversion: \(String(format: "%.6f", bsDiff / Double(bsTotalConversions) * 1000)) ms")
    print("   • Conversions/sec: \(String(format: "%.0f", Double(bsTotalConversions) / bsDiff))")
    
    // ──────────────────────────────────────────────────────────────
    // 2. AD Date Conversion Performance (BS → AD)
    // ──────────────────────────────────────────────────────────────
    print("\n📊 AD Date Conversion (BS → AD)")
    print("─────────────────────────────────────────────────────────")
    
    let adIterations = 100_000
    let adStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<adIterations {
        for bsDate in testBSDates {
            _ = calendar.convertToADDate(from: bsDate)
        }
    }
    let adDiff = CFAbsoluteTimeGetCurrent() - adStart
    let adTotalConversions = adIterations * testBSDates.count
    
    print("   • Total Conversions: \(adTotalConversions)")
    print("   • Total Time: \(String(format: "%.4f", adDiff)) seconds")
    print("   • Avg per Conversion: \(String(format: "%.6f", adDiff / Double(adTotalConversions) * 1000)) ms")
    print("   • Conversions/sec: \(String(format: "%.0f", Double(adTotalConversions) / adDiff))")
    
    // ──────────────────────────────────────────────────────────────
    // 3. Holiday & Tithi Lookup Performance
    // ──────────────────────────────────────────────────────────────
    print("\n📊 Holiday & Tithi Lookup")
    print("─────────────────────────────────────────────────────────")
    
    let lookupIterations = 50_000
    let lookupStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<lookupIterations {
        for bsDate in testBSDates {
            _ = calendar.holidayText(year: bsDate.year, month: bsDate.month, day: bsDate.day)
            _ = calendar.tithiText(year: bsDate.year, month: bsDate.month, day: bsDate.day)
        }
    }
    let lookupDiff = CFAbsoluteTimeGetCurrent() - lookupStart
    let lookupTotalOperations = lookupIterations * testBSDates.count * 2
    
    print("   • Total Lookups: \(lookupTotalOperations)")
    print("   • Total Time: \(String(format: "%.4f", lookupDiff)) seconds")
    print("   • Avg per Lookup: \(String(format: "%.6f", lookupDiff / Double(lookupTotalOperations) * 1000)) ms")
    print("   • Lookups/sec: \(String(format: "%.0f", Double(lookupTotalOperations) / lookupDiff))")
    
    // ──────────────────────────────────────────────────────────────
    // 4. Memory Usage Analysis
    // ──────────────────────────────────────────────────────────────
    print("\n📊 Memory Usage Analysis")
    print("─────────────────────────────────────────────────────────")
    
    let (afterResident, afterVirtual) = getMemoryUsage()
    let afterPeak = getPeakMemory()
    
    let residentDelta = afterResident - baselineResident
    let peakMemory = afterPeak
    
    print("   • Baseline Resident Memory: \(String(format: "%.2f", baselineResident)) MB")
    print("   • After Operations Resident: \(String(format: "%.2f", afterResident)) MB")
    print("   • Memory Delta: \(String(format: "%+.2f", residentDelta)) MB")
    print("   • Peak Memory Usage: \(String(format: "%.2f", peakMemory)) MB")
    print("   • Virtual Memory: \(String(format: "%.2f", afterVirtual)) MB")
    
    // ──────────────────────────────────────────────────────────────
    // 5. Data Load Performance
    // ──────────────────────────────────────────────────────────────
    print("\n📊 Calendar Data Loading")
    print("─────────────────────────────────────────────────────────")
    
    let loadIterations = 100
    let loadStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<loadIterations {
        _ = NepaliCalendar.shared
    }
    let loadDiff = CFAbsoluteTimeGetCurrent() - loadStart
    
    print("   • Load Iterations: \(loadIterations)")
    print("   • Total Load Time: \(String(format: "%.4f", loadDiff)) seconds")
    print("   • Avg Load Time: \(String(format: "%.4f", loadDiff / Double(loadIterations) * 1000)) ms")
    
    // ──────────────────────────────────────────────────────────────
    // SUMMARY
    // ──────────────────────────────────────────────────────────────
    print("\n╔══════════════════════════════════════════════════════════╗")
    print("║                    PERFORMANCE SUMMARY                    ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  AD → BS Conversion:  \(String(format: "%10.0f", Double(bsTotalConversions) / bsDiff)) conversions/sec          ║")
    print("║  BS → AD Conversion:  \(String(format: "%10.0f", Double(adTotalConversions) / adDiff)) conversions/sec          ║")
    print("║  Holiday/Tithi Lookup: \(String(format: "%9.0f", Double(lookupTotalOperations) / lookupDiff)) lookups/sec          ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Peak Memory Usage:   \(String(format: "%11.2f", peakMemory)) MB                     ║")
    print("║  Memory Efficiency:   \(String(format: "%11s", residentDelta < 5 ? "Excellent" : "Good"))                         ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
}

// MARK: - Medium Test (~1GB scale)
func runMediumTest() {
    print("\n╔════════════════════════════════════════════════╗")
    print("║    NEPALI PATRO - MEDIUM PERFORMANCE TEST     ║")
    print("╚════════════════════════════════════════════════╝\n")

    let calendar = NepaliCalendar.shared
    let (baselineResident, _) = getMemoryUsage()

    // Generate test data across full date range
    var testDates: [Date] = []
    let baseDate = DateComponents(calendar: .current, year: 2000, month: 1, day: 1).date!
    for i in 0..<500 {
        if let date = Calendar.current.date(byAdding: .day, value: i * 20, to: baseDate) {
            testDates.append(date)
        }
    }

    var testBSDates: [BSDate] = []
    for year in stride(from: 2060, to: 2090, by: 2) {
        for month in stride(from: 1, to: 12, by: 3) {
            testBSDates.append(BSDate(year: year, month: month, day: 15))
        }
    }

    // BS Date Conversion (10,000 iterations)
    print("🔄 Running AD → BS conversions...")
    let bsStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<10_000 {
        for date in testDates {
            _ = calendar.convertToBSDate(from: date)
        }
    }
    let bsDiff = CFAbsoluteTimeGetCurrent() - bsStart
    let bsTotal = 10_000 * testDates.count

    // AD Date Conversion (10,000 iterations)
    print("🔄 Running BS → AD conversions...")
    let adStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<10_000 {
        for bsDate in testBSDates {
            _ = calendar.convertToADDate(from: bsDate)
        }
    }
    let adDiff = CFAbsoluteTimeGetCurrent() - adStart
    let adTotal = 10_000 * testBSDates.count

    // Holiday/Tithi Lookup (5,000 iterations)
    print("🔍 Running holiday/tithi lookups...")
    let lookupStart = CFAbsoluteTimeGetCurrent()
    for _ in 0..<5_000 {
        for bsDate in testBSDates {
            _ = calendar.holidayText(year: bsDate.year, month: bsDate.month, day: bsDate.day)
            _ = calendar.tithiText(year: bsDate.year, month: bsDate.month, day: bsDate.day)
        }
    }
    let lookupDiff = CFAbsoluteTimeGetCurrent() - lookupStart
    let lookupTotal = 5_000 * testBSDates.count * 2

    // Memory
    let (afterResident, afterVirtual) = getMemoryUsage()
    let memoryDelta = afterResident - baselineResident

    // Results
    print("\n📊 Performance Results")
    print("─────────────────────────────────────────────────")
    print("   • AD → BS: \(String(format: "%.0f", Double(bsTotal) / bsDiff)) conv/sec (~\(String(format: "%.4f", bsDiff / Double(bsTotal) * 1000)) ms)")
    print("   • BS → AD: \(String(format: "%.0f", Double(adTotal) / adDiff)) conv/sec (~\(String(format: "%.4f", adDiff / Double(adTotal) * 1000)) ms)")
    print("   • Lookup:  \(String(format: "%.0f", Double(lookupTotal) / lookupDiff)) lookups/sec (~\(String(format: "%.4f", lookupDiff / Double(lookupTotal) * 1000)) ms)")
    print("   • Total Operations: \(bsTotal + adTotal + lookupTotal)")
    print("   • Memory Delta: ~\(String(format: "%.1f", memoryDelta)) MB")
    print("   • Virtual Memory: ~\(String(format: "%.1f", afterVirtual)) MB")
    print("\n✅ Medium test complete!\n")
}

// Run medium test
runMediumTest()
