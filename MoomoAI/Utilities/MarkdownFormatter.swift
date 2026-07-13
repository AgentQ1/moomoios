//
//  MarkdownFormatter.swift
//  MoomoAI
//
//  The single Markdown rendering system for assistant messages.
//
//  Parsing is delegated to Foundation's cmark-based parser
//  (AttributedString(markdown:) with .full syntax), which correctly handles
//  the edge cases a hand-rolled scanner gets wrong: nested emphasis, escapes,
//  unterminated markers, indentation-based list nesting. Block structure
//  (headings, lists, code blocks, quotes) arrives as PresentationIntent
//  attributes; MarkdownFormatter regroups the parsed runs into blocks and
//  MarkdownText lays them out as native SwiftUI views — so raw markers
//  (**, ###, backticks, "- ") can never leak into the rendered output.
//

import SwiftUI

// MARK: - Block model

/// One visual block of a rendered assistant message.
struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case paragraph
        case heading(level: Int)
        /// `depth` is 0-based nesting; `marker` is the rendered prefix ("•", "3.").
        case listItem(depth: Int, marker: String)
        case codeBlock(language: String?)
        case blockQuote
        case thematicBreak
    }

    let id: Int
    let kind: Kind
    var text: AttributedString
}

// MARK: - Parser

enum MarkdownFormatter {

    /// Parsed results keyed by source text. Message content is immutable and
    /// responses arrive in one piece (no token streaming), so each message is
    /// parsed exactly once; scroll passes re-evaluating row bodies hit the
    /// cache instead of re-running the parser.
    private final class BlocksBox {
        let value: [MarkdownBlock]
        init(_ value: [MarkdownBlock]) { self.value = value }
    }

    private static let cache: NSCache<NSString, BlocksBox> = {
        let cache = NSCache<NSString, BlocksBox>()
        cache.countLimit = 300
        return cache
    }()

    static func blocks(for text: String) -> [MarkdownBlock] {
        let key = text as NSString
        if let hit = cache.object(forKey: key) { return hit.value }
        let value = parse(text)
        cache.setObject(BlocksBox(value), forKey: key)
        return value
    }

    private static func parse(_ text: String) -> [MarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: text, options: options),
              !parsed.characters.isEmpty else {
            // Unparseable input degrades to plain text — never to raw markers
            // mixed with broken styling.
            return [MarkdownBlock(id: 0, kind: .paragraph, text: AttributedString(text))]
        }

        var blocks: [MarkdownBlock] = []
        var lastIdentity: [Int]?
        var lastTableColumn: Int?

        for run in parsed.runs {
            let intent = run.presentationIntent

            // Author line breaks inside a paragraph (soft or hard) must stay
            // visible line breaks — cmark's "soft break becomes a space" would
            // collapse the short stacked lines chat models emit.
            let slice: AttributedString
            if let inline = run.inlinePresentationIntent,
               inline.contains(.softBreak) || inline.contains(.lineBreak) {
                slice = AttributedString("\n")
            } else {
                slice = AttributedString(parsed[run.range])
            }

            let identity = groupIdentity(intent)
            let column = tableColumn(intent)
            if identity == lastIdentity, !blocks.isEmpty {
                // Same block: e.g. the plain + bold runs of one paragraph, or
                // the cells of one table row (separated for readability —
                // tables degrade to one plain line per row).
                if let column, let lastColumn = lastTableColumn, column != lastColumn {
                    blocks[blocks.count - 1].text.append(AttributedString("   "))
                }
                blocks[blocks.count - 1].text.append(slice)
            } else {
                blocks.append(MarkdownBlock(id: blocks.count, kind: kind(of: intent), text: slice))
                lastIdentity = identity
            }
            lastTableColumn = column
        }

