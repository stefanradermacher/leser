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
import Observation
import PDFKit
import SwiftUI

/// Other documents that references in the text point to, like "Handbuch: Technik, S. 284",
/// each assigned to a file by the user the first time one of its references is followed. Links
/// into other files count too, their file name taking the place of the title. The
/// assignments hold for all documents.
///
/// In the sandbox Leser may only open files the user chose; a security-scoped bookmark keeps
/// that permission for a chosen file across launches.
@MainActor
@Observable
final class OtherDocuments {
    static let shared = OtherDocuments()

    struct Assignment: Codable, Identifiable {
        /// The title as it appeared in the reference it was assigned for.
        var title: String
        /// File name, to show without resolving the bookmark.
        var fileName: String
        var bookmark: Data

        var id: String { OtherDocuments.key(for: title) }
    }

    nonisolated private static let defaultsKey = "otherDocuments"
    nonisolated static let openingKey = "otherDocumentOpening"

    /// Assignments of files to titles, by the key of the title.
    private(set) var assignments: [String: Assignment] = [:]
    /// Counts the changes, so that references found before can be found again.
    private(set) var revision = 0

    @ObservationIgnored private var files: [String: URL] = [:]
    @ObservationIgnored private var loaded: [URL: (document: PDFDocument, references: PageReferences)] = [:]

    /// Reads the assignments stored before; `shared` is the one to use, the tests make their own.
    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([String: Assignment].self, from: data) {
            // By the key of their title as it is formed now, which may have changed since.
            assignments = Dictionary(stored.values.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
    }

    // MARK: Titles

    /// A title compared without case, punctuation and line breaks.
    nonisolated static func key(for title: String) -> String {
        PageReferences.joined(title).lowercased()
            .replacingOccurrences(of: #"[^\p{L}\d]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static var revision: Int { shared.revision }

    static func isKnown(_ title: String) -> Bool {
        shared.assignments[key(for: title)] != nil
    }

    // MARK: Assigning files

    func assign(_ url: URL, to title: String) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        let key = Self.key(for: title)
        assignments[key] = Assignment(title: title, fileName: url.lastPathComponent, bookmark: bookmark)
        files[key] = nil
        store()
    }

    func remove(_ assignment: Assignment) {
        assignments[assignment.id] = nil
        files[assignment.id] = nil
        store()
    }

    private func store() {
        revision += 1
        if let data = try? JSONEncoder().encode(assignments) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// The file assigned to a title, with access to it for as long as Leser runs.
    func file(for title: String) -> URL? {
        let key = Self.key(for: title)
        if let url = files[key] { return url }
        guard let assignment = assignments[key] else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: assignment.bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource()
        else { return nil }
        // Moved or renamed: keep the bookmark up to date.
        if stale { assign(url, to: assignment.title) }
        files[key] = url
        return url
    }

    // MARK: Pages

    /// A page as a reference gives it.
    enum Page {
        /// The number of the page, as printed on it or as its page label.
        case number(Int)
        /// The position of the page in the file, as a link into the file gives it.
        case index(Int)
    }

    /// The document assigned to a title and the index of a page in it.
    func page(_ page: Page, of title: String) -> (url: URL, document: PDFDocument, index: Int?)? {
        guard let url = file(for: title) else { return nil }
        let entry: (document: PDFDocument, references: PageReferences)
        if let cached = loaded[url] {
            entry = cached
        } else {
            guard let document = PDFDocument(url: url), !document.isLocked else { return nil }
            entry = (document, PageReferences(document: document, name: url.lastPathComponent))
            loaded[url] = entry
        }
        switch page {
        case .number(let number):
            return (url, entry.document, entry.references.pageIndex(forNumber: number))
        case .index(let index):
            return (url, entry.document, index < entry.document.pageCount ? index : nil)
        }
    }

    // MARK: Following a reference

    /// Opens the page a reference into another document gives. An unknown title is assigned to a
    /// file first, chosen by the user, starting in `folder`, where a linked file is likely.
    func follow(title: String, page: Page, folder: URL? = nil, from state: ReaderState) {
        if file(for: title) != nil {
            open(title: title, page: page, from: state)
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.directoryURL = folder
        panel.message = String(localized: "Welche Datei ist „\(title)“?")
        panel.prompt = String(localized: "Zuordnen")
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self, weak state] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                guard let self, let state else { return }
                self.assign(url, to: title)
                self.open(title: title, page: page, from: state)
            }
        }
        if let window = state.primary.pdfView.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func open(title: String, page pointer: Page, from state: ReaderState) {
        guard let page = page(pointer, of: title) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "„\(title)“ konnte nicht geöffnet werden.")
            alert.informativeText = String(localized: "Die zugeordnete Datei fehlt oder ist kein lesbares PDF-Dokument. In den Einstellungen unter „Verweise“ kannst du ihr eine andere Datei zuordnen.")
            if let window = state.primary.pdfView.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
            return
        }
        switch OtherDocumentOpening.current {
        case .tab:
            DocumentTabs.open(page.url, at: page.index, nextTo: state.primary.pdfView.window)
        case .split:
            state.showInSecondView(page.url, at: page.index)
        }
    }
}

