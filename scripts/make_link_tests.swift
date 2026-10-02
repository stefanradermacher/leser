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

// Creates two small documents for trying out links between files by hand:
// testdata/Abenteuer.pdf links into testdata/Regelwerk.pdf with real PDF links
// (GoToR), next to page references in its text and one link to a missing file.
// PDFKit writes such links without their file and page, so these are filled in
// afterwards, and the table of objects at the end of the file is written anew.
// Usage (from the project folder): swift scripts/make_link_tests.swift

import AppKit
import PDFKit

let folder = URL(fileURLWithPath: "testdata", isDirectory: true)
let pageSize = CGSize(width: 420, height: 595)

/// A document with one text per page and the page number printed at the bottom.
func makeDocument(title: String, pages: [String]) -> PDFDocument {
    let data = NSMutableData()
    var box = CGRect(origin: .zero, size: pageSize)
    let info = [kCGPDFContextTitle as String: title] as CFDictionary
    let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, info)!
    for (index, text) in pages.enumerated() {
        context.beginPDFPage(nil)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let body = NSAttributedString(string: text, attributes: [
            .font: NSFont(name: "Georgia", size: 13) ?? NSFont.systemFont(ofSize: 13),
        ])
        body.draw(with: CGRect(x: 48, y: 80, width: pageSize.width - 96, height: pageSize.height - 140),
                  options: [.usesLineFragmentOrigin])
        let number = NSAttributedString(string: "\(index + 1)", attributes: [.font: NSFont.systemFont(ofSize: 10)])
        number.draw(at: CGPoint(x: pageSize.width / 2 - number.size().width / 2, y: 36))
        context.endPDFPage()
    }
    context.closePDF()
    return PDFDocument(data: data as Data)!
}

/// Puts a link over a text on a page.
func link(_ text: String, on page: PDFPage, to action: PDFAction) {
    guard let document = page.document,
          let selection = document.findString(text, withOptions: []).first(where: { $0.pages.contains(page) })
    else { fatalError("„\(text)“ nicht gefunden") }
    let annotation = PDFAnnotation(bounds: selection.bounds(for: page).insetBy(dx: -1, dy: -1),
                                   forType: .link, withProperties: nil)
    annotation.action = action
    page.addAnnotation(annotation)
}

// MARK: - Regelwerk

let topics = ["Einleitung", "Spielwerte", "Proben", "Aktionen", "Kampf", "Zustände",
              "Feuerball", "Unsichtbarkeit", "Heilung", "Gifte", "Schätze", "Register"]
let rules = makeDocument(title: "Regelwerk", pages: topics.enumerated().map { index, topic in
    "Regelwerk – Kapitel \(index + 1)\n\n\(topic)\n\nDies ist die Seite \(index + 1) des Regelwerks. "
        + "Sie erklärt alles über \(topic.lowercased()). Ein Link aus dem Abenteuer, der hierher "
        + "führt, sollte genau diese Seite zeigen."
})

// MARK: - Abenteuer

let adventure = makeDocument(title: "Abenteuer", pages: [
    """
    Abenteuer – Teil 1

    Echte Links in eine andere Datei:
    Der Drache wirkt Feuerball (Regelwerk, Feuerball).
    Danach brennt das Ziel (Regelwerk, Zustände).

    Link auf eine fehlende Datei (Fehlende Datei).
    """,
    """
    Abenteuer – Teil 2

    Seitenangaben im Text ohne Link:
    Der Kampf folgt den Regeln (Regelwerk, S. 5).
    Siehe auch die Heilung (Regelwerk, S. 9).
    Zurück zum Anfang (Seite 1).
    """,
])

/// The links of the adventure: text, file, page index. Written in this order.
let remoteLinks = [
    ("(Regelwerk, Feuerball)", "Regelwerk.pdf", 6),
    ("(Regelwerk, Zustände)", "Regelwerk.pdf", 5),
    ("(Fehlende Datei)", "Fehlt.pdf", 0),
]
for (text, file, page) in remoteLinks {
    link(text, on: adventure.page(at: 0)!,
         to: PDFActionRemoteGoTo(pageIndex: page, at: .zero, fileURL: URL(string: file)!))
}

/// Fills in file and page of the links PDFKit wrote as bare "/S /GoToR", in order, takes
/// away their frames, and writes the table of object positions anew, as the objects moved.
func completeRemoteLinks(in data: Data) -> Data {
    // Latin-1 keeps every byte as one character, so lengths are byte counts.
    var text = String(data: data, encoding: .isoLatin1)!
    for (_, file, page) in remoteLinks {
        guard let range = text.range(of: "/A << /S /GoToR >>") else { fatalError("Link fehlt") }
        text.replaceSubrange(range, with: "/A << /S /GoToR /F (\(file)) /D [ \(page) /Fit ] >>")
    }
    // No frame around the links, which a link without a border entry gets.
    text = text.replacingOccurrences(of: "/Subtype /Link", with: "/Subtype /Link /Border [ 0 0 0 ]")
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
        offsets[Int((body as NSString).substring(with: match.range(at: 1)))!] = match.range.location
    }
    var table = "xref\n0 \(size)\n0000000000 65535 f \n"
    for number in 1..<size {
        table += String(format: "%010d 00000 %@ \n", offsets[number], offsets[number] > 0 ? "n" : "f")
    }
    let startMatch = matches(#"startxref\s+\d+"#, in: trailer)[0]
    let tail = (trailer as NSString).replacingCharacters(in: startMatch.range,
                                                         with: "startxref\n\((body as NSString).length)")
    return (body + table + tail).data(using: .isoLatin1)!
}

try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
rules.write(to: folder.appendingPathComponent("Regelwerk.pdf"))
try completeRemoteLinks(in: adventure.dataRepresentation()!)
    .write(to: folder.appendingPathComponent("Abenteuer.pdf"))
print("testdata/Regelwerk.pdf, testdata/Abenteuer.pdf")
