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

/// Copied text: lines joined into paragraphs again, as far as the layout tells.
@MainActor
struct ParagraphTextTests {
    typealias Run = TestPDF.Run
    typealias Line = TestPDF.Line

    /// The text of a page with lines placed as given, copied in full.
    private func copied(_ lines: [Line]) -> NSAttributedString {
        var pdf = TestPDF(pages: [TestPDF.Page(lines: lines)])
        pdf.printedNumber = { _ in nil }
        let document = pdf.document()
        let page = document.page(at: 0)!
        let selection = page.selection(for: page.bounds(for: .mediaBox))!
        return ParagraphText.text(of: selection)
    }

    /// Lines in one column below each other, each a line apart.
    private func column(_ texts: [String], x: CGFloat = 40, top: CGFloat = 60, font: NSFont = TestFont.regular()) -> [Line] {
        texts.enumerated().map { index, text in
            Line(runs: [Run(text: text, font: font)], x: x, top: top + CGFloat(index) * 14)
        }
    }

    @Test func wrappedLinesBecomeOneParagraph() {
        let text = copied(column([
            "Leser ist ein schlichter Betrachter für Dokumente,",
            "die man in Ruhe lesen möchte, ohne Ablenkung und",
            "ohne Werbung.",
        ]))
        #expect(text.string == "Leser ist ein schlichter Betrachter für Dokumente, die man in Ruhe lesen möchte, ohne Ablenkung und ohne Werbung.")
    }

    @Test func lineEndingBeforeTheMarginEndsTheParagraph() {
        let text = copied(column([
            "Der erste Absatz endet hier.",
            "Der zweite Absatz beginnt hier und ist deutlich",
            "länger als die erste Zeile.",
        ]))
        #expect(text.string == "Der erste Absatz endet hier.\nDer zweite Absatz beginnt hier und ist deutlich länger als die erste Zeile.")
    }

    @Test func hyphenatedWordIsJoined() {
        let text = copied(column([
            "Ein langes Wort wird am Ende der Zeile zusammen-",
            "gefügt, wenn man den Text wieder kopiert.",
        ]))
        #expect(text.string == "Ein langes Wort wird am Ende der Zeile zusammengefügt, wenn man den Text wieder kopiert.")
    }

    @Test func hyphenBeforeCapitalStays() {
        // "Nord- und Südseite": before a capital, the hyphen belongs to the word.
        let text = copied(column([
            "Der Weg verbindet die beiden Hälften der Stadt, Nord-",
            "Süd-Verbindung genannt, und wird viel befahren.",
        ]))
        #expect(text.string == "Der Weg verbindet die beiden Hälften der Stadt, Nord- Süd-Verbindung genannt, und wird viel befahren.")
    }

    @Test func headingInLargerTypeStandsAlone() {
        let lines = [Line(runs: [Run(text: "Lesen und Navigieren", font: TestFont.bold(16))], x: 40, top: 40)]
            + column(["Ein Dokument öffnest du per Doppelklick oder über", "das Menü."], top: 64)
        #expect(copied(lines).string == "Lesen und Navigieren\nEin Dokument öffnest du per Doppelklick oder über das Menü.")
    }

    @Test func boldLineOfSameSizeIsAHeading() {
        let lines = column(["Die Seitenleiste"], font: TestFont.bold())
            + column(["Links zeigt Leser wahlweise die Gliederung oder", "die Miniaturen."], top: 74)
        #expect(copied(lines).string == "Die Seitenleiste\nLinks zeigt Leser wahlweise die Gliederung oder die Miniaturen.")
    }

    @Test func entryStartingInBoldStartsALine() {
        // Stat blocks: "Skills …" in bold after a line that did not end in bold.
        let lines = [
            Line(runs: [Run(text: "Perception", font: TestFont.bold()), Run(text: " +9; darkvision and more senses than most")], x: 40, top: 60),
            Line(runs: [Run(text: "Skills", font: TestFont.bold()), Run(text: " Athletics +11")], x: 40, top: 74),
        ]
        #expect(copied(lines).string == "Perception +9; darkvision and more senses than most\nSkills Athletics +11")
    }

