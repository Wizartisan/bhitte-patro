import SwiftUI

struct NoteEditorView: View {
    let date: BSDate
    @State private var content: String
    @FocusState private var isFocused: Bool
    @EnvironmentObject var noteManager: PatroNoteManager
    var onDismiss: () -> Void
    
    private var dateString: String {
        "\(date.year)-\(String(format: "%02d", date.month))-\(String(format: "%02d", date.day))"
    }
    
    private var displayDate: String {
        "\(NepaliCalendar.shared.months[date.month - 1]) \(NepaliCalendar.shared.toNepaliDigits(date.day))"
    }
    
    init(date: BSDate, noteManager: PatroNoteManager, onDismiss: @escaping () -> Void) {
        self.date = date
        _content = State(initialValue: noteManager.notes["\(date.year)-\(String(format: "%02d", date.month))-\(String(format: "%02d", date.day))"] ?? "")
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with explicit Save/Cancel
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayDate)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(NepaliCalendar.shared.toNepaliDigits(date.year))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    noteManager.saveNote(id: dateString, content: content)
                    onDismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction) // Save on Enter
            }
            .padding(.bottom, 20)
            
            // Writing Area
            VStack(alignment: .trailing, spacing: 4) {
                TextEditor(text: $content)
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(4)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { _, newValue in
                        if newValue.count > 100 {
                            content = String(newValue.prefix(100))
                        }
                    }
                
                Text("\(content.count)/100")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(content.count >= 100 ? .red : .secondary)
            }
        }
        .padding(20)
        .onAppear {
            // Delay focus slightly for a smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}
