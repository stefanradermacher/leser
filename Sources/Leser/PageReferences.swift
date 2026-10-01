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
        /// Where the reference is on its page, one rectangle per line, in page coordinates.
        let bounds: [CGRect]
        /// Index of the page it refers to.
        let target: Int
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

    init(document: PDFDocument) {
        self.document = document
        hasLabels = Self.hasPageLabels(document)
        pageNumbers = Self.pageNumbers(of: document, hasLabels: hasLabels)
        var titles: [String] = []
        if let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            titles.append(title)
        }
        if let url = document.documentURL { titles.append(url.deletingPathExtension().lastPathComponent) }
        ownTitles = titles.map(Self.normalized).filter { $0.count >= 3 }
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
        for match in Self.pattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            let before = string.substring(to: match.range.location)
            let abbreviated = string.substring(with: match.range(at: 1)).hasSuffix(".")
            guard pointsIntoDocument(after: before, abbreviated: abbreviated),
                  !namesAnotherBook(after: string.substring(from: NSMaxRange(match.range)))
            else { continue }
            // The first number together with the word before it, a second one on its own.
            var parts = [NSRange(location: match.range.location,
                                 length: NSMaxRange(match.range(at: 2)) - match.range.location)]
            if match.range(at: 3).location != NSNotFound { parts.append(match.range(at: 3)) }
            for (number, range) in zip([match.range(at: 2), match.range(at: 3)], parts) {
                let digits = string.substring(with: number)
                guard let target = pageNumbers[digits], target != index,
                      hasLabels || printsNumber(Int(digits) ?? 0, onPage: target),
                      let selection = page.selection(for: range)
                else { continue }
                let bounds = selection.selectionsByLine().map { $0.bounds(for: page) }
                    .filter { !$0.isEmpty }
                guard !bounds.isEmpty,
                      !bounds.contains(where: { rect in links.contains { $0.intersects(rect) } })
                else { continue }
                references.append(Reference(bounds: bounds, target: target, location: range.location))
            }
        }
        return references
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
    /// document's own title.
    private func namesAnotherBook(after text: String) -> Bool {
        let context = Self.joined(String(text.prefix(80)))
        guard let match = Self.titleAfter.firstMatch(
            in: context, range: NSRange(location: 0, length: (context as NSString).length))
        else { return false }
        let title = Self.normalized((context as NSString).substring(from: match.range(at: 1).location))
        return !ownTitles.contains { title.hasPrefix($0) }
    }

    private static let titleAfter = try! NSRegularExpression(
        pattern: #"^\s*,?\s*(?:of|from|in|im|aus|der|des)\s+(?:the\s+|den\s+)?(\p{Lu})"#)

    private func endsWithOwnTitle(_ text: String) -> Bool {
        let normalized = Self.normalized(text)
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
    private static func joined(_ text: String) -> String {
        text.replacingOccurrences(of: #"[-‐­]\s*\n\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func normalized(_ text: String) -> String {
        joined(text).lowercased()
            .replacingOccurrences(of: #"[^\p{L}\d]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
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
