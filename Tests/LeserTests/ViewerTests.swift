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

/// The view of a document: page numbers, going to a page, suggested bookmark names, search,
/// printing.
@MainActor
@Suite(.serialized)
struct ViewerTests {
    /// Six pages: two in roman numerals, then 1 to 4.
    private func labelled() -> ViewerModel {
        var pdf = TestPDF(texts: ["Titel", "Inhalt", "Eins", "Zwei", "Drei", "Vier"])
        pdf.pageLabels = "0 << /S /r >> 2 << /S /D >>"
        return ViewerModel(document: pdf.document(), fileURL: nil)
    }

    /// Shows a model's view in a window out of sight, for what needs a laid-out view.
    private func show(_ model: ViewerModel) async -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 600, height: 800),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        model.pdfView.frame = window.contentLayoutRect
        model.pdfView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(model.pdfView)
        window.orderFrontRegardless()
        model.performInitialLayoutIfReady()
        _ = await eventually { model.pdfView.currentPage != nil }
        return window
    }

    // MARK: Page numbers

    @Test func labelsAsPrintedOnThePages() {
        let model = labelled()
        #expect(model.label(ofPage: 0) == "i")
        #expect(model.label(ofPage: 2) == "1")
        #expect(model.label(ofPage: 5) == "4")
        #expect(model.hasPageLabels)
    }

    @Test func goToPageByLabelOrPosition() {
        let model = labelled()
        #expect(model.pageIndex(for: "ii") == 1)
        #expect(model.pageIndex(for: "II") == 1)
        #expect(model.pageIndex(for: " 3 ") == 4)
        // Not a label: the position in the document.
        #expect(model.pageIndex(for: "6") == 5)
        #expect(model.pageIndex(for: "7") == nil)
        #expect(model.pageIndex(for: "") == nil)
        #expect(model.pageIndex(for: "x") == nil)
    }

    @Test func documentWithoutLabelsCountsPositions() {
        let model = ViewerModel(document: TestPDF(texts: ["Eins", "Zwei"]).document(), fileURL: nil)
        #expect(!model.hasPageLabels)
        #expect(model.label(ofPage: 1) == "2")
        #expect(model.pageIndex(for: "2") == 1)
    }

    // MARK: Bookmark names

    private func outlined() -> ViewerModel {
        var pdf = TestPDF(texts: ["Eins", "Zwei", "Drei"])
        pdf.outline = [("Kapitel A", 0, 40), ("Kapitel B", 1, 40), ("Abschnitt B2", 1, 300)]
        return ViewerModel(document: pdf.document(), fileURL: nil)
    }

    @Test func bookmarkNamedAfterTheSectionOfThePlace() throws {
        let model = outlined()
        let height = TestPDF.pageSize.height
        // Below "Abschnitt B2": that is where the place lies; the other entries of the page and
        // the page itself are offered as well.
        let low = try #require(model.bookmarkDraft(page: 1, point: CGPoint(x: 0, y: height - 400)))
        #expect(low.names.prefix(2) == ["Abschnitt B2", "Kapitel B"])
        #expect(low.names.count == 3 && low.names[2].contains("2"))
        // At the very top of the page, above "Kapitel B": still in chapter A.
        let top = try #require(model.bookmarkDraft(page: 1, point: CGPoint(x: 0, y: height - 10)))
        #expect(top.names.first == "Kapitel A")
        #expect(top.names.contains("Kapitel B"))
    }

    // MARK: Search

    /// Matches on the first, second, fifth and sixth page.
    private func searchable() -> ViewerModel {
        ViewerModel(document: TestPDF(texts: ["Ein Treffer", "Noch ein Treffer", "Nichts", "Nichts",
                                               "Hier ein Treffer", "Letzter Treffer"]).document(), fileURL: nil)
    }

    private func search(_ text: String, in model: ViewerModel) async {
        model.searchText = text
        model.performSearch()
        _ = await eventually { !model.isFinding }
        // Matches found before the first one shown arrive a moment later.
        try? await Task.sleep(for: .milliseconds(200))
    }

    @Test func searchStartsOnTheCurrentPage() async throws {
        try await keepingDefaults([Preferences.searchFromCurrentPageKey]) {
            UserDefaults.standard.set(true, forKey: Preferences.searchFromCurrentPageKey)
            let model = searchable()
            let window = await show(model)
            defer { window.close() }
            model.goToPage(2)
            #expect(await eventually { model.pageIndex == 2 })

            await search("treffer", in: model)
            #expect(model.matches.map(\.pageLabel) == ["1", "2", "5", "6"])
            // The first match on the current page or after it is shown, not the first of all.
            #expect(model.currentMatchIndex == 2)
            model.nextMatch()
            #expect(model.currentMatchIndex == 3)
            model.nextMatch()
            #expect(model.currentMatchIndex == 0)
            model.previousMatch()
            #expect(model.currentMatchIndex == 3)
        }
    }

    @Test func searchFromTheStartIfSoSet() async throws {
        try await keepingDefaults([Preferences.searchFromCurrentPageKey]) {
            UserDefaults.standard.set(false, forKey: Preferences.searchFromCurrentPageKey)
            let model = searchable()
            let window = await show(model)
            defer { window.close() }
            model.goToPage(3)
            #expect(await eventually { model.pageIndex == 3 })
            await search("Treffer", in: model)
            #expect(model.currentMatchIndex == 0)
        }
    }

    @Test func searchIgnoresCaseAndAccents() async {
        let model = ViewerModel(document: TestPDF(texts: ["Die Übergröße zählt."]).document(), fileURL: nil)
        let window = await show(model)
        defer { window.close() }
        await search("ubergrosse", in: model)
        #expect(model.matches.count == 1)
        await search("", in: model)
        #expect(model.matches.isEmpty)
    }

    // MARK: Printing

    @Test func printOptionsGoIntoThePrintSettings() async {
        await keepingDefaults(["printScaling", "printAutoRotate"]) {
            let info = NSPrintInfo()
            let options = PrintOptions(printInfo: info)
            options.scalingMode = PDFPrintScalingMode.pageScaleToFit.rawValue
            options.rotates = false
            #expect(info.dictionary()[NSPrintInfo.AttributeKey("PDFPrintScalingMode")] as? Int == PDFPrintScalingMode.pageScaleToFit.rawValue)
            #expect(info.dictionary()[NSPrintInfo.AttributeKey("PDFPrintAutoRotate")] as? Bool == false)
            // Remembered for the next print.
            #expect(PrintOptions.scaling == .pageScaleToFit)
            #expect(!PrintOptions.autoRotate)

            UserDefaults.standard.removeObject(forKey: "printScaling")
            UserDefaults.standard.removeObject(forKey: "printAutoRotate")
            #expect(PrintOptions.scaling == .pageScaleNone)
            #expect(PrintOptions.autoRotate)
        }
    }
}
