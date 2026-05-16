import AppKit
import SwiftUI

struct MemoPanelView: View {
    @Bindable var store: TodoStore

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "메모",
                background: NotionDesign.Colors.memoBackground,
                hairline: NotionDesign.Colors.hairlineSoft
            ) {
                ShortcutBadge("⌘M")
            }

            if let selectedTodo = store.selectedTodo {
                MemoEditor(store: store, todo: selectedTodo)
                    .id(selectedTodo.id)
            } else {
                ContentUnavailableView("선택된 투두가 없습니다", systemImage: "note.text")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(
            minWidth: MemoPanelLayout.minimumContentWidth,
            maxWidth: .infinity,
            minHeight: MemoPanelLayout.minimumPanelContentHeight,
            maxHeight: .infinity
        )
        .background(NotionDesign.Colors.memoBackground)
        .clipShape(MemoPanelLayout.shape)
        .compositingGroup()
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(NotionDesign.Panel.floatingShadowPadding)
    }
}

enum MemoPanelLayout {
    static let contentWidth: CGFloat = 520
    static let contentMinHeight: CGFloat = 340
    static let minimumContentWidth: CGFloat = 360
    static let minimumContentMinHeight: CGFloat = 220
    static let minimumPanelContentHeight = NotionDesign.Panel.headerHeight + minimumContentMinHeight
    static let windowWidth = contentWidth + NotionDesign.Panel.floatingShadowPadding * 2
    static let windowHeight = NotionDesign.Panel.headerHeight + contentMinHeight + NotionDesign.Panel.floatingShadowPadding * 2
    static let minimumWindowWidth = minimumContentWidth + NotionDesign.Panel.floatingShadowPadding * 2
    static let minimumWindowHeight = NotionDesign.Panel.headerHeight + minimumContentMinHeight + NotionDesign.Panel.floatingShadowPadding * 2
    static let shape = RoundedRectangle(cornerRadius: NotionDesign.Radius.widget, style: .continuous)
}

private struct MemoEditor: View {
    let store: TodoStore
    let todo: TodoItem
    @State private var notes: String

    init(store: TodoStore, todo: TodoItem) {
        self.store = store
        self.todo = todo
        _notes = State(initialValue: todo.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(NotionDesign.Colors.primary)
                    .frame(width: 5, height: 5)
                Text(todo.title)
                    .font(NotionDesign.Fonts.pretendard(size: 12, weight: .medium))
                    .foregroundStyle(NotionDesign.Colors.slate)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NotionDesign.Colors.hairlineSoft)
                    .frame(height: 1)
            }

            LiveMarkdownEditor(text: $notes)
                .onChange(of: notes) { _, newValue in
                    persist(notes: newValue)
                }
                .frame(maxWidth: .infinity, minHeight: MemoPanelLayout.contentMinHeight - 62, maxHeight: .infinity)

            HStack {
                Text("\(notes.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)줄")
                Spacer()
                Text("자동 저장됨")
            }
            .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
            .foregroundStyle(NotionDesign.Colors.stone)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NotionDesign.Colors.hairlineSoft)
                    .frame(height: 1)
            }
        }
    }

    private func persist(notes: String) {
        var updated = store.binding(for: todo)
        updated.notes = notes
        store.updateTodo(updated)
    }
}

private struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.onToggleMarkdownStyle = { [weak coordinator = context.coordinator, weak textView] style in
            guard let textView else { return }
            coordinator?.toggleMarkdownStyle(style, in: textView)
        }
        textView.string = text
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.applyMarkdownStyle(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        context.coordinator.parent = self
        context.coordinator.applyMarkdownStyle(to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LiveMarkdownEditor
        private var isApplyingStyle = false

        init(_ parent: LiveMarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyMarkdownStyle(to: textView)
        }

        func toggleMarkdownStyle(_ style: MarkdownInlineStyle, in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let selectedRange = textView.selectedRange()
            let marker = style.marker
            let nsString = textView.string as NSString

            if selectedRange.length == 0 {
                insertEmptyMarkdownMarker(marker, textView: textView, storage: storage)
            } else if isRange(selectedRange, wrappedBy: marker, in: nsString) {
                unwrapMarkdownMarker(marker, selectedRange: selectedRange, textView: textView, storage: storage)
            } else {
                wrapMarkdownMarker(marker, selectedRange: selectedRange, textView: textView, storage: storage)
            }

            parent.text = textView.string
            applyMarkdownStyle(to: textView)
        }

        private func insertEmptyMarkdownMarker(
            _ marker: String,
            textView: NSTextView,
            storage: NSTextStorage
        ) {
            let selectedRange = textView.selectedRange()
            guard textView.shouldChangeText(in: selectedRange, replacementString: marker + marker) else { return }

            storage.replaceCharacters(in: selectedRange, with: marker + marker)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: selectedRange.location + marker.count, length: 0))
        }

        private func wrapMarkdownMarker(
            _ marker: String,
            selectedRange: NSRange,
            textView: NSTextView,
            storage: NSTextStorage
        ) {
            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            let replacement = marker + selectedText + marker
            guard textView.shouldChangeText(in: selectedRange, replacementString: replacement) else { return }

            storage.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: selectedRange.location + marker.count, length: selectedRange.length))
        }

        private func unwrapMarkdownMarker(
            _ marker: String,
            selectedRange: NSRange,
            textView: NSTextView,
            storage: NSTextStorage
        ) {
            let leadingRange = NSRange(location: selectedRange.location - marker.count, length: marker.count)
            let trailingRange = NSRange(location: selectedRange.upperBound, length: marker.count)
            let affectedRange = NSRange(location: leadingRange.location, length: selectedRange.length + marker.count * 2)
            guard textView.shouldChangeText(in: affectedRange, replacementString: nil) else { return }

            storage.replaceCharacters(in: trailingRange, with: "")
            storage.replaceCharacters(in: leadingRange, with: "")
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: selectedRange.location - marker.count, length: selectedRange.length))
        }

        private func isRange(_ range: NSRange, wrappedBy marker: String, in string: NSString) -> Bool {
            let markerLength = marker.count
            guard range.location >= markerLength,
                  range.upperBound + markerLength <= string.length else {
                return false
            }

            let leadingRange = NSRange(location: range.location - markerLength, length: markerLength)
            let trailingRange = NSRange(location: range.upperBound, length: markerLength)
            return string.substring(with: leadingRange) == marker
                && string.substring(with: trailingRange) == marker
        }

        func applyMarkdownStyle(to textView: NSTextView) {
            guard !isApplyingStyle else { return }
            isApplyingStyle = true
            defer { isApplyingStyle = false }

            let selectedRanges = textView.selectedRanges
            let storage = textView.textStorage ?? NSTextStorage()
            let string = textView.string as NSString
            let fullRange = NSRange(location: 0, length: string.length)
            guard fullRange.length > 0 else { return }

            storage.beginEditing()
            storage.setAttributes(Self.baseAttributes, range: fullRange)
            applyLineStyles(in: storage, string: string, fullRange: fullRange)
            applyInlineStyles(in: storage, string: string, fullRange: fullRange)
            storage.endEditing()

            textView.selectedRanges = selectedRanges
            textView.needsDisplay = true
        }

        private func applyLineStyles(in storage: NSTextStorage, string: NSString, fullRange: NSRange) {
            string.enumerateSubstrings(in: fullRange, options: [.byLines]) { line, lineRange, _, _ in
                guard let line else { return }
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("### ") {
                    self.applyHeadingStyle(level: 3, marker: "### ", line: line, lineRange: lineRange, storage: storage)
                } else if trimmed.hasPrefix("## ") {
                    self.applyHeadingStyle(level: 2, marker: "## ", line: line, lineRange: lineRange, storage: storage)
                } else if trimmed.hasPrefix("# ") {
                    self.applyHeadingStyle(level: 1, marker: "# ", line: line, lineRange: lineRange, storage: storage)
                } else if trimmed.hasPrefix(">") {
                    storage.addAttributes([
                        .foregroundColor: NSColor.systemGray,
                        .font: Self.baseItalicFont
                    ], range: lineRange)
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                    self.applyListStyle(line: line, lineRange: lineRange, storage: storage)
                }
            }
        }

        private func applyHeadingStyle(
            level: Int,
            marker: String,
            line: String,
            lineRange: NSRange,
            storage: NSTextStorage
        ) {
            let markerLocation = lineRange.location + line.leadingWhitespaceCount
            let markerRange = NSRange(location: markerLocation, length: marker.count)
            let contentRange = NSRange(location: markerRange.upperBound, length: max(0, lineRange.upperBound - markerRange.upperBound))

            storage.addAttributes(Self.headerAttributes(size: Self.headingSize(for: level)), range: contentRange)
            storage.addAttributes(Self.markupAttributes, range: markerRange)
        }

        private func applyListStyle(line: String, lineRange: NSRange, storage: NSTextStorage) {
            let markerLength: Int
            let isUnordered = line.trimmingCharacters(in: .whitespaces).hasPrefix("- ")
                || line.trimmingCharacters(in: .whitespaces).hasPrefix("* ")
            if isUnordered {
                markerLength = 2
            } else if let match = line.range(of: #"^\s*\d+\. "#, options: .regularExpression) {
                markerLength = line.distance(from: match.lowerBound, to: match.upperBound) - line.leadingWhitespaceCount
            } else {
                markerLength = 0
            }

            storage.addAttributes([
                .foregroundColor: Self.charcoal,
                .paragraphStyle: Self.listParagraphStyle
            ], range: lineRange)

            let markerLocation = lineRange.location + line.leadingWhitespaceCount
            if markerLength > 0 {
                storage.addAttributes(
                    isUnordered ? Self.hiddenMarkupAttributes : Self.listMarkerAttributes,
                    range: NSRange(location: markerLocation, length: markerLength)
                )
            }
        }

        private func applyInlineStyles(in storage: NSTextStorage, string: NSString, fullRange: NSRange) {
            apply(pattern: #"\*\*([^*]+)\*\*"#, attributes: [.font: Self.baseBoldFont], storage: storage, range: fullRange)
            apply(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, attributes: [.font: Self.baseItalicFont], storage: storage, range: fullRange)
            apply(pattern: #"`([^`\n]+)`"#, attributes: [
                .font: Self.monoFont,
                .backgroundColor: NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.92, alpha: 1)
            ], storage: storage, range: fullRange)
            apply(pattern: #"~~([^~\n]+)~~"#, attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue], storage: storage, range: fullRange)
            apply(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, attributes: [
                .foregroundColor: NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.83, alpha: 1),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], storage: storage, range: fullRange)
        }

        private func apply(
            pattern: String,
            attributes: [NSAttributedString.Key: Any],
            storage: NSTextStorage,
            range: NSRange
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
                guard let match, match.range.length > 0 else { return }
                storage.addAttributes(attributes, range: match.range)
            }
        }

        private static let charcoal = NSColor(calibratedRed: 0.216, green: 0.208, blue: 0.184, alpha: 1)
        private static let paragraphStyle: NSParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacing = 3
            return style
        }()
        private static let listParagraphStyle: NSParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacing = 3
            style.firstLineHeadIndent = 0
            style.headIndent = 18
            return style
        }()
        private static let baseFont = NSFont(name: AppFontRegistry.primaryFontName, size: 13) ?? .systemFont(ofSize: 13)
        private static let baseBoldFont = NSFont(name: AppFontRegistry.primaryFontName, size: 13)?.withTraits(.boldFontMask) ?? .boldSystemFont(ofSize: 13)
        private static let baseItalicFont = (NSFont(name: AppFontRegistry.primaryFontName, size: 13) ?? .systemFont(ofSize: 13)).withTraits(.italicFontMask)
        private static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private static let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: charcoal,
            .paragraphStyle: paragraphStyle
        ]
        private static let markupAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: AppFontRegistry.primaryFontName, size: 11) ?? .systemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.59, blue: 0.52, alpha: 1)
        ]
        private static let listMarkerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: AppFontRegistry.primaryFontName, size: 13)?.withTraits(.boldFontMask) ?? .boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.83, alpha: 1)
        ]
        private static let hiddenMarkupAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.clear
        ]

        private static func headerAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont(name: AppFontRegistry.primaryFontName, size: size)?.withTraits(.boldFontMask) ?? .boldSystemFont(ofSize: size),
                .foregroundColor: charcoal
            ]
        }

        private static func headingSize(for level: Int) -> CGFloat {
            switch level {
            case 1:
                20
            case 2:
                17
            default:
                15
            }
        }
    }
}

