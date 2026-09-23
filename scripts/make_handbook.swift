// Creates the small manual about Leser, used for the App Store screenshots and as a
// sample document with an outline.
// Usage (from the project folder): swift scripts/make_handbook.swift [en]
//   without an argument: docs/Leser-Handbuch.pdf (German)
//   with "en":           docs/Leser-Handbook.pdf (English)

import AppKit
import PDFKit

// MARK: - Language

let english = CommandLine.arguments.contains("en")

let outputPath = english ? "docs/Leser-Handbook.pdf" : "docs/Leser-Handbuch.pdf"
let coverSubtitle = english ? "Handbook for the macOS PDF viewer" : "Handbuch zum PDF-Betrachter für macOS"
let coverClaim = english ? "View documents. Nothing else." : "Dokumente ansehen. Sonst nichts."
let coverIntro = english
    ? "Leser shows PDFs and never changes them: with an outline, thumbnails, full-text search and a split view. Free, ad-free and collecting no data."
    : "Leser zeigt PDFs und verändert sie nie: mit Gliederung, Miniaturen, Volltextsuche und geteilter Ansicht. Kostenlos, werbefrei und ohne Datensammlung."
let documentTitle = english ? "Leser – Handbook" : "Leser – Handbuch"
let documentSubject = english ? "PDF viewer for macOS" : "PDF-Betrachter für macOS"

// MARK: - Look

let brick = NSColor(srgbRed: 0.69, green: 0.23, blue: 0.18, alpha: 1)
let ink = NSColor(white: 0.1, alpha: 1)
let quiet = NSColor(white: 0.42, alpha: 1)
let paper = NSColor.white

let pageSize = CGSize(width: 595, height: 842)   // A4
let margin: CGFloat = 70
let contentWidth = pageSize.width - 2 * margin
let bottomMargin: CGFloat = 78

func paragraphStyle(_ spacing: CGFloat, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 3) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.paragraphSpacing = spacing
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.hyphenationFactor = 1
    return style
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular,
          color: NSColor = ink, spacing: CGFloat = 0, alignment: NSTextAlignment = .left,
          lineSpacing: CGFloat = 3) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle(spacing, alignment: alignment, lineSpacing: lineSpacing),
    ])
}

// MARK: - Document model

enum Block {
    case chapter(String)        // starts a new page and an outline entry
    case heading(String)
    case body(String)
    case bullet(String)
    case note(String)           // text in a tinted box
    case shortcuts([(String, String)])
    case space(CGFloat)
}

