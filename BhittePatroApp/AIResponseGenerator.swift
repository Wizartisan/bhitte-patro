//
//  AIResponseGenerator.swift
//  BhittePatroApp
//
//  Created by Pranab Kc on 18/04/2026.
//

import Foundation

class AIResponseGenerator {
    static let shared = AIResponseGenerator()
    
    // MARK: - Knowledge Base Models
    struct KnowledgeBase: Codable {
        let calendarInfo: CalendarInfo
        let tithiInfo: TithiInfo
        let holidays: [HolidayInfo]
        
        enum CodingKeys: String, CodingKey {
            case calendarInfo = "calendar_info"
            case tithiInfo = "tithi_info"
            case holidays
        }
    }
    
    struct CalendarInfo: Codable {
        let name: String
        let description: String
        let history: String
        let whyItExists: String
        let newYear: String
        
        enum CodingKeys: String, CodingKey {
            case name, description, history
            case whyItExists = "why_it_exists"
            case newYear = "new_year"
        }
    }
    
    struct TithiInfo: Codable {
        let definition: String
        let phases: [String: String]
        let significance: String
        let names: [String]
    }
    
    struct HolidayInfo: Codable {
        let name: String
        let significance: String
        let traditions: String
    }
    
    private var knowledgeBase: KnowledgeBase?
    
    private var conversationState: ConversationState = .idle
    private var userOffDays: [Int]? // 0 = Sunday, 6 = Saturday
    private var lastHolidayQueried: String?
    private var lastAction: AIAction?
    private var leaveDaysToTake: Int?
    private var conversionType: ConversionType?
    
    // For days between calculation
    private var daysBetweenStart: (month: Int, day: Int)?
    private var daysBetweenEnd: (month: Int, day: Int)?
    private var daysBetweenYear: Int?

    private enum ConversationState {
        case idle
        case awaitingOffDays
        case awaitingLeaveDayCount
        case awaitingDesiredBreakLength
        case awaitingConversionType
        case awaitingConversionDate
        case awaitingDaysBetweenRange
        case awaitingDaysBetweenYear
        case awaitingHolidayDescription
    }
    
    private enum ConversionType {
        case bsToAD
        case adToBS
    }
    
    private enum AIAction {
        case checkingHoliday
        case checkingDate
        case calculatingDuration
        case planningVacation
    }
    
    private let holidaySynonyms: [String: [String]] = [
        "dashain": ["dashain", "दशैं", "विजया दशमी", "dashain", "dasain", "dhashain", "dashin", "dahsian", "dashian", "dasain"],
        "tihar": ["tihar", "तिहार", "दीपावली", "tihar", "deepawali", "yamapanchak", "tihaar", "deewali", "tiihaar", "deepwali"],
        "kukur tihar": ["kukur tihar", "कुकुर तिहार", "dog festival"],
        "gai tihar": ["gai tihar", "गाई तिहार", "laxmi puja", "lakshmi puja", "laxmi pooja"],
        "bhai tika": ["bhai tika", "भाइटीका", "bhaitika", "bhai teeka"],
        "holi": ["holi", "होली", "फागु पूर्णिमा", "fagu purnima", "fagu", "holy", "holli"],
        "new year": ["navabarsha", "नयाँ वर्ष", "new year", "nava barsha", "nawayars", "nayabarsa", "nayan barsa"],
        "maha shivaratri": ["maha shivaratri", "महाशिवरात्री", "shivaratri", "shiva ratri", "shivratri", "shivaratry", "shiva"],
        "gai jatra": ["gai jatra", "गाईजात्रा", "gaijatra", "gai jatra"],
        "buddha jayanti": ["buddha jayanti", "बुद्ध जयन्ती", "buddha purnima", "buddha"],
        "chhat": ["chhath", "छठ", "chhath puja", "chhat", "chhathh", "chaat"],
        "lhosar": ["lhosar", "ल्होसार", "sonam lhosar", "gyalpo lhosar", "tamu lhosar", "losar", "loosar"],
        "janai purnima": ["janai purnima", "जनै पूर्णिमा", "rakshya bandhan", "rakhi", "kwati punhi"],
        "eid": ["eid", "eid-al-fitr", "eid-ul-adha", "bakra eid", "ईदुल फित्र", "बकर ईद", "id"],
        "christmas": ["christmas", "xmas", "क्रिसमस", "x-mas"]
    ]
    
    private init() {
        loadKnowledgeBase()
    }
    
