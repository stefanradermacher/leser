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
import Testing
@testable import Leser

/// The tools: text selection by characters, the rectangular selection and the choice of tool.
@MainActor
@Suite(.serialized)
struct ToolTests {
    private static let first = "Die Über-Größe hat’s. Ende"
    private static let second = "Zweite Zeile"

    /// One page with two lines, the first 100 points from the top, at x = 60.
    private func page() -> (PDFDocument, PDFPage) {
        var pdf = TestPDF(pages: [TestPDF.Page(lines: [
            TestPDF.Line(runs: [TestPDF.Run(text: Self.first)], x: 60, top: 100),
            TestPDF.Line(runs: [TestPDF.Run(text: Self.second)], x: 60, top: 130),
        ])])
        pdf.printedNumber = { _ in nil }
        let document = pdf.document()
        return (document, document.page(at: 0)!)
    }

    private func text(of page: PDFPage, _ range: NSRange) -> String {
        ((page.string ?? "") as NSString).substring(with: range)
    }

    // MARK: Text selection

    @Test func doubleClickTakesTheWholeWord() throws {
        let (_, page) = page()
        let characters = TextCharacters()
        let string = (page.string ?? "") as NSString
        let inWord = string.range(of: "Größe").location + 2
        #expect(text(of: page, characters.word(on: page, around: inWord)) == "Über-Größe")
        let apostrophe = string.range(of: "’").location
        #expect(text(of: page, characters.word(on: page, around: apostrophe)) == "hat’s")
        let stop = string.range(of: ".").location
        #expect(text(of: page, characters.word(on: page, around: stop)) == ".")
    }

    @Test func tripleClickTakesTheLine() throws {
        let (_, page) = page()
        var characters = TextCharacters()
        let index = ((page.string ?? "") as NSString).range(of: "Zeile").location
        let found = characters.line(on: page, containing: index)
        let line = try #require(found)
        #expect(text(of: page, line).trimmingCharacters(in: .whitespacesAndNewlines) == Self.second)
    }

    @Test func dragFromTheMarginStartsAtTheLine() throws {
        let (document, page) = page()
        var characters = TextCharacters()
        let height = TestPDF.pageSize.height
        // Left of the first line, in the margin, and right of its end.
        let left = characters.nearestCaret(on: page, pageIndex: 0, at: CGPoint(x: 52, y: height - 106))
        let right = characters.nearestCaret(on: page, pageIndex: 0, at: CGPoint(x: 400, y: height - 106))
        let start = try #require(left), end = try #require(right)
        let inMargin = characters.index(on: page, at: CGPoint(x: 52, y: height - 106))
        #expect(inMargin != nil)
        let selection = try #require(TextCaret.selection(from: start, to: end, in: document))
        #expect(selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) == Self.first)
        // Far from any text, the click is left to PDFKit.
        let farAway = characters.index(on: page, at: CGPoint(x: 200, y: 100))
        #expect(farAway == nil)
    }

    @Test func selectionWorksInBothDirections() throws {
        let (document, page) = page()
        let a = TextCaret(page: page, pageIndex: 0, index: 4)
        let b = TextCaret(page: page, pageIndex: 0, index: 14)
        let forward = try #require(TextCaret.selection(from: a, to: b, in: document))
        let backward = try #require(TextCaret.selection(from: b, to: a, in: document))
        #expect(forward.string == "Über-Größe")
        #expect(backward.string == forward.string)
        #expect(TextCaret.selection(from: a, to: a, in: document) == nil)
    }

    @Test func shiftClickExtendsFromTheStart() throws {
        let (document, page) = page()
        let selection = try #require(page.selection(for: NSRange(location: 4, length: 5)))
        let start = try #require(TextCaret.start(of: selection, in: document))
        #expect(start.index == 4)
    }

    // MARK: Rectangular selection

    @Test func areaIsCopiedAsAPicture() throws {
        let (_, page) = page()
        let area = AreaSelection(page: page, rect: CGRect(x: 50, y: 400, width: 100, height: 50))
        let image = try #require(area.image(box: .mediaBox, scale: 2))
        #expect(image.width == 200 && image.height == 100)

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        } ?? []
        defer {
            pasteboard.clearContents()
            if !saved.isEmpty { pasteboard.writeObjects(saved) }
        }
        area.copy(box: .mediaBox)
        #expect(pasteboard.types?.contains(.png) == true)
        #expect(pasteboard.types?.contains(.tiff) == true)
        #expect(pasteboard.types?.contains(.pdf) == false)
    }

    @Test func veryLargeAreasAreScaledDown() throws {
        let (_, page) = page()
        let area = AreaSelection(page: page, rect: page.bounds(for: .mediaBox))
        let image = try #require(area.image(box: .mediaBox, scale: 40))
        #expect(max(image.width, image.height) <= 8000)
    }

    // MARK: Choice of tool

    @Test func toolIsRememberedForNewWindows() async {
        await keepingDefaults(["readerTool"]) {
            UserDefaults.standard.removeObject(forKey: "readerTool")
            #expect(ReaderTool.preferred == .text)
            let state = ReaderState(primary: ViewerModel(document: page().0, fileURL: nil), fileURL: nil)
            state.tool = .hand
            #expect(state.primary.pdfView.tool == .hand)
            #expect(ReaderTool.preferred == .hand)
            let next = ReaderState(primary: ViewerModel(document: page().0, fileURL: nil), fileURL: nil)
            #expect(next.tool == .hand && next.primary.pdfView.tool == .hand)
            state.stop()
            next.stop()
        }
    }

    @Test func changingTheToolClearsTheArea() {
        let (document, page) = page()
        let view = ReaderPDFView()
        view.document = document
        view.tool = .area
        view.areaSelection = AreaSelection(page: page, rect: CGRect(x: 10, y: 10, width: 50, height: 50))
        view.tool = .text
        #expect(view.areaSelection == nil)
    }
}