let blocksDE: [Block] = [
    .chapter("Über dieses Handbuch"),
    .body("Leser ist ein schlichter PDF-Betrachter für macOS. Er zeigt Dokumente an und verändert sie nie. Dieses Handbuch beschreibt in wenigen Kapiteln, was Leser kann und wie es sich bedienen lässt."),
    .body("Es ist zugleich ein Beispieldokument: mehrere Kapitel mit Gliederung, damit sich die Seitenleiste, die Suche und die geteilte Ansicht daran ausprobieren lassen."),
    .note("Leser bearbeitet keine Dokumente. Wer Anmerkungen machen, Seiten drehen oder Formulare ausfüllen möchte, braucht ein anderes Programm. Genau diese Beschränkung macht Leser schnell und übersichtlich."),
    .heading("Was Leser ausmacht"),
    .bullet("Kostenlos und quelloffen unter der Apache-Lizenz 2.0"),
    .bullet("Keine Werbung, kein Tracking, keine Datensammlung"),
    .bullet("Nur Apple-Frameworks, keine Fremdkomponenten"),
    .bullet("Deutsch und Englisch"),

    .chapter("Lesen und Navigieren"),
    .body("Ein Dokument öffnest du per Doppelklick, über „Ablage → Öffnen …“ oder indem du es auf das Symbol im Dock ziehst. Leser merkt sich, an welcher Stelle du zuletzt warst, und öffnet das Dokument beim nächsten Mal genau dort."),
    .heading("Blättern"),
    .body("Mit den Pfeiltasten nach links und rechts blätterst du seitenweise, mit den Tasten nach oben und unten sowie mit dem Trackpad scrollst du fortlaufend. Über „Gehe zu Seite …“ springst du direkt zu einer Seitenzahl; die aktuelle Seite steht immer als Untertitel im Fenster."),
    .heading("Die Seitenleiste"),
    .body("Links zeigt Leser wahlweise die Gliederung des Dokuments oder Miniaturen aller Seiten. Beides lässt sich mit einem Klick umschalten. In der Gliederung folgt die Markierung deiner Leseposition, sodass du jederzeit siehst, in welchem Kapitel du bist."),
    .bullet("Gliederung: springt zu Kapiteln und Abschnitten"),
    .bullet("Miniaturen: zeigt alle Seiten und die aktuelle Seite hervorgehoben"),
    .heading("Zoom"),
    .body("Der Zoom lässt sich in Stufen ändern oder an die Seitenbreite, die Seitenhöhe oder die ganze Seite anpassen. Die gewählte Anpassung bleibt erhalten, auch wenn du das Fenster größer oder kleiner ziehst."),

    .heading("Tabs und Fenster"),
    .body("Mehrere Dokumente öffnet Leser wahlweise als Tabs in einem Fenster oder in eigenen Fenstern, je nachdem, was in den Einstellungen steht. Größe und Position des zuletzt benutzten Fensters merkt sich Leser, sodass neue Dokumente gleich passend aufgehen."),

    .chapter("Suchen"),
    .body("Die Suche findet Wörter im gesamten Dokument. Die Fundstellen erscheinen in einer eigenen Seitenleiste rechts, jeweils mit einem Textausschnitt und der Seitenzahl. Ein Klick darauf springt zur Stelle, und alle Treffer sind im Dokument farbig hervorgehoben."),
    .heading("Von Treffer zu Treffer"),
    .body("Mit der Eingabetaste oder mit „Weitersuchen“ wanderst du durch die Fundstellen, rückwärts geht es ebenso. Leser achtet dabei weder auf Groß- und Kleinschreibung noch auf Akzente, sodass auch „Ubergrosse“ die Stelle „Übergröße“ findet."),
    .note("Findet die Suche nichts, obwohl der Text sichtbar ist, enthält das Dokument vermutlich nur Bilder, etwa bei einem Scan ohne Texterkennung. Unter „Dokumentinformationen“ steht dann bei „Durchsuchbarer Text“ ein Nein."),

    .heading("Wonach sich suchen lässt"),
    .body("Gesucht wird im Text des Dokuments, nicht in den Namen der Kapitel. Ein Dokument, das aus Bildern besteht, lässt sich daher nicht durchsuchen, ein aus einem Satzprogramm erzeugtes PDF dagegen vollständig."),

    .chapter("Zwei Stellen gleichzeitig"),
    .body("Mit der geteilten Ansicht zeigt Leser dasselbe Dokument zweimal, nebeneinander oder untereinander. So lassen sich eine Tabelle und ihre Erläuterung, ein Vertragstext und seine Anlage oder zwei weit auseinanderliegende Kapitel zusammen lesen."),
    .heading("Zwei Dokumente"),
    .body("In der zweiten Hälfte kannst du auch ein anderes PDF öffnen, etwa um zwei Fassungen zu vergleichen. Jede Hälfte hat ihre eigene Position, ihren eigenen Zoom und ihren eigenen Anzeigemodus."),
    .heading("Die aktive Hälfte"),
    .body("Symbolleiste, Menübefehle, Seitenleiste und Suche wirken immer auf die zuletzt angeklickte Hälfte. Welche das ist, zeigt eine farbige Linie unter ihrer Kopfzeile."),

    .heading("Wieder schließen"),
    .body("Ein Klick auf das Kreuz in der Kopfzeile der zweiten Hälfte beendet die geteilte Ansicht, ebenso der Knopf in der Symbolleiste oder der Menübefehl. Das Hauptdokument bleibt dabei an seiner Stelle."),

    .chapter("Anzeige und Einstellungen"),
    .body("Leser kennt vier Arten, Seiten anzuordnen: fortlaufend, einzeln, als Doppelseite oder als Doppelseite mit einzelner erster Seite, wie bei einem Buch mit Titelseite."),
    .heading("Was beim Öffnen gilt"),
    .body("In den Einstellungen legst du fest, womit ein Dokument aufgeht: mit welcher Anzeige, welchem Zoom und ob die Seitenleiste erscheint. Ebenso, ob neue Dokumente als Tab oder in einem eigenen Fenster öffnen."),
    .heading("Automatisch neu laden"),
    .body("Ändert ein anderes Programm die Datei, etwa beim Export aus einem Satzprogramm oder beim Übersetzen eines LaTeX-Dokuments, zeigt Leser die neue Fassung von selbst an. Seite, Zoom und Anzeige bleiben dabei erhalten."),

    .heading("Standard-App"),
    .body("Soll Leser PDFs immer öffnen, genügt ein Klick in den Einstellungen. Die Umstellung bestätigt macOS anschließend selbst, damit sie nie unbemerkt geschieht."),

    .chapter("Fragen und Antworten"),
    .heading("Kann ich mit Leser PDFs bearbeiten?"),
    .body("Nein, und das bleibt so. Leser ist bewusst nur ein Betrachter. Für Anmerkungen, Formulare oder das Zusammenfügen von Dokumenten eignen sich andere Programme."),
    .heading("Warum fehlt die Gliederung?"),
    .body("Weil das Dokument keine enthält. Viele PDFs aus Textverarbeitungen bringen keine mit. In diesem Fall zeigt Leser Miniaturen der Seiten an."),
    .heading("Kann ich Text kopieren?"),
    .body("Ja. Text lässt sich wie gewohnt mit der Maus markieren und kopieren, sofern das Dokument es erlaubt. Ob es das tut, steht unter „Dokumentinformationen“."),
    .heading("Was passiert mit meinen Dokumenten?"),
    .body("Nichts, außer dass sie angezeigt werden. Leser schreibt nie in ein Dokument und lädt nichts hoch."),

    .chapter("Tastaturkürzel"),
    .body("Die wichtigsten Befehle lassen sich ohne Maus erreichen:"),
    .shortcuts([
        ("Suchen, Weitersuchen, Rückwärts", "⌘F, ⌘G, ⇧⌘G"),
        ("Suchergebnisse ein- und ausblenden", "⌥⌘F"),
        ("Seitenleiste ein- und ausblenden", "⌃⌘S"),
        ("Gliederung, Miniaturen", "⌃⌘1, ⌃⌘2"),
        ("Vergrößern, Verkleinern, Originalgröße", "⌘+, ⌘-, ⌘0"),
        ("Seitenbreite, Seitenhöhe, Ganze Seite", "⌘1, ⌘2, ⌘3"),
        ("Vorherige und nächste Seite", "← und →"),
        ("Erste und letzte Seite", "⌥⌘Pos1, ⌥⌘Ende"),
        ("Gehe zu Seite", "⌥⌘G"),
        ("Ansicht teilen", "⌃⌘T"),
        ("Dokumentinformationen", "⌘I"),
        ("Drucken", "⌘P"),
    ]),

    .chapter("Datenschutz"),
    .body("Leser sammelt keine Daten. Es gibt kein Tracking, keine Analyse und keine Werbung, und die App baut von sich aus keine Verbindung ins Internet auf. Deine Dokumente werden ausschließlich auf deinem Mac gelesen und angezeigt."),
    .heading("Was lokal gespeichert wird"),
    .bullet("Deine Einstellungen"),
    .bullet("Größe und Position des zuletzt benutzten Fensters"),
    .bullet("Die zuletzt gelesene Stelle für bis zu 200 Dokumente"),
    .body("Diese Angaben verlassen deinen Mac nicht. Die gespeicherten Stellen lassen sich in den Einstellungen mit einem Schalter wieder löschen."),
    .note("Wer möchte, kann die Weiterentwicklung mit einem freiwilligen Trinkgeld unterstützen. Es schaltet nichts frei: Leser bleibt vollständig kostenlos."),
]

