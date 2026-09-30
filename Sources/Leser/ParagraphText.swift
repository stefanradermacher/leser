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

import Foundation
import PDFKit

/// Text of a selection with its paragraphs rejoined.
///
/// PDFs store lines, not paragraphs: PDFKit's own text ends every line with a line break, so a
/// copied paragraph arrives in a word processor broken exactly as it was on the page. Here the
/// lines of a selection are joined again wherever the layout says they belong together, and a
/// word hyphenated at the end of a line is put back together. Fonts, and with them bold and
/// italic, are kept.
enum ParagraphText {
    static func text(of selection: PDFSelection) -> NSAttributedString {
        let lines = selection.selectionsByLine().compactMap(Line.init)
        guard !lines.isEmpty else { return selection.attributedString ?? NSAttributedString() }

        let text = NSMutableAttributedString(attributedString: lines[0].styled)
        for index in lines.indices.dropFirst() {
            let line = lines[index]
            // The space or line break takes the type of the text before it.
            let attributes = text.attributes(at: text.length - 1, effectiveRange: nil)
            if !continues(at: index, in: lines) {
                text.append(NSAttributedString(string: "\n", attributes: attributes))
            } else if isHyphenated(text.string, before: line.text) {
                text.deleteCharacters(in: NSRange(location: text.length - 1, length: 1))
            } else {
                text.append(NSAttributedString(string: " ", attributes: attributes))
            }
            text.append(line.styled)
        }
        return text
    }

    /// One line of the selection without surrounding white space, where it is and the type it
    /// starts and ends with.
    private struct Line {
        let styled: NSAttributedString
        let page: PDFPage
        let bounds: CGRect
        let firstFont: NSFont?
        let lastFont: NSFont?

        var text: String { styled.string }

        init?(_ selection: PDFSelection) {
            guard let page = selection.pages.first else { return nil }
            let string = selection.attributedString
                ?? NSAttributedString(string: selection.string ?? "")
            let characters = string.string as NSString
            let visible = CharacterSet.whitespacesAndNewlines.inverted
            let first = characters.rangeOfCharacter(from: visible)
            guard first.location != NSNotFound else { return nil }
            let last = characters.rangeOfCharacter(from: visible, options: .backwards)
            styled = string.attributedSubstring(
                from: NSRange(location: first.location, length: NSMaxRange(last) - first.location))
            self.page = page
            bounds = selection.bounds(for: page)
            firstFont = styled.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            lastFont = styled.attribute(.font, at: styled.length - 1, effectiveRange: nil) as? NSFont
        }

        /// Width of the first word including the space after it, estimated from the average
        /// width of the characters of the line.
        var firstWordWidth: CGFloat {
            let word = text.prefix { !$0.isWhitespace }.count + 1
            return bounds.width * CGFloat(word) / CGFloat(max(text.count, 1))
        }

        func startsListItem(after previous: Line) -> Bool {
            guard let first = text.first else { return false }
            if "•◦▪‣∙·–—-*".contains(first), text.dropFirst().first?.isWhitespace == true { return true }
            // "1." or "a)" followed by a space, after a line that ends a sentence; otherwise it
            // is more likely a number that happens to start the line, as in "(at least / 0)".
            guard let end = previous.text.last, ".:;!?".contains(end) else { return false }
            let marker = text.prefix { !$0.isWhitespace }
            return marker.count <= 4 && marker.count >= 2
                && (marker.last == "." || marker.last == ")")
                && marker.dropLast().allSatisfy { $0.isNumber || ($0.isLetter && marker.count == 2) }
                && text.dropFirst(marker.count).first?.isWhitespace == true
        }
    }

    /// Whether the line at `index` continues the paragraph of the line before it.
    private static func continues(at index: Int, in lines: [Line]) -> Bool {
        let previous = lines[index - 1], line = lines[index]
        guard previous.page == line.page else { return false }
        let a = previous.bounds, b = line.bounds
        let height = min(a.height, b.height)

        // Same size of type: a heading and the text below it are separate paragraphs.
        if let end = previous.lastFont, let start = line.firstFont {
            guard abs(end.pointSize - start.pointSize) <= 0.5 else { return false }
            // A line starting with a bold capitalised word after one that did not end in bold
            // starts an entry of its own, as in "Skills …" below "Perception …". A line in bold
            // throughout followed by plain text is a heading of the same size.
            if isBold(start), !isBold(end), line.text.first?.isUppercase == true { return false }
            if let first = previous.firstFont, isBold(first), isBold(end), !isBold(start) { return false }
        } else {
            guard abs(a.height - b.height) <= 0.2 * max(a.height, b.height) else { return false }
        }
        guard !line.startsListItem(after: previous) else { return false }

        // Top of the next column: the paragraph goes on there if the column ended in the
        // middle of a word or a sentence.
        if b.midY > a.midY + height {
            guard b.minX >= a.maxX - height else { return false }
            if isHyphenated(previous.text, before: line.text) { return true }
            return !(previous.text.last.map { ".!?:;”“\"»«)".contains($0) } ?? true)
                && line.text.first?.isLowercase == true
        }

        // Directly below, without the extra space between paragraphs, and in the same column.
        let step = a.midY - b.midY
        guard step > 0.5 * height, step <= 1.6 * height else { return false }
        guard min(a.maxX, b.maxX) - max(a.minX, b.minX) > 0 else { return false }

        // A line that ends before the margin although the next word would have fitted ends
        // its paragraph. The margin is where the longest of the nearby lines of the same
        // column ends.
        let margin = lines[max(index - 4, 0)...min(index + 2, lines.count - 1)]
            .filter { neighbour in
                neighbour.page == line.page
                    && abs(neighbour.bounds.midY - a.midY) <= 5 * height
                    && min(neighbour.bounds.maxX, a.maxX) - max(neighbour.bounds.minX, a.minX) > 0
            }
            .map(\.bounds.maxX)
            .max() ?? a.maxX
        guard margin - a.maxX < line.firstWordWidth else { return false }

        // In text with a straight left edge, a line indented further than the one before it
        // starts a new paragraph, unless the lines after it stay indented as well (a hanging
        // indent). Centred or right-aligned text has no such edge and is left alone.
        if b.minX - a.minX > height, index >= 3,
           lines[(index - 3)...(index - 1)].allSatisfy({ abs($0.bounds.minX - a.minX) <= 1 }) {
            guard index + 1 < lines.count,
                  lines[index + 1].page == line.page,
                  abs(lines[index + 1].bounds.minX - b.minX) <= height / 2
            else { return false }
        }
        return true
    }

    private static func isBold(_ font: NSFont) -> Bool {
        if font.fontDescriptor.symbolicTraits.contains(.bold) { return true }
        let name = font.fontName.lowercased()
        return ["bold", "black", "heavy", "semibold", "demi"].contains { name.contains($0) }
    }

    /// Whether `text` ends with a word hyphenated at the line break before `next`. The hyphen
    /// is then the last character of `text` and goes when the lines are joined.
    private static func isHyphenated(_ text: String, before next: String) -> Bool {
        guard let last = text.last else { return false }
        if last == "\u{00AD}" { return true }
        return (last == "-" || last == "\u{2010}")
            && text.dropLast().last?.isLetter == true
            && next.first?.isLowercase == true
    }
}