    @Test func listItemsStayApart() {
        let text = copied(column([
            "Die Schritte sind diese, in dieser Reihenfolge:",
            "• Dokument öffnen und lesen, so lange man mag",
            "• Lesezeichen setzen",
            "1. Erster Schritt",
        ]))
        #expect(text.string == "Die Schritte sind diese, in dieser Reihenfolge:\n• Dokument öffnen und lesen, so lange man mag\n• Lesezeichen setzen\n1. Erster Schritt")
    }

    @Test func numberStartingALineMidSentenceIsNoList() {
        let text = copied(column([
            "Die Gruppe braucht für diesen Weg mindestens",
            "2. Grades Abenteurer und genügend Vorräte.",
        ]))
        #expect(text.string == "Die Gruppe braucht für diesen Weg mindestens 2. Grades Abenteurer und genügend Vorräte.")
    }

    @Test func paragraphGoesOnInTheNextColumn() {
        let left = column(["Der Text der linken Spalte", "läuft hier über mehrere", "Zeilen nach unten und", "endet mitten im Satz und"], x: 40, top: 60)
        let right = column(["geht in der rechten Spalte", "weiter, oben auf der Seite."], x: 230, top: 60)
        #expect(copied(left + right).string == "Der Text der linken Spalte läuft hier über mehrere Zeilen nach unten und endet mitten im Satz und geht in der rechten Spalte weiter, oben auf der Seite.")
    }

    @Test func columnEndingWithASentenceEndsTheParagraph() {
        let left = column(["Der Text der linken Spalte", "läuft hier über mehrere", "Zeilen nach unten und", "endet mit einem Satzende."], x: 40, top: 60)
        let right = column(["Rechts beginnt etwas Neues", "oben auf der Seite."], x: 230, top: 60)
        #expect(copied(left + right).string == "Der Text der linken Spalte läuft hier über mehrere Zeilen nach unten und endet mit einem Satzende.\nRechts beginnt etwas Neues oben auf der Seite.")
    }

    @Test func indentedLineStartsAParagraph() {
        let lines = column([
            "Der erste Absatz hat eine gerade linke Kante und",
            "läuft über mehrere Zeilen, bis zum Rand der Spalte",
            "und noch eine weitere Zeile bis zu ihrem Ende hin.",
        ]) + [Line(runs: [Run(text: "Der nächste Absatz ist eingerückt und geht")], x: 60, top: 102)]
            + [Line(runs: [Run(text: "bis zum Rand der Spalte, wie es sich gehört hier.")], x: 40, top: 116)]
        let text = copied(lines).string
        #expect(text.hasPrefix("Der erste Absatz hat eine gerade linke Kante und läuft über mehrere Zeilen"))
        #expect(text.contains("bis zu ihrem Ende hin.\nDer nächste Absatz ist eingerückt"))
    }

    @Test func boldAndItalicAreKept() throws {
        let text = copied([
            Line(runs: [Run(text: "Normal, "), Run(text: "fett", font: TestFont.bold()), Run(text: " und "),
                        Run(text: "kursiv", font: TestFont.italic()), Run(text: ".")], x: 40, top: 60),
        ])
        let string = text.string as NSString
        let bold = try #require(text.attribute(.font, at: string.range(of: "fett").location, effectiveRange: nil) as? NSFont)
        let italic = try #require(text.attribute(.font, at: string.range(of: "kursiv").location, effectiveRange: nil) as? NSFont)
        #expect(bold.fontName.lowercased().contains("bold"))
        #expect(italic.fontName.lowercased().contains("oblique") || italic.fontDescriptor.symbolicTraits.contains(.italic))
    }

    @Test func whiteTextTurnsBlack() throws {
        let source = NSMutableAttributedString(string: "Weiß Rot")
        source.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: 4))
        source.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: 5, length: 3))
        let result = ReaderPDFView.readableOnWhite(source)
        let white = try #require((result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.usingColorSpace(.sRGB))
        let red = try #require((result.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor)?.usingColorSpace(.sRGB))
        #expect(white.redComponent < 0.1 && white.greenComponent < 0.1 && white.blueComponent < 0.1)
        #expect(red.redComponent > 0.9 && red.greenComponent < 0.1)
    }
}
