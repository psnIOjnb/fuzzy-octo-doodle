//
//  DailyNoteCard.swift
//  DayPage
//
//  One Markdown note per day. The editor grows with its content (a hidden
//  copy of the text does the measuring) so the whole page scrolls as one
//  document instead of trapping a scroll view inside a scroll view.
//
//  Edits are written back to SwiftData on a short debounce; the note row is
//  only created once something has actually been typed.
//

import SwiftUI
import SwiftData

@MainActor
struct DailyNoteCard: View {

    let day: Date
    let note: DailyNote?
    /// Markdown for the whole page, used by the share button.
    let shareText: () -> String

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var text = ""
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isEditing: Bool

    private let placeholder = "What happened today?"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(symbol: "square.and.pencil", title: "Daily Note") {
                IconButton(
                    systemName: settings.renderMarkdown ? "textformat" : "textformat.alt",
                    accessibilityLabel: settings.renderMarkdown ? "Edit Markdown" : "Preview Markdown"
                ) {
                    isEditing = false
                    withAnimation(.snappy(duration: 0.2)) { settings.renderMarkdown.toggle() }
                }

                ShareLink(item: shareText(), preview: SharePreview(DayExporter.fileName(for: day))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                        }
                }
                .accessibilityLabel("Share this day")
            }

            Group {
                if settings.renderMarkdown {
                    preview
                } else {
                    editor
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.inset)
            }

            footer
        }
        .card()
        .task(id: day) {
            await adoptStoredText()
        }
        .onChange(of: text) { _, newValue in
            scheduleSave(newValue)
        }
        .onDisappear {
            saveTask?.cancel()
            commit(text)
        }
    }

    // MARK: Editing

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Invisible twin: sets the height the TextEditor should take.
            Text(text.isEmpty ? placeholder : text)
                .font(Theme.note)
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hidden()
                .accessibilityHidden(true)

            if text.isEmpty {
                Text(placeholder)
                    .font(Theme.note)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(Theme.note)
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .focused($isEditing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 120, alignment: .topLeading)
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(placeholder)
                .font(Theme.note)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        } else {
            MarkdownText(text)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(wordCountLabel)
            Spacer()
            if let updated = note?.updatedAt, !(note?.isEmpty ?? true) {
                Text("Edited \(Formatters.time.string(from: updated))")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.textTertiary)
    }

    private var wordCountLabel: String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return words == 1 ? "1 word" : "\(words) words"
    }

    // MARK: Persistence

    /// New day on screen: drop any pending write and adopt its stored text.
    private func adoptStoredText() async {
        saveTask?.cancel()
        text = note?.text ?? ""
    }

    /// Debounced so a burst of typing produces one write.
    private func scheduleSave(_ value: String) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            commit(value)
        }
    }

    private func commit(_ value: String) {
        if let note {
            guard note.text != value else { return }
            note.text = value
            note.updatedAt = .now
        } else {
            // Don't litter the store with empty notes for days just browsed.
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            context.insert(DailyNote(day: day, text: value))
        }
        try? context.save()
    }
}

// MARK: - Markdown rendering

private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let style: MarkdownBlockStyle
    let attributed: AttributedString
}

private enum MarkdownBlockStyle {
    case paragraph
    case heading(Int)
    case bullet
    case numbered(Int)
    case quote
}


/// Small block-level Markdown renderer: headings, bullets, quotes and
/// paragraphs, with inline styling handled by `AttributedString`.
/// Enough for a daily note, and no third-party dependency.
@MainActor
struct MarkdownText: View {

    private let blocks: [MarkdownBlock]

    init(_ raw: String) {
        blocks = MarkdownText.parse(raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block.style {
                case .heading(let level):
                    Text(block.attributed)
                        .font(.system(size: level == 1 ? 22 : (level == 2 ? 19 : 17), design: .serif).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, block.id == blocks.first?.id ? 0 : 4)

                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(Theme.note).foregroundStyle(Theme.textSecondary)
                        Text(block.attributed).font(Theme.note).foregroundStyle(Theme.textPrimary)
                    }

                case .numbered(let number):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(number).").font(Theme.note).foregroundStyle(Theme.textSecondary)
                        Text(block.attributed).font(Theme.note).foregroundStyle(Theme.textPrimary)
                    }

                case .quote:
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle().fill(Theme.accent.opacity(0.5)).frame(width: 3)
                        Text(block.attributed).font(Theme.note).foregroundStyle(Theme.textSecondary)
                    }

                case .paragraph:
                    Text(block.attributed)
                        .font(Theme.note)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    // MARK: Parsing

    private static func parse(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(MarkdownBlock(style: .paragraph, attributed: inline(paragraph.joined(separator: " "))))
            paragraph.removeAll()
        }

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let hashes = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                flushParagraph()
                let level = line.prefix { $0 == "#" }.count
                let content = String(line[hashes.upperBound...])
                blocks.append(MarkdownBlock(style: .heading(min(level, 3)), attributed: inline(content)))
                continue
            }

            if let marker = line.range(of: #"^([-*+])\s+"#, options: .regularExpression) {
                flushParagraph()
                blocks.append(MarkdownBlock(style: .bullet, attributed: inline(String(line[marker.upperBound...]))))
                continue
            }

            if let marker = line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                flushParagraph()
                let number = Int(line[line.startIndex..<marker.upperBound]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " .)"))) ?? 1
                blocks.append(MarkdownBlock(style: .numbered(number), attributed: inline(String(line[marker.upperBound...]))))
                continue
            }

            if let marker = line.range(of: #"^>\s?"#, options: .regularExpression) {
                flushParagraph()
                blocks.append(MarkdownBlock(style: .quote, attributed: inline(String(line[marker.upperBound...]))))
                continue
            }

            paragraph.append(line)
        }
        flushParagraph()

        return blocks
    }

    /// Inline emphasis, code spans and links via Foundation's own parser.
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
