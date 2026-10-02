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
import Testing
@testable import Leser

/// Page references in the text: which count, where they lead, and which are left alone.
@MainActor
@Suite(.serialized)
struct PageReferenceTests {
    typealias Target = PageReferences.Reference.Target

    /// The references on the first page of a document whose first page holds `text`, with
    /// page numbers printed at the foot of every page.
    private func targets(_ runs: [TestPDF.Run], pages: Int = 12, title: String? = nil,
                         name: String? = nil, change: (inout TestPDF) -> Void = { _ in }) -> [Target] {
        var pdf = TestPDF(pages: [TestPDF.Page(text: runs)] + Array(repeating: TestPDF.Page(text: [TestPDF.Run(text: "Text")]), count: pages - 1),
                          title: title)
        change(&pdf)
        let document = pdf.document()
        return PageReferences(document: document, name: name).references(on: document.page(at: 0)!).map(\.target)
    }

    private func targets(_ text: String, pages: Int = 12, title: String? = nil, name: String? = nil,
                         change: (inout TestPDF) -> Void = { _ in }) -> [Target] {
        targets([TestPDF.Run(text: text)], pages: pages, title: title, name: name, change: change)
    }

    // MARK: Into the document itself

    @Test func seeAndBrackets() {
        #expect(targets("Mehr dazu siehe Seite 5 im Anhang.") == [.page(4)])
        #expect(targets("Die Regel (Seite 7) gilt immer.") == [.page(6)])
        #expect(targets("The rule (page 3) always applies.") == [.page(2)])
        #expect(targets("Details are on page 8, see page 9 too.") == [.page(7), .page(8)])
    }

    @Test func leadInRightAfterBracketOrQuote() {
        #expect(targets("Wie beschrieben (siehe Seite 6) und „siehe Seite 7“.") == [.page(5), .page(6)])
    }

    @Test func rangeGivesEveryPage() {
        #expect(targets("Alles dazu steht auf den Seiten 3–4.") == [.page(2), .page(3)])
    }

    @Test func sectionOfThisDocumentSpelledOut() {
        // A section title before a spelled-out "Seite" belongs to this document.
        #expect(targets("Die Belohnung (Die Reise nach Norden, Seite 6) folgt.") == [.page(5)])
        #expect(targets("Wie erklärt (siehe „Die Reise“, Seite 6).") == [.page(5)])
    }

    @Test func articleBeforeNameMeansSection() {
        #expect(targets("Explained on page 6 in the Glossary of terms.") == [.page(5)])
    }

    @Test func ownTitleAlsoWithSeriesName() {
        #expect(targets("As shown (Field Guide, page 6) before.", title: "Field Guide") == [.page(5)])
        #expect(targets("As shown (Explorer Series Field Guide, page 6).", title: "Field Guide") == [.page(5)])
        #expect(targets("As shown (Field Guide, page 6).", name: "Field Guide.pdf") == [.page(5)])
    }

    @Test func pagesThatDoNotExistOrAreThisOne() {
        #expect(targets("Siehe Seite 50 für mehr.").isEmpty)
        #expect(targets("Siehe Seite 1 für mehr.").isEmpty)
        #expect(targets("Siehe Seite 0 für mehr.").isEmpty)
    }

    @Test func numbersWithoutLeadInStayText() {
        #expect(targets("Wir zählen bis Seite 5 nicht mit, Nr, S. 5 auch nicht.").isEmpty)
        #expect(targets("Der Wert (DC 25) zählt nicht.").isEmpty)
    }

    // MARK: Page numbers

    @Test func positionCountsOnlyWhereThePageShowsIt() {
        // No page labels and a cover before page 1: the fifth page prints "4", so position 5
        // is not page 5, and the reference is left alone rather than leading astray.
        #expect(targets("Siehe Seite 5.") { $0.printedNumber = { $0 == 0 ? nil : "\($0)" } }.isEmpty)
        // Printed numbers matching the position.
        #expect(targets("Siehe Seite 5.") == [.page(4)])
        // Nothing printed at all.
        #expect(targets("Siehe Seite 5.") { $0.printedNumber = { _ in nil } }.isEmpty)
    }

    @Test func pageLabelsDecide() {
        // Two pages in roman numerals, then 1, 2, …: page 3 is the fifth page. Labels count
        // without a printed number.
        let found = targets("Siehe Seite 3.") {
            $0.pageLabels = "0 << /S /r >> 2 << /S /D >>"
            $0.printedNumber = { _ in nil }
        }
        #expect(found == [.page(4)])
    }

    @Test func numberPrintedTwiceOnTopOfItself() {
        // Text drawn twice, as some publishers do, reads "1919"; a real "33" must still count.
        let doubled: (inout TestPDF) -> Void = { $0.printedNumber = { "\($0 + 1)\($0 + 1)" } }
        #expect(targets("Siehe Seite 5.", pages: 40, change: doubled) == [.page(4)])
        #expect(targets("Siehe Seite 33.", pages: 40) == [.page(32)])
    }

    @Test func realLinksComeFirst() {
        let found = targets("Siehe Seite 5 dort.") {
            $0.links = [TestPDF.Link(page: 0, over: "Seite 5", action: .url("https://example.com"))]
        }
        #expect(found.isEmpty)
    }

