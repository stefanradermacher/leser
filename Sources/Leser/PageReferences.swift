// Copyright 2026 Stefan Radermacher
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PDFKit

/// Page references in the text of a document that are not links, like "(page 359)",
/// "see page 12" or "siehe Seite 42", so that they can be previewed and followed like links.
///
/// Only references to the document itself count, and better one missed than one leading to a
/// wrong page: a reference preceded by another book's title, as in "(Kernregeln: Monster,
/// S. 284)", is left alone, and so is a number no page of the document carries. Page numbers
/// are the page labels the PDF sets; a PDF without them counts the pages by position, and a
/// reference is only taken if the page at that position shows the number, since a cover
/// before page 1 would shift them all.
@MainActor
final class PageReferences {
    struct Reference {
        enum Target: Equatable {
            /// A page of this document, by index.
            case page(Int)
            /// A page of another book, by its title and the page number given.
            case book(title: String, number: Int)
        }

        /// Where the reference is on its page, one rectangle per line, in page coordinates.
        let bounds: [CGRect]
        let target: Target
        /// Position in the page's text, identifying the reference on its page.
        let location: Int
    }

    let document: PDFDocument
    private let pageNumbers: [String: Int]
    /// Whether the PDF sets page labels; without them, a target page has to show its number.
    private let hasLabels: Bool
    /// The numbers found printed at the top or bottom of a page, by page index.
    private var printed: [Int: Set<Int>] = [:]
    private let ownTitles: [String]
    private var cache: [Int: [Reference]] = [:]
    /// The books assigned to files when the references were found: a newly assigned title is
    /// recognized in more forms.
    let booksRevision = OtherBooks.revision

