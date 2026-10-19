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

import AppKit
import PDFKit

/// What dragging the mouse over a page does, as in Preview's Tools menu.
enum ReaderTool: String, CaseIterable, Identifiable {
    /// Selects text, by characters, also where a picture lies over the text.
    case text
    /// Selects a rectangle of a page, copied as an image.
    case area
    /// Moves the page around, for pages larger than the window.
    case hand

    var id: Self { self }

    var title: String {
        switch self {
        case .text: String(localized: "Textauswahl")
        case .area: String(localized: "Rechteckige Auswahl")
        case .hand: String(localized: "Verschieben")
        }
    }

    var systemImage: String {
        switch self {
        case .text: "character.cursor.ibeam"
        case .area: "rectangle.dashed"
        case .hand: "hand.raised"
        }
    }

    private static let key = "readerTool"

    /// The tool last chosen, for new windows.
    static var preferred: ReaderTool {
        get { UserDefaults.standard.string(forKey: key).flatMap(ReaderTool.init) ?? .text }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// A rectangle of a page chosen with the rectangular selection.
struct AreaSelection {
    let page: PDFPage
    /// In page coordinates.
    let rect: CGRect

    /// The area as a picture, at `scale` pixels per point (4 is about 300 dpi), on white.
    func image(box: PDFDisplayBox, scale: CGFloat = 4) -> CGImage? {
        let drawn = drawnRect(box: box)
        // Very large areas at a lower resolution, so the picture stays a manageable size.
        let scale = min(scale, 8000 / max(drawn.width, drawn.height, 1))
        let width = Int((drawn.width * scale).rounded()), height = Int((drawn.height * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -drawn.minX, y: -drawn.minY)
        context.interpolationQuality = .high
        page.draw(with: box, to: context)
        return context.makeImage()
    }

    /// The rectangle where drawing the page puts the area: drawing applies the page's rotation
    /// and the offset of its box.
    private func drawnRect(box: PDFDisplayBox) -> CGRect {
        rect.applying(page.transform(for: box)).standardized.integral
    }

    /// Puts the area on the pasteboard as a picture, as Preview does. A PDF of the area would
    /// carry the whole page with it, pictures and fonts, only clipped.
    func copy(box: PDFDisplayBox) {
        guard let image = image(box: box) else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        pasteboard.setData(bitmap.representation(using: .png, properties: [:]), forType: .png)
        pasteboard.setData(bitmap.tiffRepresentation, forType: .tiff)
    }
}

/// The frame of a rectangular selection, laid over the pages so it scrolls and zooms with them.
final class AreaSelectionOverlay: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        // Above the views PDFKit adds for pages as they come into view.
        layer?.zPosition = 1000
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Clicks go through to the pages.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.12).setFill()
        rect.fill()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1
        NSColor.selectedContentBackgroundColor.setStroke()
        path.setLineDash([4, 3], count: 2, phase: 0)
        path.stroke()
    }
}

extension ReaderPDFView {
    /// Whether a point of the view lies on a link, which a click with the text tool or the
    /// hand follows.
    func isOnLink(_ location: NSPoint) -> Bool {
        guard let page = page(for: location, nearest: false),
              let annotation = page.annotation(at: convert(location, to: page))
        else { return pageReference(at: location) != nil }
        return annotation.type == "Link" || pageReference(at: location) != nil
    }

    /// Moves the page with the mouse until the button is released, like a hand pushing paper.
    /// Returns whether it moved at all.
    @discardableResult
    func pan(from event: NSEvent, dragged: NSEvent.EventType, up: NSEvent.EventType) -> Bool {
        guard let window, let clip = documentView?.enclosingScrollView?.contentView else { return false }
        let start = event.locationInWindow
        let origin = clip.bounds.origin
        var moved = false
        NSCursor.closedHand.set()
        while let next = window.nextEvent(matching: [NSEvent.EventTypeMask(type: dragged), NSEvent.EventTypeMask(type: up)]),
              next.type == dragged {
            let dx = next.locationInWindow.x - start.x, dy = next.locationInWindow.y - start.y
            if abs(dx) + abs(dy) > 2 { moved = true }
            let target = NSPoint(x: origin.x - dx, y: clip.isFlipped ? origin.y + dy : origin.y - dy)
            let constrained = clip.constrainBoundsRect(NSRect(origin: target, size: clip.bounds.size)).origin
            clip.scroll(to: constrained)
            clip.enclosingScrollView?.reflectScrolledClipView(clip)
        }
        return moved
    }