let blocksEN: [Block] = [
    .chapter("About This Handbook"),
    .body("Leser is a plain PDF viewer for macOS. It shows documents and never changes them. This handbook describes in a few short chapters what Leser can do and how it is used."),
    .body("It is also a sample document: several chapters with an outline, so that the sidebar, the search and the split view have something to work with."),
    .note("“Leser” [ˈleːzɐ] is the German word for “reader”. Leser does not edit documents. Anyone who wants to add notes, rotate pages or fill in forms needs a different program. That very limitation is what keeps Leser fast and uncluttered."),
    .heading("What Leser stands for"),
    .bullet("Free and open source under the Apache 2.0 licence"),
    .bullet("No ads, no tracking, no data collection"),
    .bullet("Apple frameworks only, no third-party components"),
    .bullet("English and German"),

    .chapter("Reading and Navigating"),
    .body("You open a document by double-clicking it, through “File → Open …” or by dropping it onto the icon in the Dock. Leser remembers where you left off and opens the document there the next time."),
    .heading("Turning pages"),
    .body("The left and right arrow keys turn one page at a time; the up and down keys and the trackpad scroll continuously. “Go to Page …” jumps straight to a page number, and the current page is always shown as the window subtitle."),
    .heading("The sidebar"),
    .body("On the left, Leser shows either the outline of the document or thumbnails of every page. A single click switches between them. In the outline the highlight follows your reading position, so you can always see which chapter you are in."),
    .bullet("Outline: jumps to chapters and sections"),
    .bullet("Thumbnails: shows every page with the current one highlighted"),
    .heading("Zoom"),
    .body("The zoom can be changed in steps or fitted to the page width, the page height or the whole page. The chosen fit is kept even when you resize the window."),

    .heading("Tabs and windows"),
    .body("Leser opens several documents either as tabs in one window or in windows of their own, whichever the settings say. It remembers the size and position of the last window used, so new documents open to fit right away."),

    .chapter("Searching"),
    .body("The search looks through the whole document. Every match appears in a sidebar of its own on the right, each with a snippet of text and the page number. Clicking one jumps to that spot, and all matches are highlighted in the document."),
    .heading("From match to match"),
    .body("The return key, or “Find Next”, walks you through the matches, and backwards works just as well. Leser ignores both capitalisation and accents, so “Ubergrosse” will find “Übergröße”."),
    .note("If the search finds nothing although the text is plainly visible, the document probably holds nothing but images, as a scan without text recognition does. In that case “Document Information” says No next to “Searchable text”."),

    .heading("What can be searched"),
    .body("Leser searches the text of the document, not the names of its chapters. A document made of images therefore cannot be searched at all, while a PDF produced by a word processor can be searched completely."),

    .chapter("Two Places at Once"),
    .body("With the split view Leser shows the same document twice, side by side or stacked. That way a table and its explanation, a contract and its appendix, or two chapters far apart can be read together."),
    .heading("Two documents"),
    .body("In the second half you can also open a different PDF, to compare two versions for instance. Each half keeps its own position, its own zoom and its own page layout."),
    .heading("The active half"),
    .body("The toolbar, the menu commands, the sidebar and the search always act on the half you clicked last. A coloured line under its header shows which one that is."),

    .heading("Closing it again"),
    .body("Clicking the cross in the header of the second half ends the split view, and so does the toolbar button or the menu command. The main document stays exactly where it was."),

    .chapter("Display and Settings"),
    .body("Leser knows four ways to arrange pages: continuous, single page, two pages, or two pages with the first one alone, the way a book with a title page reads."),
    .heading("How documents open"),
    .body("The settings decide what a document opens with: which page layout, which zoom and whether the sidebar appears. They also decide whether new documents open as a tab or in a window of their own."),
    .heading("Reloading automatically"),
    .body("When another program changes the file, after an export or when a LaTeX document is typeset, Leser shows the new version by itself. Page, zoom and page layout are kept."),

    .heading("Default app"),
    .body("If you want Leser to open PDFs from now on, one click in the settings is enough. macOS then confirms the change itself, so that it never happens unnoticed."),

    .chapter("Questions and Answers"),
    .heading("Can I edit PDFs with Leser?"),
    .body("No, and it will stay that way. Leser is deliberately a viewer only. For notes, forms or merging documents, other programs are the right tool."),
    .heading("Why is the outline missing?"),
    .body("Because the document has none. Many PDFs from word processors do not bring one along. In that case Leser shows thumbnails of the pages instead."),
    .heading("Can I copy text?"),
    .body("Yes. Text can be selected and copied with the mouse as usual, as long as the document allows it. Whether it does is listed under “Document Information”."),
    .heading("What happens to my documents?"),
    .body("Nothing, other than being shown. Leser never writes into a document and never uploads anything."),

    .chapter("Keyboard Shortcuts"),
    .body("The most useful commands are all within reach without the mouse:"),
    .shortcuts([
        ("Find, Find Next, Find Previous", "⌘F, ⌘G, ⇧⌘G"),
        ("Show and hide search results", "⌥⌘F"),
        ("Show and hide the sidebar", "⌃⌘S"),
        ("Outline, Thumbnails", "⌃⌘1, ⌃⌘2"),
        ("Zoom in, Zoom out, Actual Size", "⌘+, ⌘-, ⌘0"),
        ("Page Width, Page Height, Whole Page", "⌘1, ⌘2, ⌘3"),
        ("Previous and next page", "← and →"),
        ("First and last page", "⌥⌘Home, ⌥⌘End"),
        ("Go to Page", "⌥⌘G"),
        ("Split View", "⌃⌘T"),
        ("Document Information", "⌘I"),
        ("Print", "⌘P"),
    ]),

    .chapter("Privacy"),
    .body("Leser collects no data. There is no tracking, no analytics and no advertising, and the app opens no connection to the internet of its own accord. Your documents are read and shown on your Mac and nowhere else."),
    .heading("What is stored locally"),
    .bullet("Your settings"),
    .bullet("Size and position of the last window used"),
    .bullet("The place you last read, for up to 200 documents"),
    .body("None of this leaves your Mac. The stored places can be deleted again with a switch in the settings."),
    .note("If you like, you can support the continued work with a voluntary tip. It unlocks nothing: Leser stays free in full."),
]