    private func loadKnowledgeBase() {
        guard let url = Bundle.main.url(forResource: "KnowledgeBase", withExtension: "json") ??
                        Bundle.main.url(forResource: "KnowledgeBase", withExtension: "json", subdirectory: "data") else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.knowledgeBase = try JSONDecoder().decode(KnowledgeBase.self, from: data)
        } catch {
            print("Error loading KnowledgeBase: \(error)")
        }
    }
    
    private let monthSynonyms: [Int: [String]] = [
        1: ["baishakh", "baisakh", "बैशाख", "vaishakh"],
        2: ["jestha", "jeth", "जेठ", "jaistha"],
        3: ["ashad", "ashar", "असार", "asad"],
        4: ["shrawan", "saun", "साउन", "shravan"],
        5: ["bhadra", "bhadau", "भदौ", "bhadrapad"],
        6: ["ashwin", "asoj", "असोज", "ashvin"],
        7: ["kartik", "कात्तिक", "kartick"],
        8: ["mangsir", "mansir", "marg", "मंसिर", "margashirsha"],
        9: ["poush", "paush", "push", "पुष", "pous"],
        10: ["magh", "माघ"],
        11: ["falgun", "phagun", "फागुन", "phalgun"],
        12: ["chaitra", "chait", "चैत", "chaita"]
    ]

    func generateResponse(for input: String, history: [ChatMessage] = []) -> String {
        let lowercasedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Context awareness: handle very short queries if they follow a previous query
        let words = lowercasedInput.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        
        // Handle "everything" or "all" requests
        if matches(input: lowercasedInput, keywords: ["everything", "all info", "all of it", "detailed info"]) {
            if let holidayName = lastHolidayQueried, let info = findHolidayInfo(named: holidayName) {
                return "**\(holidayName)**\n\n**Significance:** \(info.significance)\n\n**Traditions:** \(info.traditions)"
            }
        }

        // Month conversion check
        if words.count <= 3 {
            for (index, synonyms) in monthSynonyms {
                let found = synonyms.contains { synonym in
                    if lowercasedInput.contains(synonym) { return true }
                    return words.contains { word in fuzzyMatch(word, synonym, threshold: 0.8) }
                }
                
                if found {
                    let nepaliName = BhitteCalendar.shared.months[index - 1]
                    // If it's just the month name or "what is baishakh", return conversion
                    if words.count == 1 || lowercasedInput.contains("what") || lowercasedInput.contains("convert") || lowercasedInput.contains("meaning") {
                        let suffix = index == 1 ? "st" : index == 2 ? "nd" : index == 3 ? "rd" : "th"
                        let year = BhitteCalendar.shared.convertToBSDate(from: Date())?.year ?? 2081
                        return "**\(nepaliName)** is the \(index)\(suffix) month of the Nepali calendar. [DATE:\(year):\(index):1]"
                    }
                }
            }
        }

        if let holidayName = findHolidayName(in: lowercasedInput) {
            lastHolidayQueried = holidayName
            lastAction = .checkingHoliday
            return findNextHoliday(named: holidayName)
        }
        
        // Handle "what about..." or "and..." context
        if matches(input: lowercasedInput, keywords: ["what about", "how about", "and tomorrow", "and next"]) {
            if let holidayName = findHolidayName(in: lowercasedInput) {
                lastHolidayQueried = holidayName
                return findNextHoliday(named: holidayName)
            }
            
            // If they just say "and tomorrow?" or "and next week?"
            if matches(input: lowercasedInput, keywords: ["today", "todays"]) { return getTodaysDateInfo() }
            if matches(input: lowercasedInput, keywords: ["tomorrow", "tomorow"]) {
                if let tomorrow = BhitteCalendar.shared.addDays(to: BhitteCalendar.shared.convertToBSDate(from: Date())!, days: 1) {
                    return getInfoForBSDate(date: tomorrow)
                }
            }
        }

        switch conversationState {
        case .awaitingOffDays:
            return handleOffDaysResponse(for: lowercasedInput)
        case .awaitingLeaveDayCount:
            return handleLeaveCountResponse(for: lowercasedInput)
        case .awaitingDesiredBreakLength:
            return handleDesiredBreakLengthResponse(for: lowercasedInput)
        case .awaitingConversionType:
            return handleConversionTypeResponse(for: lowercasedInput)
        case .awaitingConversionDate:
            return handleConversionDateResponse(for: lowercasedInput)
        case .awaitingDaysBetweenRange:
            return handleDaysBetweenRangeResponse(for: lowercasedInput)
        case .awaitingDaysBetweenYear:
            return handleDaysBetweenYearResponse(for: lowercasedInput)
        case .awaitingHolidayDescription:
            return handleHolidayDescriptionResponse(for: lowercasedInput)
        case .idle:
            return handleIdleState(for: lowercasedInput)
        }
    }
    
    private func handleHolidayDescriptionResponse(for input: String) -> String {
        if matches(input: input, keywords: ["yes", "yep", "sure", "ok", "please", "why not", "yeah"]) {
            guard let holidayName = lastHolidayQueried, let info = findHolidayInfo(named: holidayName) else {
                resetConversation()
                return "I couldn't find the details for that holiday. What else can I help you with?"
            }
            resetConversation()
            return "**\(holidayName)**\n\n**Significance:** \(info.significance)\n\n**Traditions:** \(info.traditions)"
        } else {
            resetConversation()
            return "No problem! Let me know if you want to know about anything else."
        }
    }
    
    private func handleDaysBetweenRangeResponse(for input: String) -> String {
        let (start, end) = parseTwoDates(from: input)
        
        if let s = start, let e = end {
            self.daysBetweenStart = s
            self.daysBetweenEnd = e
            
            // Check if year was also provided in this message
            var year: Int?
            let yearMatches = input.lowercased().split(whereSeparator: { !$0.isNumber })
            for match in yearMatches {
                if match.count == 4, let y = Int(String(match)), y >= 2000 && y <= 2100 {
                    year = y
                    break
                }
            }
            
            if let y = year {
                self.daysBetweenYear = y
                let response = performDaysBetweenCalculation()
                resetConversation()
                return response
            }
            
            conversationState = .awaitingDaysBetweenYear
            return "Which year are we looking at? (e.g., 2083)"
        } else {
            return "Sure! Please provide the date range like 'Baishak 12 to Kartik 16' and I'll help you calculate the days."
        }
    }
    
    private func handleDaysBetweenYearResponse(for input: String) -> String {
        let numericInput = input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let year = Int(numericInput), year >= 2000 && year <= 2100 {
            self.daysBetweenYear = year
            let response = performDaysBetweenCalculation()
            resetConversation()
            return response
        } else {
            return "Please provide a valid year, like 2083."
        }
    }
    
    private func parseTwoDates(from input: String) -> (start: (month: Int, day: Int)?, end: (month: Int, day: Int)?) {
        let separators = [" to ", " and ", " - ", " from "]
        var parts: [String] = []
        
        for sep in separators {
            let p = input.lowercased().components(separatedBy: sep)
            if p.count == 2 {
                parts = p
                break
            }
        }
        
        guard parts.count == 2 else { return (nil, nil) }
        
        return (parseMonthDay(from: parts[0]), parseMonthDay(from: parts[1]))
    }
    
    private func parseMonthDay(from input: String) -> (month: Int, day: Int)? {
        let components = input.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        var foundDay: Int?
        var foundMonth: Int?
        
        for comp in components {
            let strComp = String(comp).lowercased()
            let cleanComp = strComp.trimmingCharacters(in: .decimalDigits.inverted)
            if let day = Int(cleanComp) {
                if day > 0 && day <= 32 {
                    foundDay = day
                }
            }
            
            for (index, synonyms) in monthSynonyms {
                if synonyms.contains(strComp) {
                    foundMonth = index
                    break
                }
                // Fuzzy match for months
                for synonym in synonyms {
                    if fuzzyMatch(strComp, synonym, threshold: 0.8) {
                        foundMonth = index
                        break
                    }
                }
                if foundMonth != nil { break }
            }
        }
        
        if let m = foundMonth, let d = foundDay {
            return (m, d)
        }
        return nil
    }
    
    private func performDaysBetweenCalculation() -> String {
        guard let start = daysBetweenStart, let end = daysBetweenEnd, let year = daysBetweenYear else {
            return "I'm sorry, I ran into an issue calculating those days. Could we try again?"
        }
        
        let startBS = BSDate(year: year, month: start.month, day: start.day)
        let endBS = BSDate(year: year, month: end.month, day: end.day)
        
        if let days = BhitteCalendar.shared.daysBetween(from: startBS, to: endBS) {
            let startMonthName = BhitteCalendar.shared.months[start.month - 1]
            let endMonthName = BhitteCalendar.shared.months[end.month - 1]
            let startDayDigits = BhitteCalendar.shared.toNepaliDigits(start.day)
            let endDayDigits = BhitteCalendar.shared.toNepaliDigits(end.day)
            let yearDigits = BhitteCalendar.shared.toNepaliDigits(year)
            
            let absDays = abs(days)
            return "There are **\(absDays) days** between \(startMonthName) \(startDayDigits) and \(endMonthName) \(endDayDigits), \(yearDigits) BS. [DATE:\(startBS.year):\(startBS.month):\(startBS.day)] [DATE:\(endBS.year):\(endBS.month):\(endBS.day)]"
        }
        
        return "I couldn't calculate the duration for those specific dates. Please make sure they are valid dates for the year \(year)."
    }
    
    private func handleIdleState(for input: String) -> String {
        if matches(input: input, keywords: ["hello", "hi", "namaste", "hey", "namaskar"]) {
            return "नमस्ते! I am your **Patro Assistant**. How can I help you with your schedule today? You can ask about holidays, calculate days, or plan a vacation."
        }
        
        if matches(input: input, keywords: ["what is your name", "who are you", "your name", "tell me your name", "what do I call you", "identity"]) {
            return "I am your **Patro Assistant**, your personal guide to the Nepali calendar. I don't have a human name, but I'm always here to help you track dates and holidays!"
        }
        
        if matches(input: input, keywords: ["what is your gender", "are you male or female", "boy or girl", "gender", "are you a man", "are you a woman"]) {
            return "I am an AI assistant, so I don't have a gender! I'm just a collection of smart rules and calendar data designed to help you stay organized."
        }
        
        if matches(input: input, keywords: ["how are you", "how are things", "are you okay", "you good", "how's it going"]) {
            return "I'm doing great! My circuits are humming and I'm ready to help you with the calendar. How are *you* doing today?"
        }
        
        if matches(input: input, keywords: ["what is this app", "about this app", "purpose", "why was this made"]) {
            return "**Bhitte Patro** was created to bring the traditional Nepali calendar into the digital age. I'm here to ensure you never miss a Tithi, holiday, or important event!"
        }
        
        if matches(input: input, keywords: ["who made you", "your creator", "who built you", "author", "developer"]) {
            return "I was built by **Pranab Kc** to help people stay connected with the Nepali calendar and culture. He's the brain, I'm the calendar expert!"
        }
        
        if matches(input: input, keywords: ["i love you", "you are great", "good job", "awesome", "smart assistant", "thank you", "thanks"]) {
            return "धन्यवाद (Thank you)! I'm blushing... or at least my code is glowing! I'm happy to be of service. Is there anything else you need help with?"
        }

        if matches(input: input, keywords: ["what is today", "today's date", "today date", "tell me about today", "what is this", "today", "whats today", "what's today"]) {
            lastAction = .checkingDate
            return getTodaysDateInfo()
        }
        
        if matches(input: input, keywords: ["what can you do", "help", "how to use", "what is this app", "about this app", "who are you", "features", "capabilities", "what is this", "what is this that all all", "show everything"]) {
            return "I am your **Patro Assistant**! I am a smart rule-based AI designed to help you with the Nepali calendar. I can:\n\n- **Holidays:** Ask \"When is Dashain?\" or \"Upcoming holidays?\"\n- **Date Info:** Ask \"What is today?\" or \"What's on 15th Jestha?\"\n- **Conversion:** Say \"Convert date\" to switch between BS and AD.\n- **Planning:** Say \"Plan a vacation\" to optimize your leave days.\n- **Calculations:** Ask \"How many days until Kartik 1?\"\n- **History:** Ask \"History of Bikram Sambat\" to learn more."
        }
        
        // Check for date range: "Jestha 12th to Kartik 13th" or "days between..."
        if input.contains(" to ") || input.contains(" and ") || input.contains("days between") || input.contains("how many days from") {
            let (start, end) = parseTwoDates(from: input)
            
            if let s = start, let e = end {
                // Extract a 4-digit year
                var year: Int?
                let yearMatches = input.lowercased().split(whereSeparator: { !$0.isNumber })
                for match in yearMatches {
                    if match.count == 4, let y = Int(String(match)), y >= 2000 && y <= 2100 {
                        year = y
                        break
                    }
                }
                
                if let y = year {
                    self.daysBetweenStart = s
                    self.daysBetweenEnd = e
                    self.daysBetweenYear = y
                    let response = performDaysBetweenCalculation()
                    resetConversation()
                    return response
                } else {
                    self.daysBetweenStart = s
                    self.daysBetweenEnd = e
                    conversationState = .awaitingDaysBetweenYear
                    return "Which year are we looking at? (e.g., 2083)"
                }
            } else if input.contains("days between") || input.contains("how many days from") {
                conversationState = .awaitingDaysBetweenRange
                return "Sure! Please let me know the dates you're interested in, like 'Baishak 12 to Kartik 16'."
            }
        }
        
        // Check for notes if no holiday was specifically named
        if let noteResult = findNextNoteMatch(matching: input) {
            lastAction = .checkingDate
            let daysDifference = BhitteCalendar.shared.daysBetween(from: BhitteCalendar.shared.convertToBSDate(from: Date())!, to: noteResult.date) ?? 0
            let dateTag = "[DATE:\(noteResult.date.year):\(noteResult.date.month):\(noteResult.date.day)]"
            
            if daysDifference == 0 {
                return "Today you have a note: **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference == 1 {
                return "Tomorrow is **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference == -1 {
                return "Yesterday you had a note: **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference > 0 {
                return "**\(noteResult.name)** is in **\(daysDifference) days**. \(dateTag)"
            } else {
                return "**\(noteResult.name)** was **\(abs(daysDifference)) days ago**. \(dateTag)"
            }
        }
        
        if matches(input: input, keywords: ["when is next holiday", "next public holiday", "upcoming holiday", "upcomming holiday", "next holiday", "any holiday", "holiday list", "holidays", "upcoming festivals", "festival list", "festivals", "public holidays"]) {
            lastAction = .checkingHoliday
            
            // Check if they want a list (plural)
            if input.contains("list") || input.contains("holidays") || input.contains("festivals") {
                return findUpcomingHolidays(count: 3)
            }
            
            return findNextHoliday(named: nil)
        }
        
        if input.contains("what is on") || input.contains("what's on") || input.contains("events on") || input.contains("tell me about") {
            lastAction = .checkingDate
            return getInfoForDate(input: input)
        }

        let durationKeywords = ["how long", "how many days", "days left", "days remaining", "until", "till", "how many days to"]
        if durationKeywords.contains(where: { input.contains($0) }) {
            lastAction = .calculatingDuration
            return calculateDaysUntil(input: input)
        }
        
        if matches(input: input, keywords: ["date conversion", "convert date", "conversion", "converter", "bs to ad", "ad to bs"]) {
            conversationState = .awaitingConversionType
            return "Sure! Would you like to convert **BS to AD** or **AD to BS**? CHAT_OPTIONS:[BS to AD,AD to BS]"
        }

        let vacationTriggers = [
            "plan a vacation",
            "plan vacation",
            "take leave",
            "take a break",
            "need a break",
            "vacation planning",
            "best time to leave",
            "when to take off",
            "exhausted",
            "tired of work",
            "holiday planning"
        ]
        
        if matches(input: input, keywords: vacationTriggers) {
            conversationState = .awaitingOffDays
            lastAction = .planningVacation
            return "I can help you plan a vacation. Saturday is always off. Which other day do you have off? CHAT_OPTIONS:[Friday,Sunday,Both,All days off]"
        }
        
        // Knowledge Base Triggers
        if matches(input: input, keywords: ["bikram sambat", "nepali calendar history", "why nepali calendar", "bs history", "who made bs", "origin of bs"]) {
            if let info = knowledgeBase?.calendarInfo {
                return "**\(info.name)**\n\n\(info.description)\n\n**History:** \(info.history)\n\n**Why it exists:** \(info.whyItExists)"
            }
        }
        
        if matches(input: input, keywords: ["what is tithi", "tithi definition", "explain tithi", "tithis", "lunar phase", "tithi explanation"]) {
            if let info = knowledgeBase?.tithiInfo {
                return "**What is Tithi?**\n\n\(info.definition)\n\n**Phases:**\n- *Shukla Paksha:* \(info.phases["shukla_paksha"] ?? "")\n- *Krishna Paksha:* \(info.phases["krishna_paksha"] ?? "")\n\n**Significance:** \(info.significance)"
            }
        }
        
        if matches(input: input, keywords: ["culture", "traditions", "tell me about nepal", "nepali culture", "nepali traditions", "nepal festivals"]) {
            return "Nepali culture is rich with festivals and traditions! You can ask me about major holidays like Dashain or Tihar, or about the Bikram Sambat calendar and Tithis."
        }
        
        // Fallback: if input looks like just a date (e.g. "17th baishakh")
        if parseDate(from: input) != nil {
            return getInfoForDate(input: input)
        }

        return "I'm not sure I understood. I am a rule-based assistant, so try using simpler phrases like:\n- \"When is Dashain?\"\n- \"Upcoming holidays?\"\n- \"How many days until 15th Jestha?\"\n- \"Help me plan a vacation\""
    }
    
    private func getTodaysDateInfo() -> String {
        guard let today = BhitteCalendar.shared.convertToBSDate(from: Date()) else {
            return "I'm having trouble getting today's date."
        }
        let monthName = BhitteCalendar.shared.months[today.month - 1]
        let nepaliDay = BhitteCalendar.shared.toNepaliDigits(today.day)
        let nepaliYear = BhitteCalendar.shared.toNepaliDigits(today.year)
        
        var response = "Today is **\(monthName) \(nepaliDay), \(nepaliYear)** [DATE:\(today.year):\(today.month):\(today.day)]."
        
        if let tithi = BhitteCalendar.shared.tithiText(year: today.year, month: today.month, day: today.day) {
            response += "\nTithi: **\(tithi)**."
        }
        if let holiday = BhitteCalendar.shared.holidayText(year: today.year, month: today.month, day: today.day) {
            response += "\n\nIt is **\(holiday)**!"
            lastHolidayQueried = holiday
            if findHolidayInfo(named: holiday) != nil {
                conversationState = .awaitingHolidayDescription
                response += "[SPLIT]Fancy learning more about **\(holiday)**? CHAT_OPTIONS:[Yes,No]"
            }
        }
        return response
    }
    
    private func getInfoForBSDate(date: BSDate) -> String {
        let monthName = BhitteCalendar.shared.months[date.month - 1]
        let nepaliDay = BhitteCalendar.shared.toNepaliDigits(date.day)
        var response = "**\(monthName) \(nepaliDay)** [DATE:\(date.year):\(date.month):\(date.day)]:"
        
        var detailsFound = false
        if let tithi = BhitteCalendar.shared.tithiText(year: date.year, month: date.month, day: date.day) {
            response += "\n- Tithi: **\(tithi)**"
            detailsFound = true
        }
        if let holiday = BhitteCalendar.shared.holidayText(year: date.year, month: date.month, day: date.day) {
            response += "\n- Holiday: **\(holiday)**"
            detailsFound = true
            lastHolidayQueried = holiday
            if findHolidayInfo(named: holiday) != nil {
                conversationState = .awaitingHolidayDescription
                response += "[SPLIT]Fancy learning more about **\(holiday)**? CHAT_OPTIONS:[Yes,No]"
                return response
            }
        }
        
        // Check for user notes
        let dateKey = "\(date.year)-\(String(format: "%02d", date.month))-\(String(format: "%02d", date.day))"
        if let note = PatroNoteManager.shared.notes[dateKey], !note.isEmpty {
            response += "\n- Note: **\(note)**"
            detailsFound = true
        }
        
        return detailsFound ? response : "No specific events for \(monthName) \(nepaliDay)."
    }
    
    private func getInfoForDate(input: String) -> String {
        guard let date = parseDate(from: input) else {
            return "I couldn't understand which date you're asking about. Please use a format like '18th Baishakh'."
        }
        
        let monthName = BhitteCalendar.shared.months[date.month - 1]
        let nepaliDay = BhitteCalendar.shared.toNepaliDigits(date.day)
        var response = "On **\(monthName) \(nepaliDay)** [DATE:\(date.year):\(date.month):\(date.day)]:"
        
        var detailsFound = false
        if let tithi = BhitteCalendar.shared.tithiText(year: date.year, month: date.month, day: date.day) {
            response += "\n- Tithi is **\(tithi)**."
            detailsFound = true
        }
        if let holiday = BhitteCalendar.shared.holidayText(year: date.year, month: date.month, day: date.day) {
            response += "\n- It's **\(holiday)**."
            detailsFound = true
            
            lastHolidayQueried = holiday
            if findHolidayInfo(named: holiday) != nil {
                conversationState = .awaitingHolidayDescription
                response += "[SPLIT]Fancy learning more about **\(holiday)**? CHAT_OPTIONS:[Yes,No]"
                return response
            }
        }
        
        return detailsFound ? response : "I don't have any specific events for \(monthName) \(nepaliDay)."
    }

    private func handleOffDaysResponse(for input: String) -> String {
        if matches(input: input, keywords: ["all", "none", "no work", "retired"]) {
            resetConversation()
            return "Since you have all days off, every day is a holiday for you! Honestly, the best day to plan your vacation is **today**. Enjoy your time!"
        }

        var offDays: [Int] = [6] // Saturday is always off
        
        if input.contains("both") || (input.contains("friday") && input.contains("sunday")) {
            offDays.append(5)
            offDays.append(0)
        } else if input.contains("friday") {
            offDays.append(5)
        } else if input.contains("sunday") {
            offDays.append(0)
        } else {
            return "Please choose between Friday, Sunday, Both, or All days off. CHAT_OPTIONS:[Friday,Sunday,Both,All days off]"
        }
        
        self.userOffDays = offDays
        conversationState = .awaitingLeaveDayCount
        
        return "Got it. And how many working days can you take off? CHAT_OPTIONS:[1 Day,2 Days,3 Days,4 Days]"
    }
    
    private func handleLeaveCountResponse(for input: String) -> String {
        let numericInput = input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let leaveDays = Int(numericInput), (0...10).contains(leaveDays) else {
            return "Please provide a valid number of days (0-10)."
        }
        
        self.leaveDaysToTake = leaveDays
        conversationState = .awaitingDesiredBreakLength
        
        return "Got it. How long of a break are you looking for? CHAT_OPTIONS:[3 days,4 days,5+ days,10+ days]"
    }
    
    private func handleDesiredBreakLengthResponse(for input: String) -> String {
        let numericInput = input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let desiredLength = Int(numericInput) else {
            return "Please select a break length. CHAT_OPTIONS:[3 days,4 days,5+ days,10+ days]"
        }
        
        let leaveDays = self.leaveDaysToTake ?? 0
        let result = calculateBestVacation(leaveDays: leaveDays, minTotalLength: desiredLength, searchDays: 40)
        
        let next40Message = "I searched for potential breaks within the next **40 days**."

        guard let bestOption = result else {
            // Stay in the current state to let them try a different break length
            return "\(next40Message)\n\nSorry, I couldn't find a **\(desiredLength)-day** break using only **\(leaveDays) leave days**. Would you like to look for a different length of break? CHAT_OPTIONS:[3 days,4 days,5+ days,10+ days]"
        }
        
        let (leaveDates, fullBlock) = bestOption
        let totalDays = fullBlock.count
        
        var response = "\(next40Message)\n\n"
        
        if leaveDates.isEmpty {
            response += "Great news! You can get a **\(totalDays)-day** break without taking any leave days!\n\nYour break will be:\n"
        } else {
            let leaveDateStrings = leaveDates.map { date in
                let month = BhitteCalendar.shared.months[date.month - 1]
                let day = BhitteCalendar.shared.toNepaliDigits(date.day)
                return "**\(month) \(day)**"
            }.joined(separator: ", ")
            
            response += "To get a **\(totalDays)-day** break, you should take leave on \(leaveDateStrings).\n\nYour full break will be:\n"
        }
        
        // Reset only on success
        resetConversation()
        
        // Sort full block by date
        let sortedBlock = fullBlock.sorted { d1, d2 in
            if d1.year != d2.year { return d1.year < d2.year }
            if d1.month != d2.month { return d1.month < d2.month }
            return d1.day < d2.day
        }
        
        for date in sortedBlock {
            response += "[DATE:\(date.year):\(date.month):\(date.day)] "
        }
        
        return response
    }

    private func calculateBestVacation(leaveDays: Int, minTotalLength: Int, searchDays: Int) -> (leaveDates: [BSDate], fullBlock: [BSDate])? {
        guard let offDays = userOffDays, let today = BhitteCalendar.shared.convertToBSDate(from: Date()) else { return nil }

        var bestOption: (leaveDates: [BSDate], fullBlock: [BSDate])?

        // Search for a vacation block that meets minTotalLength within searchDays
        for i in 1...searchDays {
            guard let startDate = BhitteCalendar.shared.addDays(to: today, days: i) else { continue }
            
            // For each starting day, try to build a block using up to 'leaveDays'
            var cursorDate = startDate
            var currentLeaveUsed = 0
            var currentBlock: [BSDate] = []
            var leaveDatesUsed: [BSDate] = []
            
            // Expand forward until we hit a workday we can't take leave for
            while true {
                let isWork = isWorkDay(date: cursorDate, offDays: offDays)
                if isWork {
                    if currentLeaveUsed < leaveDays {
                        currentLeaveUsed += 1
                        leaveDatesUsed.append(cursorDate)
                        currentBlock.append(cursorDate)
                    } else {
                        // Out of leave days
                        break
                    }
                } else {
                    // Holiday or Weekend
                    currentBlock.append(cursorDate)
                }
                
                guard let nextDay = BhitteCalendar.shared.addDays(to: cursorDate, days: 1) else { break }
                cursorDate = nextDay
                
                // Safety: don't look too far ahead for a single block
                if currentBlock.count > 45 { break }
            }
            
            // Also expand backward from startDate to catch any adjacent non-work days
            var backDate = startDate
            while true {
                guard let prevDay = BhitteCalendar.shared.addDays(to: backDate, days: -1) else { break }
                if !isWorkDay(date: prevDay, offDays: offDays) {
                    currentBlock.insert(prevDay, at: 0)
                    backDate = prevDay
                } else {
                    break
                }
            }
            
            if currentBlock.count >= minTotalLength {
                // If we found multiple, prefer the one with the MOST total days
                if bestOption == nil || currentBlock.count > bestOption!.fullBlock.count {
                    bestOption = (leaveDatesUsed, currentBlock)
                }
            }
        }

        return bestOption
    }
    
    private func isWorkDay(date: BSDate, offDays: [Int]) -> Bool {
        if BhitteCalendar.shared.holidayText(year: date.year, month: date.month, day: date.day) != nil {
            return false
        }
        guard let adDate = BhitteCalendar.shared.convertToADDate(from: date) else { return true }
        let weekday = Calendar.current.component(.weekday, from: adDate) - 1 // 0=Sun, 6=Sat
        
        if weekday == 6 { return false } // Saturday is ALWAYS a holiday
        
        return !offDays.contains(weekday)
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count + 1)
        var last = [Int](0...s2.count)

        for (i, char1) in s1.enumerated() {
            var cur = [i + 1] + empty.dropFirst()
            for (j, char2) in s2.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last!
    }

    func fuzzyMatch(_ s1: String, _ s2: String, threshold: Double = 0.75) -> Bool {
        let str1 = s1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = s2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if str1 == str2 { return true }
        if str1.isEmpty || str2.isEmpty { return false }
        
        // Handle very short strings more strictly
        let actualThreshold = str2.count <= 4 ? 0.85 : threshold
        
        let distance = Double(levenshteinDistance(str1, str2))
        let maxLength = Double(max(str1.count, str2.count))
        let similarity = 1.0 - (distance / maxLength)
        
        return similarity >= actualThreshold
    }

    private func findHolidayInfo(named name: String) -> HolidayInfo? {
        // 1. Try to find the English key for this name (it might be a Nepali synonym from the calendar)
        var canonicalName = name.lowercased()
        for (englishKey, synonyms) in holidaySynonyms {
            if synonyms.contains(where: { $0.lowercased() == canonicalName || canonicalName.contains($0.lowercased()) }) {
                canonicalName = englishKey
                break
            }
        }
        
        return knowledgeBase?.holidays.first { info in
            let lowerName = info.name.lowercased()
            if lowerName == canonicalName || canonicalName.contains(lowerName) { return true }
            return fuzzyMatch(canonicalName, lowerName)
        }
    }

    private func findHolidayName(in input: String) -> String? {
        let words = input.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        
        // 1. Try exact or contains match first (highest priority)
        for (englishName, synonyms) in holidaySynonyms {
            for synonym in synonyms {
                if synonym.count <= 4 {
                    if words.contains(synonym) { return englishName }
                } else if input.lowercased().contains(synonym.lowercased()) || words.contains(synonym.lowercased()) {
                    return englishName
                }
            }
        }
        
        // 2. Try fuzzy match on words with a slightly more relaxed threshold for typos
        for (englishName, synonyms) in holidaySynonyms {
            for synonym in synonyms {
                for word in words {
                    if fuzzyMatch(word, synonym, threshold: 0.7) { // Lowered from 0.75
                        return englishName
                    }
                }
            }
        }
        
        return nil
    }

    private func findNextHoliday(named holidayName: String?) -> String {
        let today = BhitteCalendar.shared.convertToBSDate(from: Date())!
        
        let synonyms: [String]
        if let name = holidayName {
            synonyms = holidaySynonyms[name] ?? [name]
        } else {
            synonyms = []
        }

        if let result = BhitteCalendar.shared.findNextHoliday(matching: synonyms.isEmpty ? nil : synonyms) {
            let daysRemaining = BhitteCalendar.shared.daysBetween(from: today, to: result.date) ?? 0
            
            let dateTag = "[DATE:\(result.date.year):\(result.date.month):\(result.date.day)]"
            
            var response = ""
            if daysRemaining == 0 {
                response = "Today is **\(result.name)**! \(dateTag)"
            } else if daysRemaining == 1 {
                response = "**\(result.name)** is tomorrow! \(dateTag)"
            } else {
                response = "**\(result.name)** is in **\(daysRemaining) days**. \(dateTag)"
            }
            
            lastHolidayQueried = result.name
            
            if findHolidayInfo(named: result.name) != nil {
                conversationState = .awaitingHolidayDescription
                return response + "[SPLIT]Fancy learning more about **\(result.name)**? CHAT_OPTIONS:[Yes,No]"
            }
            
            return response
        } else {
            let display = holidayName ?? "any holiday"
            return "I couldn't find \(display) in the upcoming months."
        }
    }
    
    private func findUpcomingHolidays(count: Int) -> String {
        let today = BhitteCalendar.shared.convertToBSDate(from: Date())!
        var upcoming: [(name: String, date: BSDate, days: Int)] = []
        var lastDate = today
        
        for _ in 1...count {
            if let result = BhitteCalendar.shared.findNextHoliday(matching: nil, startingFrom: BhitteCalendar.shared.addDays(to: lastDate, days: 1)) {
                let days = BhitteCalendar.shared.daysBetween(from: today, to: result.date) ?? 0
                upcoming.append((result.name, result.date, days))
                lastDate = result.date
            }
        }
        
        if upcoming.isEmpty { return "I couldn't find any upcoming holidays." }
        
        var response = "Here are the next **\(upcoming.count)** holidays:\n\n"
        for holiday in upcoming {
            let dateTag = "[DATE:\(holiday.date.year):\(holiday.date.month):\(holiday.date.day)]"
            response += "- **\(holiday.name)**: \(dateTag) (in \(holiday.days) days)\n"
        }
        return response
    }
    
    private func parseDate(from input: String) -> BSDate? {
        let components = input.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        
        var foundDay: Int?
        var foundMonth: Int?
        
        for comp in components {
            let strComp = String(comp)
            let cleanComp = strComp.trimmingCharacters(in: .decimalDigits.inverted)
            if let day = Int(cleanComp) {
                foundDay = day
            }
            
            // Check month synonyms
            for (index, synonyms) in monthSynonyms {
                if synonyms.contains(strComp) {
                    foundMonth = index
                    break
                }
                // Fuzzy match for months
                for synonym in synonyms {
                    if fuzzyMatch(strComp, synonym, threshold: 0.8) {
                        foundMonth = index
                        break
                    }
                }
                if foundMonth != nil { break }
            }
        }
        
        if let m = foundMonth {
            let year = BhitteCalendar.shared.convertToBSDate(from: Date())?.year ?? 2081
            return BSDate(year: year, month: m, day: foundDay ?? 1)
        }
        return nil
    }

    private func calculateDaysUntil(input: String) -> String {
        if let targetDate = parseDate(from: input) {
            if let today = BhitteCalendar.shared.convertToBSDate(from: Date()) {
                var finalTargetDate = targetDate
                if (targetDate.month < today.month || (targetDate.month == today.month && targetDate.day < today.day)) {
                    finalTargetDate.year += 1
                }
                if let days = BhitteCalendar.shared.daysBetween(from: today, to: finalTargetDate) {
                    let monthName = BhitteCalendar.shared.months[targetDate.month - 1]
                    let dateTag = "[DATE:\(finalTargetDate.year):\(finalTargetDate.month):\(finalTargetDate.day)]"
                    return "There are **\(days) days** until \(monthName) \(targetDate.day). \(dateTag)"
                }
            }
        }
        
        // Fallback: check notes
        if let noteResult = findNextNoteMatch(matching: input) {
            let daysDifference = BhitteCalendar.shared.daysBetween(from: BhitteCalendar.shared.convertToBSDate(from: Date())!, to: noteResult.date) ?? 0
            let dateTag = "[DATE:\(noteResult.date.year):\(noteResult.date.month):\(noteResult.date.day)]"
            
            if daysDifference == 0 {
                return "Today you have a note: **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference == 1 {
                return "Tomorrow is **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference == -1 {
                return "Yesterday you had a note: **\(noteResult.name)**. \(dateTag)"
            } else if daysDifference > 0 {
                return "**\(noteResult.name)** is in **\(daysDifference) days**. \(dateTag)"
            } else {
                return "**\(noteResult.name)** was **\(abs(daysDifference)) days ago**. \(dateTag)"
            }
        }
        
        return "I couldn't understand that date or find a matching note."
    }

    private func matches(input: String, keywords: [String]) -> Bool {
        let words = input.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        return keywords.contains { keyword in
            if input.lowercased().contains(keyword.lowercased()) { return true }
            
            // For single-word keywords, try fuzzy matching against each word
            if !keyword.contains(" ") {
                return words.contains { word in fuzzyMatch(word, keyword) }
            }
            
            // For phrases, check if all words in keyword exist in input
            let kwWords = keyword.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
            return kwWords.allSatisfy { kw in input.lowercased().contains(kw) }
        }
    }
    
    private func handleConversionTypeResponse(for input: String) -> String {
        if input.contains("bs to ad") {
            conversionType = .bsToAD
            conversationState = .awaitingConversionDate
            return "Please provide the BS date in **yyyy-mm-dd** format (e.g., 2081-01-01)."
        } else if input.contains("ad to bs") {
            conversionType = .adToBS
            conversationState = .awaitingConversionDate
            return "Please provide the AD date in **yyyy-mm-dd** format (e.g., 2024-04-13)."
        } else {
            return "Please select a conversion type. CHAT_OPTIONS:[BS to AD,AD to BS]"
        }
    }
    
    private func handleConversionDateResponse(for input: String) -> String {
        let components = input.components(separatedBy: CharacterSet(charactersIn: "-/."))
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return "Invalid format. Please use **yyyy-mm-dd**."
        }
        
        let type = conversionType
        resetConversation()
        
        if type == .bsToAD {
            let bsDate = BSDate(year: year, month: month, day: day)
            if let adDate = BhitteCalendar.shared.convertToADDate(from: bsDate) {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return "The AD equivalent of **\(year)-\(month)-\(day) BS** is **\(formatter.string(from: adDate))**."
            }
        } else {
            // AD to BS
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            if let adDate = Calendar.current.date(from: dateComponents),
               let bsDate = BhitteCalendar.shared.convertToBSDate(from: adDate) {
                let monthName = BhitteCalendar.shared.months[bsDate.month - 1]
                let nepaliDay = BhitteCalendar.shared.toNepaliDigits(bsDate.day)
                let nepaliYear = BhitteCalendar.shared.toNepaliDigits(bsDate.year)
                return "The BS equivalent of **\(year)-\(month)-\(day) AD** is **\(monthName) \(nepaliDay), \(nepaliYear)** [DATE:\(bsDate.year):\(bsDate.month):\(bsDate.day)]."
            }
        }
        
        return "I couldn't convert that date. Please make sure it's a valid date."
    }

    private func resetConversation() {
        conversationState = .idle
        userOffDays = nil
        leaveDaysToTake = nil
        conversionType = nil
        daysBetweenStart = nil
        daysBetweenEnd = nil
        daysBetweenYear = nil
    }

    private func findNextNoteMatch(matching input: String) -> (name: String, date: BSDate)? {
        let today = BhitteCalendar.shared.convertToBSDate(from: Date())!
        let notes = PatroNoteManager.shared.notes
        let inputLower = input.lowercased()
        let inputWords = inputLower.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)

        // Search outward from today (0, 1, -1, 2, -2...) up to 365 days
        for i in 0...365 {
            let offsets = i == 0 ? [0] : [i, -i]
            for offset in offsets {
                if let date = BhitteCalendar.shared.addDays(to: today, days: offset) {
                    let dateKey = "\(date.year)-\(String(format: "%02d", date.month))-\(String(format: "%02d", date.day))"
                    if let noteContent = notes[dateKey], !noteContent.isEmpty {
                        let noteContentLower = noteContent.lowercased()
                        
                        // Simple contains check
                        if inputLower.contains(noteContentLower) || noteContentLower.contains(inputLower) {
                            return (noteContent, date)
                        }
                        
                        // Word by word fuzzy check
                        let noteWords = noteContentLower.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
                        
                        for iWord in inputWords {
                            if iWord.count <= 2 { continue }
                            for nWord in noteWords {
                                if nWord.count <= 2 { continue }
                                if fuzzyMatch(iWord, nWord) {
                                    return (noteContent, date)
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
