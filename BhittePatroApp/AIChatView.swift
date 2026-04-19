//
//  AIChatView.swift
//  BhittePatroApp
//
//  Created by Pranab Kc on 18/04/2026.
//

import SwiftUI

// MARK: - Persistence
struct ChatStorage {
    private static let historyKey = "AIChatHistory"
    private static let timestampKey = "AIChatLastTimestamp"
    private static let oneHour: TimeInterval = 3600
    
    struct StoredMessage: Codable {
        let text: String
        let options: [String]
        let isUser: Bool
    }
    
    static func save(_ messages: [ChatMessage]) {
        let stored = messages.map { StoredMessage(text: $0.text, options: $0.options, isUser: $0.isUser) }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: historyKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
        }
    }
    
    static func load() -> [ChatMessage] {
        let lastTimestamp = UserDefaults.standard.double(forKey: timestampKey)
        let now = Date().timeIntervalSince1970
        
        // Clear history if older than 1 hour
        if lastTimestamp > 0 && (now - lastTimestamp > oneHour) {
            clear()
            return []
        }
        
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let stored = try? JSONDecoder().decode([StoredMessage].self, from: data) else {
            return []
        }
        
        return stored.map { ChatMessage(text: $0.text, options: $0.options, isUser: $0.isUser) }
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }
}

// MARK: - Models and Helper Views
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    var options: [String]
    let isUser: Bool
    
    init(text: String, options: [String] = [], isUser: Bool) {
        self.text = text
        self.options = options
        self.isUser = isUser
    }
}

enum MessagePart: Hashable {
    case text(String)
    case date(BSDate)
}

struct ChatBubble: View {
    let message: ChatMessage
    let onOptionTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            MessageContentView(text: message.text, isUser: message.isUser)
            
            if !message.options.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(message.options, id: \.self) { option in
                            Button(action: { onOptionTapped(option) }) {
                                Text(option)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 12)
    }
}

struct MessageContentView: View {
    let text: String
    let isUser: Bool
    
    var parts: [MessagePart] {
        parseMessage(text)
    }
    
    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
            // Group text parts and show them
            let textContent = parts.compactMap { part -> String? in
                if case .text(let content) = part { return content }
                return nil
            }.joined()
            
            if !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(parseMarkdown(textContent))
                    .font(.system(size: 13))
                    .foregroundStyle(isUser ? .white : .primary)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .lineSpacing(2)
            }
            
            // Show date parts on a new row
            let dateParts = parts.compactMap { part -> BSDate? in
                if case .date(let date) = part { return date }
                return nil
            }
            
            if !dateParts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dateParts, id: \.self) { date in
                            DateRectangleView(date: date)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isUser ? 
            Color.red.opacity(0.85) : 
            Color(nsColor: .windowBackgroundColor).opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isUser ? .clear : Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private func parseMarkdown(_ input: String) -> AttributedString {
        do {
            let attr = try AttributedString(markdown: input)
            return attr
        } catch {
            return AttributedString(input)
        }
    }
    
    private func parseMessage(_ input: String) -> [MessagePart] {
        var result: [MessagePart] = []
        let pattern = "\\[DATE:(\\d+):(\\d+):(\\d+)\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(input)]
        }
        
        let nsString = input as NSString
        var lastIndex = 0
        
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            // Text before match
            let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
            if textRange.length > 0 {
                let text = nsString.substring(with: textRange)
                result.append(.text(text))
            }
            
            // The match
            if let year = Int(nsString.substring(with: match.range(at: 1))),
               let month = Int(nsString.substring(with: match.range(at: 2))),
               let day = Int(nsString.substring(with: match.range(at: 3))) {
                result.append(.date(BSDate(year: year, month: month, day: day)))
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Remaining text
        if lastIndex < nsString.length {
            let text = nsString.substring(from: lastIndex)
            result.append(.text(text))
        }
        
        return result.isEmpty ? [.text(input)] : result
    }
}

struct DateRectangleView: View {
    let date: BSDate
    
    private var isHoliday: Bool {
        NepaliCalendar.shared.holidayText(year: date.year, month: date.month, day: date.day) != nil ||
        isSaturday
    }
    
    private var isSaturday: Bool {
        guard let ad = NepaliCalendar.shared.convertToADDate(from: date) else { return false }
        return Calendar.current.component(.weekday, from: ad) == 7
    }
    
    private var monthName: String {
        NepaliCalendar.shared.months[date.month - 1]
    }
    
    private var nepaliDay: String {
        NepaliCalendar.shared.toNepaliDigits(date.day)
    }
    
    private var englishDay: String {
        guard let ad = NepaliCalendar.shared.convertToADDate(from: date) else {
            return ""
        }
        let calendarDay = Calendar(identifier: .gregorian).component(.day, from: ad)
        return String(calendarDay)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(monthName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHoliday ? Color.red : Color.secondary.opacity(0.15))
                
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    Text(nepaliDay)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isHoliday ? .white : .primary)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer(minLength: 0)
                        if !englishDay.isEmpty {
                            Text(englishDay)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isHoliday ? .white.opacity(0.8) : .secondary)
                                .padding(.trailing, 4)
                                .padding(.bottom, 2)
                        }
                    }
                }
            }
            .frame(width: 46, height: 46)
        }
    }
}

// MARK: - AI Chat View
struct AIChatView: View {
    @State private var messages: [ChatMessage]
    @State private var inputText: String = ""
    var onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        let history = ChatStorage.load()
        if history.isEmpty {
            _messages = State(initialValue: [
                .init(text: "नमस्ते! How can I assist you with the calendar today?", isUser: false)
            ])
        } else {
            _messages = State(initialValue: history)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider().opacity(0.4)
            
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 18) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, onOptionTapped: handleOption)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 20)
                    .onChange(of: messages.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
            
            inputBar
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.secondary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Calendar AI")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                    Text("Always helpful")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                ChatStorage.clear()
                withAnimation {
                    messages = [.init(text: "नमस्ते! How can I assist you with the calendar today?", isUser: false)]
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear History")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            HStack(spacing: 10) {
                TextField("Ask about holidays, dates or plans...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                    .onSubmit {
                        if !inputText.isEmpty {
                            sendMessage(text: inputText)
                        }
                    }
                
                Button(action: { sendMessage(text: inputText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.3) : Color.red)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .withinWindow))
        }
    }
    
    private func handleOption(option: String) {
        sendMessage(text: option, isSilent: true)
    }
    
    private func sendMessage(text: String, isSilent: Bool = false) {
        guard !text.isEmpty else { return }
        
        if !isSilent {
            let userMessage = ChatMessage(text: text, isUser: true)
            messages.append(userMessage)
        }
        
        inputText = ""
        
        // Disable options on previous messages
        if messages.count > 1 {
            for i in 0..<(messages.count - 1) {
                messages[i].options = []
            }
        }
        
        // Generate AI response
        let aiResponseRaw = AIResponseGenerator.shared.generateResponse(for: text, history: messages)
        
        var options: [String] = []
        var responseText = aiResponseRaw
        
        if let range = aiResponseRaw.range(of: "CHAT_OPTIONS:") {
            responseText = String(aiResponseRaw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let optionsString = String(aiResponseRaw[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            options = optionsString.components(separatedBy: ",")
        }
        
        let aiResponse = ChatMessage(text: responseText, options: options, isUser: false)
        messages.append(aiResponse)
        
        // Persist history
        ChatStorage.save(messages)
    }
}