let blocks = english ? blocksEN : blocksDE

// MARK: - Rendering

var outline: [(title: String, page: Int)] = []
var pageNumber = 0
var pageOpen = false
var y: CGFloat = 0
var runningHead = ""

let url = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
var mediaBox = CGRect(origin: .zero, size: pageSize)
let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil)!

func beginPage() {
    ctx.beginPDFPage(nil)
    pageOpen = true
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    paper.setFill()
    CGRect(origin: .zero, size: pageSize).fill()
    pageNumber += 1
    y = pageSize.height - margin
}

func endPage() {
    guard pageOpen else { return }
    pageOpen = false
    // The title page carries neither a running head nor a page number.
    if pageNumber == 1 {
        ctx.endPDFPage()
        return
    }
    if !runningHead.isEmpty {
        text(runningHead, size: 8.5, color: quiet)
            .draw(at: NSPoint(x: margin, y: pageSize.height - margin + 24))
        brick.withAlphaComponent(0.25).setFill()
        CGRect(x: margin, y: pageSize.height - margin + 18, width: contentWidth, height: 0.7).fill()
    }
    let number = text("\(pageNumber)", size: 9, color: quiet)
    number.draw(at: NSPoint(x: (pageSize.width - number.size().width) / 2, y: bottomMargin - 34))
    ctx.endPDFPage()
}