    /// Draws a rectangle on the page the drag starts on until the button is released.
    func selectArea(from event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        setCurrentSelection(nil, animate: false)
        guard let window, let page = page(for: location, nearest: false) else {
            areaSelection = nil
            return
        }
        let bounds = page.bounds(for: displayBox)
        func clamped(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
        }
        let start = clamped(convert(location, to: page))
        areaSelection = nil
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseDragged { documentView?.autoscroll(with: next) }
            let end = clamped(convert(convert(next.locationInWindow, from: nil), to: page))
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(end.x - start.x), height: abs(end.y - start.y))
            // A mere click clears the selection.
            areaSelection = rect.width > 2 && rect.height > 2 ? AreaSelection(page: page, rect: rect) : nil
            if next.type == .leftMouseUp { break }
        }
    }

    /// Selects text from a click on a character, like PDFKit, except that pictures never get
    /// selected: PDFKit takes the whole box of a picture, transparent margins included, and
    /// then never selects the text below it; and a drag ending on a picture takes in all the
    /// text up to it. Here both ends of a drag go to the nearest character of text.
    /// Returns false where the click is not on a character, so PDFKit handles it.
    func selectText(from event: NSEvent) -> Bool {
        let location = convert(event.locationInWindow, from: nil)
        guard let window, let document,
              let page = page(for: location, nearest: false)
        else { return false }
        var characters = TextCharacters()
        let point = convert(location, to: page)
        guard let hit = characters.index(on: page, at: point) else { return false }
        window.makeFirstResponder(self)

        // Shift extends the selection from its start; a double click takes words, a triple
        // click lines.
        var anchor = TextCaret(page: page, pageIndex: document.index(for: page),
                               index: characters.caret(on: page, at: point, character: hit))
        var unit: PDFSelection?
        if event.modifierFlags.contains(.shift), let current = currentSelection,
           let start = TextCaret.start(of: current, in: document) {
            anchor = start
        } else if event.clickCount == 2 {
            unit = page.selection(for: characters.word(on: page, around: hit))
        } else if event.clickCount >= 3 {
            unit = characters.line(on: page, containing: hit).flatMap { page.selection(for: $0) }
        }

        func selection(to page: PDFPage, at point: CGPoint) -> PDFSelection? {
            let end = characters.nearestCaret(on: page, pageIndex: document.index(for: page), at: point)
            let text = end.flatMap { TextCaret.selection(from: anchor, to: $0, in: document) }
            guard let unit else { return text }
            let combined = PDFSelection(document: document)
            combined.add(unit)
            if let text { combined.add(text) }
            return combined
        }

        let initial: PDFSelection? = event.modifierFlags.contains(.shift) || unit != nil
            ? selection(to: page, at: point) : nil
        setCurrentSelection(initial, animate: false)
        var dragged = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type == .leftMouseDragged {
            documentView?.autoscroll(with: next)
            let current = convert(next.locationInWindow, from: nil)
            if !dragged, hypot(current.x - location.x, current.y - location.y) < 3 { continue }
            dragged = true
            guard let target = self.page(for: current, nearest: true) else { continue }
            setCurrentSelection(selection(to: target, at: convert(current, to: target)), animate: false)
        }
        return true
    }
}

/// A place between two characters of a page's text: before the character at `index`.
struct TextCaret {
    let page: PDFPage
    let pageIndex: Int
    let index: Int

    static func < (a: TextCaret, b: TextCaret) -> Bool {
        (a.pageIndex, a.index) < (b.pageIndex, b.index)
    }

    /// The text between two carets, in either order; nil if they are the same.
    static func selection(from a: TextCaret, to b: TextCaret, in document: PDFDocument) -> PDFSelection? {
        let (start, end) = a < b ? (a, b) : (b, a)
        guard start < end else { return nil }
        if end.index == 0, end.pageIndex > start.pageIndex, let previous = document.page(at: end.pageIndex - 1) {
            return document.selection(from: start.page, atCharacterIndex: start.index,
                                      to: previous, atCharacterIndex: max(previous.numberOfCharacters - 1, 0))
        }
        return document.selection(from: start.page, atCharacterIndex: start.index,
                                  to: end.page, atCharacterIndex: end.index - 1)
    }

    /// Where a selection begins.
    static func start(of selection: PDFSelection, in document: PDFDocument) -> TextCaret? {
        for page in selection.pages.sorted(by: { document.index(for: $0) < document.index(for: $1) }) {
            let starts = (0..<selection.numberOfTextRanges(on: page))
                .map { selection.range(at: $0, on: page) }
                .filter { $0.location != NSNotFound && $0.length > 0 }
                .map(\.location)
            if let first = starts.min() {
                return TextCaret(page: page, pageIndex: document.index(for: page), index: first)
            }
        }
        return nil
    }
}

/// The characters of text on pages and where they are, without the stand-ins PDFKit puts into
/// the text for pictures. The places come from PDFKit's selections, which are drawn where the
/// text is; `characterBounds(at:)` is off sideways in some documents. Collected once per page
/// and line during a drag.
struct TextCharacters {
    /// Object replacement character, PDFKit's stand-in for a picture in a page's text.
    private static let picture: unichar = 0xFFFC

    private struct Line {
        let range: NSRange
        let box: CGRect
    }

