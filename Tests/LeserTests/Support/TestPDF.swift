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

/// Fonts for the text of test documents.
enum TestFont {
    static func regular(_ size: CGFloat = 11) -> NSFont { NSFont(name: "Helvetica", size: size)! }
    static func bold(_ size: CGFloat = 11) -> NSFont { NSFont(name: "Helvetica-Bold", size: size)! }
    static func italic(_ size: CGFloat = 11) -> NSFont { NSFont(name: "Helvetica-Oblique", size: size)! }
}

/// A small PDF made for a test: text where the test needs it, page numbers printed at the foot,
/// and, where asked for, page labels, links and a particular document identifier. The parts
/// PDFKit cannot write, page labels, the file of a link into another file and the identifier,
/// are put into the file afterwards.
struct TestPDF {
    /// Text in one font.
    struct Run {
        var text: String
        var font: NSFont = TestFont.regular()
        var color: NSColor = .black
    }

    /// One line placed exactly: left edge and top, measured from the top of the page.
    struct Line {
        var runs: [Run]
        var x: CGFloat
        var top: CGFloat
    }

    struct Page {
        /// Text set into the page's text area, wrapped as it comes.
        var text: [Run] = []
        /// Lines placed one by one, for tests about the layout of lines.
        var lines: [Line] = []
    }

    enum Identifier {
        /// The identifier CoreGraphics makes up, different for every file.
        case generated
        /// No identifier at all.
        case none
        case bytes([UInt8])
    }

    enum Action {
        case url(String)
        /// A link into another file: its name and the index of the page.
        case file(String, page: Int)
    }

    struct Link {
        var page: Int
        /// The text the link lies over; it has to stand on one line.
        var over: String
        var action: Action
    }

    static let pageSize = CGSize(width: 420, height: 595)
    static let margin: CGFloat = 40

    var pages: [Page]
    var title: String?
    /// The number printed at the foot of each page, by index; nil prints none. By default the
    /// position, starting at 1.
    var printedNumber: (Int) -> String? = { "\($0 + 1)" }
    /// The entries of the page label tree, as in a PDF: "0 << /S /r >> 2 << /S /D >>".
    var pageLabels: String?
    var identifier = Identifier.generated
    var links: [Link] = []
    /// Entries of the outline: title (plain letters only), page index, and how far from the
    /// top of the page.
    var outline: [(title: String, page: Int, top: CGFloat)] = []

    init(pages: [Page], title: String? = nil) {
        self.pages = pages
        self.title = title
    }

    /// One page per text, in the body font.
    init(texts: [String], title: String? = nil) {
        self.init(pages: texts.map { Page(text: [Run(text: $0)]) }, title: title)
    }

    // MARK: Making the file

    func data() -> Data {
        var data = drawn()
        if !links.isEmpty { data = linked(data) }
        return patched(data)
    }

    /// The document as Leser opens it: from its data, without a file behind it.
    func document() -> PDFDocument {
        PDFDocument(data: data())!
    }