    // MARK: Into other documents

    @Test func titleAndAbbreviatedPage() {
        #expect(targets("Die Regel (Handbuch: Technik, S. 284) gilt.") == [.document(title: "Handbuch: Technik", number: 284)])
        #expect(targets("Wie im Atlas der Sterne (S. 147) steht.") == [.document(title: "Atlas der Sterne", number: 147)])
        #expect(targets("Wie (Handbuch: Technik 2, S. 12) sagt.") == [.document(title: "Handbuch: Technik 2", number: 12)])
    }

    @Test func titleAfterThePage() {
        #expect(targets("Die Werte auf S. 8 in Handbuch: FAQ gelten.") == [.document(title: "Handbuch: FAQ", number: 8)])
        #expect(targets("See the rules on page 8 of Field Guide now.") == [.document(title: "Field Guide", number: 8)])
        #expect(targets("Die Jagd auf Seite 192 der Handbuch: Technik. Weiter.") == [.document(title: "Handbuch: Technik", number: 192)])
        #expect(targets("Die Werte (auf S. 8 in Handbuch: FAQ): vier Leute.") == [.document(title: "Handbuch: FAQ", number: 8)])
        #expect(targets("As explained on page 278 of GM Guide. More.") == [.document(title: "GM Guide", number: 278)])
    }

    @Test func singleNounAfterPageIsPartOfThisDocument() {
        // German capitalises every noun: "im Anhang" is a part of this document, not a book.
        #expect(targets("Mehr dazu siehe Seite 5 im Anhang.") == [.page(4)])
        #expect(targets("As explained on page 6 in Chapter 8: Playing for more.") == [.page(5)])
    }

    @Test func titleAfterEnglishQuote() {
        #expect(targets("Such as “(Atlas of the Stars, p. 42)” here.") == [.document(title: "Atlas of the Stars", number: 42)])
    }

    @Test func headingInCapitalsIsNoTitle() {
        #expect(targets("WICHTIGER HINWEIS Handbuch: Technik, S. 12") == [.document(title: "Handbuch: Technik", number: 12)])
    }

    @Test func titleHyphenatedAtLineBreak() {
        let pdf = TestPDF(pages: [
            TestPDF.Page(lines: [
                TestPDF.Line(runs: [TestPDF.Run(text: "Die Regel (Handbuch: Tech-")], x: 40, top: 60),
                TestPDF.Line(runs: [TestPDF.Run(text: "nik, S. 12) gilt.")], x: 40, top: 74),
            ]),
        ] + Array(repeating: TestPDF.Page(text: [TestPDF.Run(text: "Text")]), count: 3))
        let document = pdf.document()
        let found = PageReferences(document: document).references(on: document.page(at: 0)!).map(\.target)
        #expect(found == [.document(title: "Handbuch: Technik", number: 12)])
    }

    @Test func titleInItalicsWithoutPageWord() {
        let italic: [TestPDF.Run] = [
            TestPDF.Run(text: "Sargassum heaps ("),
            TestPDF.Run(text: "Field Guide", font: TestFont.italic()),
            TestPDF.Run(text: " 295) appear."),
        ]
        #expect(targets(italic) == [.document(title: "Field Guide", number: 295)])
        // The same in upright type is a value, not a book.
        #expect(targets("Sargassum heaps (Field Guide 295) appear.").isEmpty)
    }

    @Test func titleAssignedToAFileNeedsNoItalics() async throws {
        let store = OtherDocuments.shared
        let file = TestPDF(texts: ["Anderes"]).write(named: "Field Guide.pdf")
        store.assign(file, to: "Field Guide")
        defer { store.assignments[OtherDocuments.key(for: "Field Guide")].map(store.remove) }
        #expect(targets("Sargassum heaps (Field Guide 295) appear.") == [.document(title: "Field Guide", number: 295)])
    }

    // MARK: Where a reference lies

    @Test func referenceAtAPoint() throws {
        let document = TestPDF(texts: ["Mehr dazu siehe Seite 5 im Anhang."] + Array(repeating: "Text", count: 9)).document()
        let page = try #require(document.page(at: 0))
        let references = PageReferences(document: document)
        let reference = try #require(references.references(on: page).first)
        let bounds = try #require(reference.bounds.first)
        #expect(page.selection(for: bounds)?.string?.contains("Seite 5") == true)
        #expect(references.reference(at: CGPoint(x: bounds.midX, y: bounds.midY), on: page)?.target == .page(4))
        #expect(references.reference(at: CGPoint(x: bounds.minX - 30, y: bounds.midY), on: page) == nil)
    }

    @Test func pageIndexForNumber() {
        let labelled = TestPDF(texts: Array(repeating: "Text", count: 6))
        var pdf = labelled
        pdf.pageLabels = "0 << /S /r >> 2 << /S /D >>"
        let references = PageReferences(document: pdf.document())
        #expect(references.pageIndex(forNumber: 1) == 2)
        #expect(references.pageIndex(forNumber: 4) == 5)
        #expect(references.pageIndex(forNumber: 5) == nil)
    }
}