        for index in blocks.indices {
            if case .codeBlock = blocks[index].kind {
                blocks[index].text = trimmingTrailingNewlines(blocks[index].text)
            } else {
                styleInlineCode(&blocks[index].text)
            }
        }
        return blocks
    }

    /// The identity path that defines "same visual block". Table cells are
    /// excluded so all cells of a row merge into one line.
    private static func groupIdentity(_ intent: PresentationIntent?) -> [Int] {
        guard let intent else { return [] }
        return intent.components.compactMap { component in
            if case .tableCell = component.kind { return nil }
            return component.identity
        }
    }

    private static func tableColumn(_ intent: PresentationIntent?) -> Int? {
        guard let intent else { return nil }
        for component in intent.components {
            if case .tableCell(let columnIndex) = component.kind { return columnIndex }
        }
        return nil
    }

    /// Map an intent stack (ordered innermost → outermost) to a block kind.
    private static func kind(of intent: PresentationIntent?) -> MarkdownBlock.Kind {
        guard let intent else { return .paragraph }
        let components = intent.components

        for component in components {
            switch component.kind {
            case .header(let level):
                return .heading(level: level)
            case .codeBlock(let languageHint):
                let language = languageHint?.trimmingCharacters(in: .whitespaces)
                return .codeBlock(language: (language?.isEmpty ?? true) ? nil : language)
            case .thematicBreak:
                return .thematicBreak
            default:
                break
            }
        }

        // List item: nesting depth is the count of enclosing listItem intents;
        // the innermost item's ordinal + its containing list pick the marker.
        let listItems = components.enumerated().filter {
            if case .listItem = $0.element.kind { return true }
            return false
        }
        if let innermost = listItems.first,
           case .listItem(let ordinal) = innermost.element.kind {
            let depth = listItems.count - 1
            var ordered = false
            for component in components[(innermost.offset + 1)...] {
                if case .orderedList = component.kind { ordered = true; break }
                if case .unorderedList = component.kind { break }
            }
            let marker = ordered ? "\(ordinal)." : bulletMarker(depth: depth)
            return .listItem(depth: depth, marker: marker)
        }

        if components.contains(where: {
            if case .blockQuote = $0.kind { return true }
            return false
        }) {
            return .blockQuote
        }
        return .paragraph
    }

    private static func bulletMarker(depth: Int) -> String {
        switch depth {
        case 0: return "•"
        case 1: return "◦"
        default: return "▪"
        }
    }

    /// Tint inline code spans. Bold/italic/links render natively from the
    /// parsed attributes; inline code additionally gets a monospaced font and
    /// a subtle chip background so it reads as code without raw backticks.
    private static func styleInlineCode(_ text: inout AttributedString) {
        let ranges = text.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard let inline = run.inlinePresentationIntent, inline.contains(.code) else { return nil }
            return run.range
        }
        for range in ranges {
            text[range].font = .system(.callout, design: .monospaced)
            text[range].foregroundColor = K.Colors.brandNavy
            text[range].backgroundColor = K.Colors.backgroundSecondary
        }
    }

    private static func trimmingTrailingNewlines(_ text: AttributedString) -> AttributedString {
        var text = text
        while text.characters.last == "\n" {
            let end = text.endIndex
            text.removeSubrange(text.index(end, offsetByCharacters: -1)..<end)
        }
        return text
    }
}

// MARK: - Renderer

/// Renders assistant-message Markdown as a stack of native SwiftUI blocks.
/// This is the only place Markdown becomes pixels — one renderer, no
/// competing parsers. Typography uses Dynamic Type text styles throughout.
struct MarkdownText: View {
    let text: String

    var body: some View {
        let blocks = MarkdownFormatter.blocks(for: text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                blockView(block)
                    .padding(.top, topSpacing(of: block, in: blocks))
            }
        }
        .tint(K.Colors.royalBlue) // link color
    }

    /// Compact, chat-style vertical rhythm: list rows sit tight, paragraphs
    /// breathe, headings get extra air above.
    private func topSpacing(of block: MarkdownBlock, in blocks: [MarkdownBlock]) -> CGFloat {
        guard block.id > 0 else { return 0 }
        switch (blocks[block.id - 1].kind, block.kind) {
        case (.listItem, .listItem): return 5
        case (_, .heading): return 14
        default: return 10
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .paragraph:
            styledText(block.text, font: .body)

        case .heading(let level):
            styledText(block.text, font: headingFont(level))

        case .listItem(let depth, let marker):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(marker)
                    .font(.body)
                    .foregroundColor(K.Colors.ink)
                    .frame(minWidth: 16, alignment: .trailing)
                styledText(block.text, font: .body)
            }
            .padding(.leading, CGFloat(depth) * 18)

        case .codeBlock(let language):
            codeBlockView(block.text, language: language)

        case .blockQuote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(K.Colors.goldSoft)
                    .frame(width: 3)
                styledText(block.text, font: .body, color: K.Colors.textSecondary)
            }

        case .thematicBreak:
            Divider().overlay(K.Colors.borderColor)
        }
    }

    private func styledText(_ text: AttributedString, font: Font, color: Color = K.Colors.ink) -> some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineSpacing(3.5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(.title2).weight(.semibold)
        case 2: return .system(.title3).weight(.semibold)
        default: return .system(.headline)
        }
    }

    /// Fenced code block: monospaced, on a card, horizontally scrollable so
    /// long lines never push the layout under the composer or off-screen.
    private func codeBlockView(_ text: AttributedString, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                Text(language)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(K.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(String(text.characters))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(K.Colors.ink)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(K.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(K.Colors.borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    ScrollView {
        MarkdownText(text: """
        ## Deleting the other apps

        I can see **four app records** in App Store Connect. Here's how:

        1. Open the app you want to remove
        2. Scroll to *Additional Information*
        3. Tap `Remove App`

        - First point
        - Second point
          - Nested detail
          - Another nested one

        Inline `code` and a [link](https://developer.apple.com).

        ```swift
        let answer = 42
        print("hello")
        ```

        > App records can only be removed when they meet Apple's eligibility conditions.
        """)
        .padding()
    }
    .background(K.Colors.cream)
}