    /// `name` is the document's file name, taken as its title along with the one the PDF sets.
    init(document: PDFDocument, name: String? = nil) {
        self.document = document
        hasLabels = Self.hasPageLabels(document)
        pageNumbers = Self.pageNumbers(of: document, hasLabels: hasLabels)
        var titles: [String] = []
        if let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            titles.append(title)
        }
        if let name { titles.append((name as NSString).deletingPathExtension) }
        if let url = document.documentURL { titles.append(url.deletingPathExtension().lastPathComponent) }
        ownTitles = titles.map(OtherBooks.key(for:)).filter { $0.count >= 3 }
    }

    /// The index of the page with a number, as a reference gives it: by the page labels of
    /// the PDF, or without them by position, if the page shows the number.
    func pageIndex(forNumber number: Int) -> Int? {
        guard let index = pageNumbers[String(number)], hasLabels || printsNumber(number, onPage: index)
        else { return nil }
        return index
    }

    /// The reference at a point of a page, in page coordinates.
    func reference(at point: CGPoint, on page: PDFPage) -> Reference? {
        references(on: page).first { $0.bounds.contains { $0.insetBy(dx: -1, dy: -1).contains(point) } }
    }

    func references(on page: PDFPage) -> [Reference] {
        let index = document.index(for: page)
        if let cached = cache[index] { return cached }
        let found = find(on: page, index: index)
        cache[index] = found
        return found
    }

    // MARK: - Finding references

    private static let pattern = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\d])(pages?|pp?\.|Seiten?|S\.)\s*(\d{1,4})(?:\s*(?:[–-]|and|und|bis|to)\s*(\d{1,4}))?(?![\p{L}\d])"#)

    /// Words after which a page reference points into the document itself.
    private static let leadIns: Set<String> = [
        "see", "also", "on", "at", "in", "to", "from", "cf.",
        "siehe", "vgl.", "auf", "ab", "von", "s.a.",
    ]

    private func find(on page: PDFPage, index: Int) -> [Reference] {
        guard let text = page.string, !text.isEmpty else { return [] }
        let string = text as NSString
        let links = page.annotations.filter { $0.type == "Link" }.map(\.bounds)
        var references: [Reference] = []
        var taken: [NSRange] = []

        func add(_ range: NSRange, _ target: Reference.Target) {
            guard !taken.contains(where: { NSIntersectionRange($0, range).length > 0 }),
                  let selection = page.selection(for: range)
            else { return }
            let bounds = selection.selectionsByLine().map { $0.bounds(for: page) }.filter { !$0.isEmpty }
            guard !bounds.isEmpty, !bounds.contains(where: { rect in links.contains { $0.intersects(rect) } })
            else { return }
            taken.append(range)
            references.append(Reference(bounds: bounds, target: target, location: range.location))
        }

        for match in Self.pattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            let before = string.substring(to: match.range.location)
            let after = string.substring(from: NSMaxRange(match.range))
            let abbreviated = string.substring(with: match.range(at: 1)).hasSuffix(".")
            let first = Int(string.substring(with: match.range(at: 2))) ?? 0

            if let book = bookBefore(match.range.location, in: string, abbreviated: abbreviated) {
                // "(Kernregeln: Monster, S. 284)": the title together with the page. Spelled
                // out, as in "(Die Belohnungen der Stadt, Seite 64)", it is rather a section of
                // this document, unless the title is assigned to another book.
                let own = isOwnTitle(book.title)
                if !own, !abbreviated, !OtherBooks.isKnown(book.title) {
                    if let target = pageIndex(forNumber: first), target != index {
                        add(NSRange(location: match.range.location,
                                    length: NSMaxRange(match.range(at: 2)) - match.range.location), .page(target))
                    }
                    continue
                }
                if !own {
                    add(NSRange(location: book.start, length: NSMaxRange(match.range(at: 2)) - book.start),
                        .book(title: book.title, number: first))
                    continue
                }
            } else if let book = bookAfter(NSMaxRange(match.range), in: string) {
                // "S. 8 in Kernregeln: NSC": the page together with the title.
                if !isOwnTitle(book.title) {
                    add(NSRange(location: match.range.location, length: book.end - match.range.location),
                        .book(title: book.title, number: first))
                    continue
                }
            }
            guard pointsIntoDocument(after: before, abbreviated: abbreviated),
                  !namesAnotherBook(after: after)
            else { continue }
            // The first number together with the word before it, a second one on its own.
            var parts = [NSRange(location: match.range.location,
                                 length: NSMaxRange(match.range(at: 2)) - match.range.location)]
            if match.range(at: 3).location != NSNotFound { parts.append(match.range(at: 3)) }
            for (number, range) in zip([match.range(at: 2), match.range(at: 3)], parts) {
                guard let digits = Int(string.substring(with: number)),
                      let target = pageIndex(forNumber: digits), target != index
                else { continue }
                add(range, .page(target))
            }
        }

        // "(Player Core 392)": a title in italics, or one assigned to a file, and a number.
        for match in Self.titleAndNumber.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            let titleRange = match.range(at: 1)
            let title = Self.joined(string.substring(with: titleRange)).trimmingCharacters(in: .whitespaces)
            guard let number = Int(string.substring(with: match.range(at: 2))),
                  Self.isTitle(title),
                  OtherBooks.isKnown(title) || Self.isItalic(titleRange, on: page)
            else { continue }
            let range = NSRange(location: titleRange.location, length: NSMaxRange(match.range(at: 2)) - titleRange.location)
            if isOwnTitle(title) {
                if let target = pageIndex(forNumber: number), target != index { add(range, .page(target)) }
            } else {
                add(range, .book(title: title, number: number))
            }
        }
        return references.sorted { $0.location < $1.location }
    }

    // MARK: - References to other books

    private static let titleAndNumber = try! NSRegularExpression(
        pattern: #"(?<=[(;,][ \t\n]{0,2})(\p{Lu}[\p{L}\d’'\-–: \n]{1,60}?)\s+(\d{1,4})(?=\s*[);,])"#)

    /// Small words that can stand inside a title, as in "Zorn der Elemente".
    private static let titleJoiners: Set<String> = ["der", "des", "die", "das", "von", "und", "of", "the", "and"]

    /// A book title right before a page reference: "Kernregeln: Monster, S. 284", or with an
    /// abbreviation in brackets "Krieg der Unsterblichen (S. 147)". Gives the title and where
    /// it starts in the page's text.
    private func bookBefore(_ location: Int, in string: NSString, abbreviated: Bool) -> (title: String, start: Int)? {
        // Back over spaces to the separator, a comma, or a bracket before an abbreviation.
        var end = location
        while end > 0, Self.isSpace(string.character(at: end - 1)) { end -= 1 }
        guard end > 0 else { return nil }
        let separator = Character(UnicodeScalar(string.character(at: end - 1)) ?? " ")
        guard separator == "," || (separator == "(" && abbreviated) else { return nil }
        end -= 1
        while end > 0, Self.isSpace(string.character(at: end - 1)) { end -= 1 }

        let start = max(0, end - 100)
        let tail = Self.joined(string.substring(with: NSRange(location: start, length: end - start)))
        guard let title = Self.trailingTitle(of: tail) else { return nil }
        return (title, Self.locationBefore(end, in: string, alphanumerics: Self.alphanumericCount(title)))
    }

    /// A book title right after a page reference: "S. 8 in Kernregeln: NSC". Gives the title
    /// and where it ends in the page's text.
    private func bookAfter(_ location: Int, in string: NSString) -> (title: String, end: Int)? {
        let length = min(100, string.length - location)
        let raw = string.substring(with: NSRange(location: location, length: length))
        let context = Self.joined(raw)
        guard let match = Self.titleAfter.firstMatch(in: context, range: NSRange(location: 0, length: (context as NSString).length))
        else { return nil }
        let rest = (context as NSString).substring(from: match.range(at: 1).location)
        guard let title = Self.leadingTitle(of: rest) else { return nil }
        // Where the title ends in the page's text: after the words before it and the title.
        let lead = (context as NSString).substring(to: match.range(at: 1).location)
        let count = Self.alphanumericCount(lead) + Self.alphanumericCount(title)
        return (title, Self.locationAfter(location, in: string, alphanumerics: count))
    }

    /// The title at the end of a text: capitalized words, with small words like "der" inside
    /// and a volume number at the end, as in "Kernregeln: Monster 2". It starts after an
    /// opening bracket or quote, if there is one.
    private static func trailingTitle(of text: String) -> String? {
        var words = text.split(separator: " ").map(String.init)
        var title: [String] = []
        if let last = words.last, Int(last) != nil, words.count > 1 {
            title.insert(last, at: 0)
            words.removeLast()
        }
        while let word = words.last {
            let bare = String(word.drop { "([„\"'‚»«".contains($0) })
            let opens = bare != word
            if isTitleWord(bare) || (titleJoiners.contains(bare) && !title.isEmpty) {
                title.insert(bare, at: 0)
                words.removeLast()
                if opens { break }
            } else {
                break
            }
        }
        while let first = title.first, titleJoiners.contains(first) || Int(first) != nil { title.removeFirst() }
        let result = title.joined(separator: " ")
        return isTitle(result) ? result : nil
    }

    /// The title at the start of a text, up to the first word that cannot belong to it.
    private static func leadingTitle(of text: String) -> String? {
        var title: [String] = []
        for word in text.split(separator: " ").map(String.init) {
            let bare = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,;)"))
            if isTitleWord(bare) || titleJoiners.contains(bare) || (Int(bare) != nil && !title.isEmpty) {
                title.append(bare)
                if bare != word { break }
            } else {
                break
            }
        }
        while let last = title.last, titleJoiners.contains(last) { title.removeLast() }
        let result = title.joined(separator: " ")
        return isTitle(result) ? result : nil
    }

    /// A capitalized word of at least three letters, like "Kernregeln:" or "NSC": short ones
    /// like "SG" or "A" are rather values or areas than titles.
    private static func isTitleWord(_ word: String) -> Bool {
        let bare = word.hasSuffix(":") ? String(word.dropLast()) : word
        guard let first = bare.first, first.isUppercase else { return false }
        return bare.filter(\.isLetter).count >= 3 && bare.allSatisfy { $0.isLetter || "-’'".contains($0) }
    }

    /// Whether a text can be a title: title words and small words, at most a volume number at
    /// the end, starting with a title word. A word in capitals only counts after a colon, as in
    /// "Kernregeln: NSC"; elsewhere it is rather a heading, like "RIESIG TIER" in a stat block.
    private static func isTitle(_ text: String) -> Bool {
        let words = text.split(separator: " ").map(String.init)
        guard let first = words.first, isTitleWord(first), words.count <= 8,
              !OtherBooks.key(for: text).isEmpty,
              let last = words.last, !last.hasSuffix(":")
        else { return false }
        for (offset, word) in words.enumerated() {
            if isTitleWord(word) {
                let letters = word.filter(\.isLetter)
                if letters.count > 1, letters.allSatisfy(\.isUppercase),
                   offset == 0 || !words[offset - 1].hasSuffix(":") { return false }
                continue
            }
            if titleJoiners.contains(word) { continue }
            if Int(word) != nil, offset == words.count - 1 { continue }
            return false
        }
        return true
    }

    /// Whether all letters of a range are set in italics, as book titles are in Paizo's books.
    private static func isItalic(_ range: NSRange, on page: PDFPage) -> Bool {
        guard let text = page.selection(for: range)?.attributedString, text.length > 0 else { return false }
        var italic = true
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, part, stop in
            let letters = (text.string as NSString).substring(with: part).contains { $0.isLetter }
            guard letters else { return }
            let font = value as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let name = font?.fontName.lowercased() ?? ""
            if !(traits.contains(.italic) || name.contains("italic") || name.contains("oblique")) {
                italic = false
                stop.pointee = true
            }
        }
        return italic
    }

    private static func isSpace(_ character: unichar) -> Bool {
        UnicodeScalar(character).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
    }

    private static func alphanumericCount(_ text: String) -> Int {
        text.filter { $0.isLetter || $0.isNumber }.count
    }

    /// The position in a text after going back from `end` over a number of letters and digits,
    /// whatever spaces, line breaks and hyphens lie between them.
    private static func locationBefore(_ end: Int, in string: NSString, alphanumerics count: Int) -> Int {
        var location = end
        var remaining = count
        while location > 0, remaining > 0 {
            location -= 1
            if let scalar = UnicodeScalar(string.character(at: location)),
               CharacterSet.alphanumerics.contains(scalar) { remaining -= 1 }
        }
        return location
    }

    /// The position in a text after going on from `start` over a number of letters and digits.
    private static func locationAfter(_ start: Int, in string: NSString, alphanumerics count: Int) -> Int {
        var location = start
        var remaining = count
        while location < string.length, remaining > 0 {
            if let scalar = UnicodeScalar(string.character(at: location)),
               CharacterSet.alphanumerics.contains(scalar) { remaining -= 1 }
            location += 1
        }
        return location
    }

    /// Whether the text before a page reference makes it one into this document. A bracket
    /// alone is enough for "(page 12)" or "(Seite 12)", not for an abbreviation: "(S. 147)"
    /// usually follows the title of another book, as in "Krieg der Unsterblichen (S. 147)".
    private func pointsIntoDocument(after text: String, abbreviated: Bool) -> Bool {
        let tail = String(text.suffix(120))
        let context = Self.joined(tail)
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return true }

        if "([".contains(last) { return !abbreviated }
        if endsWithOwnTitle(trimmed) { return true }
        if ",:;".contains(last) {
            // "(siehe Bereich J5, Seite 61)" or "(Monster Core, page 12)", but not
            // "(Kernregeln: Monster, S. 284)".
            let segment = Self.segment(before: String(trimmed.dropLast()))
            if let first = segment.split(separator: " ").first,
               Self.leadIns.contains(first.lowercased()) { return true }
            return endsWithOwnTitle(segment)
        }
        if let word = trimmed.split(separator: " ").last,
           Self.leadIns.contains(word.lowercased()) { return true }
        // At the start of a line after a number or the end of a sentence, as in a heading.
        let line = tail.replacingOccurrences(of: "\r", with: "\n")
        if let lastBreak = line.lastIndex(of: "\n"),
           line[line.index(after: lastBreak)...].allSatisfy(\.isWhitespace),
           !last.isLetter { return true }
        return false
    }

    /// Whether a title follows the reference, as in "page 8 of Player Core" or "S. 8 in
    /// Kernregeln: NSC" – a capitalized word after "of", "in" and the like, unless it is the
    /// document's own title. With an article between, as in "page 358 in the Ability
    /// Glossary", it is rather a section of this document.
    private func namesAnotherBook(after text: String) -> Bool {
        let context = Self.joined(String(text.prefix(80)))
        guard let match = Self.titleAfter.firstMatch(
            in: context, range: NSRange(location: 0, length: (context as NSString).length))
        else { return false }
        let title = OtherBooks.key(for: (context as NSString).substring(from: match.range(at: 1).location))
        return !ownTitles.contains { title.hasPrefix($0) }
    }

    private static let titleAfter = try! NSRegularExpression(
        pattern: #"^\s*,?\s*(?:of|from|in|im|aus|der|des)\s+(\p{Lu})"#)

    /// Whether a title is this document's, also with more words before it, like a series
    /// name: "Pathfinder Monster Core" inside "Monster Core".
    private func isOwnTitle(_ title: String) -> Bool {
        let key = OtherBooks.key(for: title)
        return ownTitles.contains { key == $0 || key.hasSuffix(" " + $0) }
    }

    private func endsWithOwnTitle(_ text: String) -> Bool {
        let normalized = OtherBooks.key(for: text)
        return ownTitles.contains { normalized.hasSuffix($0) }
    }

    /// The text from the last opening bracket or sentence end on.
    private static func segment(before text: String) -> String {
        var start = text.startIndex
        if let bracket = text.lastIndex(where: { "([".contains($0) }) {
            start = text.index(after: bracket)
        }
        if let period = text.range(of: ". ", options: .backwards), period.upperBound > start {
            start = period.upperBound
        }
        return text[start...].trimmingCharacters(in: .whitespaces)
    }

    /// Text over line breaks as one line, with words hyphenated at a break put together again.
    nonisolated static func joined(_ text: String) -> String {
        text.replacingOccurrences(of: #"[-‐­]\s*\n\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    // MARK: - Page numbers

    /// Page indexes by page number: the page labels the PDF sets, or, without them, the
    /// positions of the pages.
    private static func pageNumbers(of document: PDFDocument, hasLabels: Bool) -> [String: Int] {
        var numbers: [String: Int] = [:]
        for index in 0..<document.pageCount {
            let label = hasLabels ? document.page(at: index)?.label : "\(index + 1)"
            if let label, Int(label) != nil, numbers[label] == nil { numbers[label] = index }
        }
        return numbers
    }

    private static func hasPageLabels(_ document: PDFDocument) -> Bool {
        guard let catalog = document.documentRef?.catalog else { return false }
        var labels: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(catalog, "PageLabels", &labels)
    }

    /// Whether a page has a number printed at its top or bottom, checked where the PDF sets
    /// no page labels: the position of a page is then only its number if it says so, a cover
    /// before page 1 would otherwise shift every reference.
    private func printsNumber(_ number: Int, onPage index: Int) -> Bool {
        if let known = printed[index] { return known.contains(number) }
        let lines = (document.page(at: index)?.string ?? "").split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = Set((lines.prefix(3) + lines.suffix(3)).flatMap(Self.printedNumbers))
        printed[index] = numbers
        return numbers.contains(number)
    }

    /// The page number a line can stand for if it holds nothing but a number. Some documents
    /// have the number in their text twice, drawn on top of each other, so "1919" can be 19
    /// as well – and "33" can be 3.
    private static func printedNumbers(_ line: String) -> [Int] {
        guard !line.isEmpty, line.count <= 8, line.allSatisfy(\.isASCII), let number = Int(line), number > 0
        else { return [] }
        let half = line.prefix(line.count / 2)
        if line.count.isMultiple(of: 2), half == line.suffix(line.count / 2), let single = Int(half) {
            return [number, single]
        }
        return [number]
    }
}