private enum MarkdownInlineStyle {
    case bold
    case italic
    case strikethrough

    var marker: String {
        switch self {
        case .bold:
            "**"
        case .italic:
            "*"
        case .strikethrough:
            "~~"
        }
    }
}

private final class MarkdownTextView: NSTextView {
    private static let bulletColor = NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.83, alpha: 1)
    var onToggleMarkdownStyle: ((MarkdownInlineStyle) -> Void)?
    private var didFocusOnWindow = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didFocusOnWindow, let window else { return }
        didFocusOnWindow = true
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleMarkdownShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawListBullets()
    }

    private func handleMarkdownShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let character = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        let hasShift = event.modifierFlags.contains(.shift)

        switch (character, hasShift) {
        case ("b", false):
            onToggleMarkdownStyle?(.bold)
        case ("i", false):
            onToggleMarkdownStyle?(.italic)
        case ("s", true), ("x", true):
            onToggleMarkdownStyle?(.strikethrough)
        default:
            return false
        }

        return true
    }

    private func drawListBullets() {
        guard let layoutManager,
              let textContainer,
              string.isEmpty == false else {
            return
        }

        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let origin = textContainerOrigin

        nsString.enumerateSubstrings(in: fullRange, options: [.byLines]) { line, lineRange, _, _ in
            guard let line,
                  line.trimmingCharacters(in: .whitespaces).hasPrefix("- ")
                    || line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") else {
                return
            }

            let markerLocation = lineRange.location + line.leadingWhitespaceCount
            guard markerLocation < nsString.length else { return }

            let markerGlyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: markerLocation, length: 1),
                actualCharacterRange: nil
            )
            guard markerGlyphRange.length > 0 else { return }

            let markerRect = layoutManager.boundingRect(forGlyphRange: markerGlyphRange, in: textContainer)
            let bulletRect = NSRect(
                x: origin.x + markerRect.minX + 1,
                y: origin.y + markerRect.midY - 2.5,
                width: 5,
                height: 5
            )

            Self.bulletColor.setFill()
            NSBezierPath(ovalIn: bulletRect).fill()
        }
    }
}

private extension String {
    var leadingWhitespaceCount: Int {
        var count = 0
        for character in self {
            guard character == " " || character == "\t" else { break }
            count += 1
        }
        return count
    }
}

private extension NSFont {
    func withTraits(_ traits: NSFontTraitMask) -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: traits)
    }
}

private struct ShortcutBadge: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
            .foregroundStyle(NotionDesign.Colors.slate)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
    }
}