/// Where another document opens when a reference into it is followed.
enum OtherDocumentOpening: String, CaseIterable, Identifiable {
    case tab, split

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tab: "In einem neuen Tab"
        case .split: "In der zweiten Ansicht"
        }
    }

    static var current: OtherDocumentOpening {
        OtherDocumentOpening(rawValue: UserDefaults.standard.string(forKey: OtherDocuments.openingKey) ?? "") ?? .tab
    }
}

/// Opens documents in tabs of a window, at a given page.
@MainActor
enum DocumentTabs {
    /// The window the next document window joins as a tab.
    private(set) static weak var pendingHost: NSWindow?
    /// Pages to show first in documents about to open, by file.
    private static var pendingPages: [URL: Int] = [:]

    /// Opens a file in a tab of `window`, or goes to its window if it is open already.
    static func open(_ url: URL, at page: Int?, nextTo window: NSWindow?) {
        if let state = ReaderState.open(for: url) {
            if let page { state.primary.goToPage(page) }
            state.primary.pdfView.window?.makeKeyAndOrderFront(nil)
            state.primary.focusDocument()
            return
        }
        pendingHost = window
        if let page { pendingPages[url.standardizedFileURL] = page }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            MainActor.assumeIsolated {
                pendingHost = nil
                pendingPages[url.standardizedFileURL] = nil
                if let error { NSApp.presentError(error) }
            }
        }
    }

    /// The page to show first in a document that was opened at a page, once.
    static func takePendingPage(for url: URL?) -> Int? {
        guard let url else { return nil }
        return pendingPages.removeValue(forKey: url.standardizedFileURL)
    }

    /// Puts a newly opened document window into the tabs of the window it was opened from.
    static func adopt(_ window: NSWindow) {
        guard let host = pendingHost, host !== window else { return }
        pendingHost = nil
        if host.tabbedWindows?.contains(window) ?? false { return }
        host.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Settings

/// The settings for references into other documents: where they open, and the assigned files.
struct ReferenceSettings: View {
    @AppStorage(OtherDocuments.openingKey) private var opening = OtherDocumentOpening.tab.rawValue
    private let store = OtherDocuments.shared

    private var sorted: [OtherDocuments.Assignment] {
        store.assignments.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                Picker("Dokumente öffnen", selection: $opening) {
                    ForEach(OtherDocumentOpening.allCases) { Text($0.title).tag($0.rawValue) }
                }
            } footer: {
                SettingsFooter("Nennt ein Dokument eine Seite in einem anderen Dokument, etwa „Titel, S. 12“, öffnet ein Klick darauf das andere Dokument an dieser Seite. Welche Datei zu einem Titel gehört, fragt Leser beim ersten Mal. Links in andere Dateien funktionieren genauso.")
            }
            Section("Zugeordnete Dokumente") {
                if sorted.isEmpty {
                    Text("Noch keine Dokumente zugeordnet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { assignment in
                        AssignmentRow(assignment: assignment)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        // Short lists keep the window small, long ones scroll.
        .frame(height: min(200 + CGFloat(max(sorted.count, 1)) * 44, 560))
    }
}

/// An assigned title: the title and its file, the full path when the pointer rests on the file,
/// and a button to show the file in the Finder.
private struct AssignmentRow: View {
    let assignment: OtherDocuments.Assignment
    private let store = OtherDocuments.shared

    var body: some View {
        let url = store.file(for: assignment.title)
        LabeledContent {
            HStack(spacing: 6) {
                Text(assignment.fileName)
                    .foregroundStyle(url == nil ? .red : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url?.path ?? String(localized: "Die Datei wurde nicht gefunden."))
                Button {
                    if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(url == nil)
                .help("Im Finder zeigen")
                .accessibilityLabel("Im Finder zeigen")
                Menu {
                    Button("Andere Datei zuordnen …") { reassign() }
                    Button("Zuordnung entfernen", role: .destructive) { store.remove(assignment) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Weitere Aktionen")
            }
        } label: {
            Text(assignment.title)
                .lineLimit(1)
        }
        .contextMenu {
            Button("Im Finder zeigen") {
                if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            .disabled(url == nil)
            Button("Andere Datei zuordnen …") { reassign() }
            Divider()
            Button("Zuordnung entfernen") { store.remove(assignment) }
        }
    }

    private func reassign() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.message = String(localized: "Welche Datei ist „\(assignment.title)“?")
        panel.prompt = String(localized: "Zuordnen")
        panel.directoryURL = store.file(for: assignment.title)?.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            store.assign(url, to: assignment.title)
        }
    }
}

// MARK: - Links into other files

/// Reads where links into other files lead ("GoToR" actions) from the PDF itself.
enum RemoteLinks {
    /// The name of the file a link leads to and the index of the page in it.
    static func target(of link: PDFAnnotation, on page: PDFPage) -> (file: String, page: Int)? {
        guard let dictionary = page.pageRef?.dictionary else { return nil }
        var annotations: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Annots", &annotations), let annotations else { return nil }
        for index in 0..<CGPDFArrayGetCount(annotations) {
            var annotation: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(annotations, index, &annotation), let annotation,
                  let rect = rect(in: annotation), rect.insetBy(dx: -1, dy: -1).contains(link.bounds.center),
                  let target = goToR(in: annotation)
            else { continue }
            return target
        }
        return nil
    }

    private static func goToR(in annotation: CGPDFDictionaryRef) -> (file: String, page: Int)? {
        var action: CGPDFDictionaryRef?
        var kind: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetDictionary(annotation, "A", &action), let action,
              CGPDFDictionaryGetName(action, "S", &kind), let kind, String(cString: kind) == "GoToR",
              let file = fileName(in: action)
        else { return nil }
        // The page as an index, first in the destination array; a named destination counts as
        // the first page.
        var destination: CGPDFArrayRef?
        var page: CGPDFInteger = 0
        if CGPDFDictionaryGetArray(action, "D", &destination), let destination {
            _ = CGPDFArrayGetInteger(destination, 0, &page)
        }
        return (file, max(0, Int(page)))
    }

    /// The file of an action: a string, or a file specification with one.
    private static func fileName(in action: CGPDFDictionaryRef) -> String? {
        var string: CGPDFStringRef?
        if CGPDFDictionaryGetString(action, "F", &string), let string,
           let text = CGPDFStringCopyTextString(string) as String? {
            return (text as NSString).lastPathComponent
        }
        var specification: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(action, "F", &specification), let specification else { return nil }
        for key in ["UF", "F"] {
            if CGPDFDictionaryGetString(specification, key, &string), let string,
               let text = CGPDFStringCopyTextString(string) as String? {
                return (text as NSString).lastPathComponent
            }
        }
        return nil
    }

    private static func rect(in annotation: CGPDFDictionaryRef) -> CGRect? {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(annotation, "Rect", &array), let array,
              CGPDFArrayGetCount(array) == 4
        else { return nil }
        var values = [CGPDFReal](repeating: 0, count: 4)
        for index in 0..<4 { guard CGPDFArrayGetNumber(array, index, &values[index]) else { return nil } }
        return CGRect(x: min(values[0], values[2]), y: min(values[1], values[3]),
                      width: abs(values[2] - values[0]), height: abs(values[3] - values[1]))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