    /// The document written to a file of its own in the temporary folder.
    func write(named name: String = "Test.pdf") -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LeserTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try! data().write(to: url)
        return url
    }

    private func drawn() -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: Self.pageSize)
        var info: [String: Any] = [:]
        if let title { info[kCGPDFContextTitle as String] = title }
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, info as CFDictionary)!
        for (index, page) in pages.enumerated() {
            context.beginPDFPage(nil)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            if !page.text.isEmpty {
                let area = CGRect(x: Self.margin, y: 70, width: Self.pageSize.width - 2 * Self.margin,
                                  height: Self.pageSize.height - 70 - Self.margin)
                Self.attributed(page.text).draw(with: area, options: [.usesLineFragmentOrigin])
            }
            for line in page.lines {
                let string = Self.attributed(line.runs)
                let height = line.runs.map { $0.font.ascender - $0.font.descender }.max() ?? 12
                string.draw(at: CGPoint(x: line.x, y: Self.pageSize.height - line.top - height))
            }
            if let number = printedNumber(index) {
                let string = NSAttributedString(string: number, attributes: [.font: TestFont.regular(9)])
                string.draw(at: CGPoint(x: (Self.pageSize.width - string.size().width) / 2, y: 30))
            }
            context.endPDFPage()
        }
        // The outline as CoreGraphics writes it, to the page only; `patched` adds the place.
        // PDFKit does not write an outline at all.
        if !outline.isEmpty {
            let children = outline.map { ["Title": $0.title, "Destination": $0.page + 1] as [String: Any] }
            CGPDFContextSetOutline(context, ["Children": children] as CFDictionary)
        }
        context.closePDF()
        return data as Data
    }

    private static func attributed(_ runs: [Run]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in runs {
            result.append(NSAttributedString(string: run.text, attributes: [.font: run.font, .foregroundColor: run.color]))
        }
        return result
    }

    /// Adds the links through PDFKit, which writes a link into another file without its file
    /// and page; `patched` fills those in.
    private func linked(_ data: Data) -> Data {
        let document = PDFDocument(data: data)!
        for link in links {
            guard let page = document.page(at: link.page),
                  let selection = document.findString(link.over, withOptions: []).first(where: { $0.pages.contains(page) })
            else { fatalError("Linktext „\(link.over)“ nicht auf Seite \(link.page) gefunden") }
            let annotation = PDFAnnotation(bounds: selection.bounds(for: page), forType: .link, withProperties: nil)
            switch link.action {
            case .url(let string): annotation.action = PDFActionURL(url: URL(string: string)!)
            case .file(let name, let index):
                annotation.action = PDFActionRemoteGoTo(pageIndex: index, at: .zero, fileURL: URL(string: name)!)
            }
            page.addAnnotation(annotation)
        }
        return document.dataRepresentation()!
    }

    // MARK: Changing the file afterwards

    private func patched(_ data: Data) -> Data {
        var text = String(data: data, encoding: .isoLatin1)!
        for link in links {
            guard case .file(let name, let index) = link.action else { continue }
            guard let range = text.range(of: "/S /GoToR >>") else { fatalError("Link in andere Datei fehlt") }
            text.replaceSubrange(range, with: "/S /GoToR /F (\(name)) /D [ \(index) /Fit ] >>")
        }
        for entry in outline {
            // The place in the entry with this title; its other keys may stand in between.
            let pattern = #"/XYZ null null null(\s*\][^>]*?/Title\s*\("# + NSRegularExpression.escapedPattern(for: entry.title) + #"\))"#
            let expression = try! NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: (text as NSString).length)
            guard expression.firstMatch(in: text, range: range) != nil else {
                fatalError("Gliederungseintrag „\(entry.title)“ nicht gefunden")
            }
            text = expression.stringByReplacingMatches(in: text, range: range,
                                                       withTemplate: "/XYZ 0 \(Self.pageSize.height - entry.top) null$1")
        }
        if let pageLabels {
            guard let range = text.range(of: "/Type /Catalog") else { fatalError("Katalog fehlt") }
            text.replaceSubrange(range, with: "/Type /Catalog /PageLabels << /Nums [ \(pageLabels) ] >>")
        }
        switch identifier {
        case .generated: break
        case .none: text = Self.replacing(#"/ID\s*\[[^\]]*\]"#, in: text, with: "")
        case .bytes(let bytes):
            let hex = bytes.map { String(format: "%02x", $0) }.joined()
            text = Self.replacing(#"/ID\s*\[[^\]]*\]"#, in: text, with: "/ID [ <\(hex)> <\(hex)> ]")
        }
        return Self.withNewCrossReferences(text)
    }

    private static func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        let expression = try! NSRegularExpression(pattern: pattern)
        return expression.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length),
                                                   withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
    }

    /// The table of object positions written anew, as the objects moved. Latin-1 keeps every
    /// byte as one character, so lengths in the text are lengths in the file.
    private static func withNewCrossReferences(_ text: String) -> Data {
        let body = String(text[..<text.range(of: "\nxref\n", options: .backwards)!.lowerBound]) + "\n"
        let trailer = String(text[text.range(of: "trailer", options: .backwards)!.lowerBound...])
        func matches(_ pattern: String, in string: String) -> [NSTextCheckingResult] {
            try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
                .matches(in: string, range: NSRange(location: 0, length: (string as NSString).length))
        }
        let sizeMatch = matches(#"/Size (\d+)"#, in: trailer)[0]
        let size = Int((trailer as NSString).substring(with: sizeMatch.range(at: 1)))!
        var offsets = [Int](repeating: 0, count: size)
        for match in matches(#"^(\d+) 0 obj"#, in: body) {
            let number = Int((body as NSString).substring(with: match.range(at: 1)))!
            if number < size { offsets[number] = match.range.location }
        }
        var table = "xref\n0 \(size)\n0000000000 65535 f \n"
        for number in 1..<size {
            table += String(format: "%010d 00000 %@ \n", offsets[number], offsets[number] > 0 ? "n" : "f")
        }
        let start = matches(#"startxref\s+\d+"#, in: trailer)[0]
        let tail = (trailer as NSString).replacingCharacters(in: start.range, with: "startxref\n\((body as NSString).length)")
        return (body + table + tail).data(using: .isoLatin1)!
    }
}

/// Keeps settings a test changes as they were: the tests run inside the debug build of the
/// app, with its settings.
@MainActor
func keepingDefaults<T>(_ keys: [String], _ body: () async throws -> T) async rethrows -> T {
    let defaults = UserDefaults.standard
    let saved = keys.map { ($0, defaults.object(forKey: $0)) }
    defer {
        for (key, value) in saved {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }
    return try await body()
}

/// Waits until a condition holds, for work PDFKit and the app do on later turns of the run loop.
@MainActor
func eventually(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let end = clock.now + timeout
    while !condition() {
        if clock.now > end { return false }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return true
}