    private var lines: [ObjectIdentifier: [Line]] = [:]
    private var boxes: [ObjectIdentifier: [Int: CGRect]] = [:]

    /// The character of text at a point, if the point is on its line or close to it, as in the
    /// indent of a paragraph or the margin beside a line.
    mutating func index(on page: PDFPage, at point: CGPoint) -> Int? {
        guard let nearest = nearest(on: page, to: point), nearest.distance <= 10 else { return nil }
        return nearest.index
    }

    /// The word a character belongs to, for a double click: letters and digits, with
    /// apostrophes and hyphens inside a word. A character outside a word stands alone.
    func word(on page: PDFPage, around index: Int) -> NSRange {
        let text = (page.string ?? "") as NSString
        let letters = CharacterSet.alphanumerics
        let joiners = CharacterSet(charactersIn: "'’-")
        func isLetter(_ i: Int) -> Bool {
            UnicodeScalar(text.character(at: i)).map(letters.contains) ?? false
        }
        func joins(_ i: Int) -> Bool {
            (UnicodeScalar(text.character(at: i)).map(joiners.contains) ?? false)
                && i > 0 && i + 1 < text.length && isLetter(i - 1) && isLetter(i + 1)
        }
        guard index < text.length, isLetter(index) || joins(index) else { return NSRange(location: index, length: 1) }
        var start = index, end = index + 1
        while start > 0, isLetter(start - 1) || joins(start - 1) { start -= 1 }
        while end < text.length, isLetter(end) || joins(end) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    /// The line a character is on, for a triple click.
    mutating func line(on page: PDFPage, containing index: Int) -> NSRange? {
        lines(of: page).first { NSLocationInRange(index, $0.range) }?.range
    }

    /// The caret before or after a character, whichever half of it the point is in.
    mutating func caret(on page: PDFPage, at point: CGPoint, character index: Int) -> Int {
        point.x > box(of: index, on: page).midX ? index + 1 : index
    }

    /// The caret at the character of text nearest to a point.
    mutating func nearestCaret(on page: PDFPage, pageIndex: Int, at point: CGPoint) -> TextCaret? {
        guard let nearest = nearest(on: page, to: point) else { return nil }
        return TextCaret(page: page, pageIndex: pageIndex,
                         index: caret(on: page, at: point, character: nearest.index))
    }

    /// The character nearest to a point on the line nearest to it, with the distance of the
    /// point from that line.
    private mutating func nearest(on page: PDFPage, to point: CGPoint) -> (index: Int, distance: CGFloat)? {
        func distance(_ box: CGRect) -> CGFloat {
            hypot(max(box.minX - point.x, 0, point.x - box.maxX), max(box.minY - point.y, 0, point.y - box.maxY))
        }
        guard let line = lines(of: page).min(by: { distance($0.box) < distance($1.box) }) else { return nil }
        let text = (page.string ?? "") as NSString
        var best: (index: Int, distance: CGFloat)?
        for index in line.range.location..<min(NSMaxRange(line.range), text.length) {
            let character = text.character(at: index)
            guard character != Self.picture, character != 10, character != 13 else { continue }
            let box = box(of: index, on: page)
            guard box.width > 0 else { continue }
            let dx = max(box.minX - point.x, 0, point.x - box.maxX)
            if dx < best?.distance ?? .infinity { best = (index, dx) }
            if dx == 0 { break }
        }
        return best.map { ($0.index, distance(line.box)) }
    }

    private mutating func lines(of page: PDFPage) -> [Line] {
        if let known = lines[ObjectIdentifier(page)] { return known }
        let text = (page.string ?? "") as NSString
        let all = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters))
        let found = (all?.selectionsByLine() ?? []).compactMap { line -> Line? in
            let ranges = (0..<line.numberOfTextRanges(on: page)).map { line.range(at: $0, on: page) }
                .filter { $0.location != NSNotFound && $0.length > 0 }
            guard let first = ranges.map(\.location).min(), let end = ranges.map({ NSMaxRange($0) }).max(),
                  end <= text.length
            else { return nil }
            let range = NSRange(location: first, length: end - first)
            // A line of nothing but pictures is no text.
            let blank = CharacterSet.whitespacesAndNewlines
            guard (range.location..<NSMaxRange(range)).contains(where: {
                let character = text.character(at: $0)
                return character != Self.picture && !(UnicodeScalar(character).map(blank.contains) ?? false)
            }) else { return nil }
            return Line(range: range, box: line.bounds(for: page))
        }
        lines[ObjectIdentifier(page)] = found
        return found
    }

    private mutating func box(of index: Int, on page: PDFPage) -> CGRect {
        if let known = boxes[ObjectIdentifier(page)]?[index] { return known }
        let box = page.selection(for: NSRange(location: index, length: 1))?.bounds(for: page) ?? .zero
        boxes[ObjectIdentifier(page), default: [:]][index] = box
        return box
    }
}