/// Height of the text, measured with the same line breaking that is used for drawing.
/// boundingRect is too optimistic for justified text with hyphenation and clips the last line.
func height(_ string: NSAttributedString, width: CGFloat = contentWidth) -> CGFloat {
    let storage = NSTextStorage(attributedString: string)
    let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    let layout = NSLayoutManager()
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return ceil(layout.usedRect(for: container).height) + 3
}

func place(_ string: NSAttributedString, indent: CGFloat = 0, gap: CGFloat = 0) {
    let width = contentWidth - indent
    let needed = height(string, width: width)
    if y - needed < bottomMargin {
        endPage()
        beginPage()
    }
    string.draw(with: CGRect(x: margin + indent, y: y - needed, width: width, height: needed),
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    y -= needed + gap
}

func titlePage() {
    beginPage()
    brick.setFill()
    CGRect(x: 0, y: pageSize.height - 250, width: pageSize.width, height: 250).fill()

    let title = text("Leser", size: 54, weight: .bold, color: .white)
    title.draw(at: NSPoint(x: margin, y: pageSize.height - 150))
    let subtitle = text(coverSubtitle, size: 15, color: NSColor(white: 1, alpha: 0.9))
    subtitle.draw(at: NSPoint(x: margin + 3, y: pageSize.height - 185))

    if let icon = NSImage(contentsOfFile: "Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png") {
        icon.draw(in: CGRect(x: (pageSize.width - 190) / 2, y: 380, width: 190, height: 190))
    }

    let claim = text(coverClaim, size: 19, weight: .semibold, color: brick, alignment: .center)
    claim.draw(with: CGRect(x: margin, y: 310, width: contentWidth, height: 40), options: [.usesLineFragmentOrigin])

    let intro = text(coverIntro,
                     size: 12, color: quiet, alignment: .center, lineSpacing: 4)
    intro.draw(with: CGRect(x: margin + 40, y: 230, width: contentWidth - 80, height: 70), options: [.usesLineFragmentOrigin, .usesFontLeading])

    let footer = text("Version 1.0 · stefanradermacher.com", size: 9.5, color: quiet, alignment: .center)
    footer.draw(with: CGRect(x: margin, y: 120, width: contentWidth, height: 20), options: [.usesLineFragmentOrigin])
    endPage()
}

func shortcutTable(_ rows: [(String, String)]) {
    let rowHeight: CGFloat = 23
    for (index, row) in rows.enumerated() {
        if y - rowHeight < bottomMargin {
            endPage()
            beginPage()
        }
        if index % 2 == 0 {
            NSColor(white: 0.96, alpha: 1).setFill()
            CGRect(x: margin - 8, y: y - rowHeight + 4, width: contentWidth + 16, height: rowHeight).fill()
        }
        text(row.0, size: 11).draw(at: NSPoint(x: margin, y: y - rowHeight + 10))
        let keys = text(row.1, size: 11, weight: .medium, color: brick)
        keys.draw(at: NSPoint(x: pageSize.width - margin - keys.size().width, y: y - rowHeight + 10))
        y -= rowHeight
    }
    y -= 10
}

func noteBox(_ string: String) {
    let content = text(string, size: 11, color: NSColor(white: 0.25, alpha: 1), lineSpacing: 3.5)
    let inner = contentWidth - 34
    let needed = height(content, width: inner) + 28
    if y - needed < bottomMargin {
        endPage()
        beginPage()
    }
    let box = CGRect(x: margin, y: y - needed, width: contentWidth, height: needed)
    NSColor(srgbRed: 0.98, green: 0.94, blue: 0.93, alpha: 1).setFill()
    NSBezierPath(roundedRect: box, xRadius: 7, yRadius: 7).fill()
    brick.setFill()
    CGRect(x: box.minX, y: box.minY, width: 3.5, height: box.height).fill()
    content.draw(with: CGRect(x: box.minX + 20, y: box.minY + 14, width: inner, height: needed - 28),
                 options: [.usesLineFragmentOrigin, .usesFontLeading])
    y -= needed + 16
}

titlePage()

for block in blocks {
    switch block {
    case .chapter(let title):
        endPage()
        runningHead = title
        beginPage()
        outline.append((title, pageNumber))
        place(text(title, size: 27, weight: .bold, color: brick), gap: 6)
        brick.withAlphaComponent(0.3).setFill()
        CGRect(x: margin, y: y + 2, width: 70, height: 2.5).fill()
        y -= 18
    case .heading(let title):
        y -= 6
        place(text(title, size: 14, weight: .semibold), gap: 6)
    case .body(let string):
        place(text(string, size: 11.5, alignment: .justified, lineSpacing: 3.5), gap: 12)
    case .bullet(let string):
        let dot = text("•", size: 11.5, color: brick)
        let line = text(string, size: 11.5, lineSpacing: 3.5)
        let needed = height(line, width: contentWidth - 18)
        if y - needed < bottomMargin {
            endPage()
            beginPage()
        }
        dot.draw(at: NSPoint(x: margin, y: y - needed + (needed - 14)))
        line.draw(with: CGRect(x: margin + 18, y: y - needed, width: contentWidth - 18, height: needed),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
        y -= needed + 7
    case .note(let string):
        y -= 4
        noteBox(string)
    case .shortcuts(let rows):
        shortcutTable(rows)
    case .space(let value):
        y -= value
    }
}
endPage()

// Outline, so the sidebar has something to show
let children = outline.map { entry -> [String: Any] in
    ["Title": entry.title, "Destination": entry.page]
}
CGPDFContextSetOutline(ctx, ["Children": children] as CFDictionary)
ctx.closePDF()

// Title and author for the document information
if let document = PDFDocument(url: url) {
    document.documentAttributes = [
        PDFDocumentAttribute.titleAttribute: documentTitle,
        PDFDocumentAttribute.authorAttribute: "Stefan Radermacher",
        PDFDocumentAttribute.subjectAttribute: documentSubject,
        PDFDocumentAttribute.creatorAttribute: "Leser",
    ]
    let temporary = url.deletingLastPathComponent().appendingPathComponent("tmp-handbuch.pdf")
    if document.write(to: temporary) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.moveItem(at: temporary, to: url)
    }
}
print("\(outputPath) — \(pageNumber) Seiten, \(outline.count) Kapitel")
