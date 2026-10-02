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

/// Books that references in the text point to, like "Kernregeln: Monster, S. 284", each
/// assigned to a file by the user the first time one of its references is followed. The
/// assignments hold for all documents.
///
/// In the sandbox Leser may only open files the user chose; a security-scoped bookmark keeps
/// that permission for a chosen file across launches.
@MainActor
@Observable
final class OtherBooks {
    static let shared = OtherBooks()

    struct Book: Codable, Identifiable {
        /// The title as it appeared in the reference it was assigned for.
        var title: String
        /// File name, to show without resolving the bookmark.
        var fileName: String
        var bookmark: Data

        var id: String { OtherBooks.key(for: title) }
    }

    nonisolated private static let defaultsKey = "otherBooks"
    nonisolated static let openingKey = "otherBookOpening"

    /// Assigned books by the key of their title.
    private(set) var books: [String: Book] = [:]
    /// Counts the changes, so that references found before can be found again.
    private(set) var revision = 0

    @ObservationIgnored private var files: [String: URL] = [:]
    @ObservationIgnored private var documents: [URL: (document: PDFDocument, references: PageReferences)] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([String: Book].self, from: data) {
            books = stored
        }
    }

    // MARK: Titles

    /// A title compared without case, punctuation and line breaks, and without a leading
    /// "Pathfinder": "Pathfinder Kernregeln: Monster" is "Kernregeln: Monster".
    nonisolated static func key(for title: String) -> String {
        var key = PageReferences.joined(title).lowercased()
            .replacingOccurrences(of: #"[^\p{L}\d]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if key.hasPrefix("pathfinder ") { key.removeFirst("pathfinder ".count) }
        return key == "pathfinder" ? "" : key
    }

    static var revision: Int { shared.revision }

    static func isKnown(_ title: String) -> Bool {
        shared.books[key(for: title)] != nil
    }

    // MARK: Assigning files

    func assign(_ url: URL, to title: String) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        let key = Self.key(for: title)
        books[key] = Book(title: title, fileName: url.lastPathComponent, bookmark: bookmark)
        files[key] = nil
        store()
    }

    func remove(_ book: Book) {
        books[book.id] = nil
        files[book.id] = nil
        store()
    }

    private func store() {
        revision += 1
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// The file assigned to a title, with access to it for as long as Leser runs.
    func file(for title: String) -> URL? {
        let key = Self.key(for: title)
        if let url = files[key] { return url }
        guard let book = books[key] else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: book.bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource()
        else { return nil }
        // Moved or renamed: keep the bookmark up to date.
        if stale { assign(url, to: book.title) }
        files[key] = url
        return url
    }

    // MARK: Pages

    /// The document assigned to a title and the index of the page with a number in it.
    func page(_ number: Int, of title: String) -> (url: URL, document: PDFDocument, index: Int?)? {
        guard let url = file(for: title) else { return nil }
        let entry: (document: PDFDocument, references: PageReferences)
        if let cached = documents[url] {
            entry = cached
        } else {
            guard let document = PDFDocument(url: url), !document.isLocked else { return nil }
            entry = (document, PageReferences(document: document, name: url.lastPathComponent))
            documents[url] = entry
        }
        return (url, entry.document, entry.references.pageIndex(forNumber: number))
    }

    // MARK: Following a reference

    /// Opens the page a reference into another book gives. An unknown title is assigned to a
    /// file first, chosen by the user.
    func follow(title: String, number: Int, from state: ReaderState) {
        if file(for: title) != nil {
            open(title: title, number: number, from: state)
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.message = String(localized: "Welche Datei ist „\(title)“?")
        panel.prompt = String(localized: "Zuordnen")
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self, weak state] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                guard let self, let state else { return }
                self.assign(url, to: title)
                self.open(title: title, number: number, from: state)
            }
        }
        if let window = state.primary.pdfView.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func open(title: String, number: Int, from state: ReaderState) {
        guard let page = page(number, of: title) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "„\(title)“ konnte nicht geöffnet werden.")
            alert.informativeText = String(localized: "Die zugeordnete Datei fehlt oder ist kein lesbares PDF-Dokument. In den Einstellungen unter „Andere Bücher“ kannst du ihr eine andere Datei zuordnen.")
            if let window = state.primary.pdfView.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
            return
        }
        switch OtherBookOpening.current {
        case .tab:
            DocumentTabs.open(page.url, at: page.index, nextTo: state.primary.pdfView.window)
        case .split:
            state.showInSecondView(page.url, at: page.index)
        }
    }
}

/// Where a book opens when a reference into it is followed.
enum OtherBookOpening: String, CaseIterable, Identifiable {
    case tab, split

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tab: "In einem neuen Tab"
        case .split: "In der zweiten Ansicht"
        }
    }

    static var current: OtherBookOpening {
        OtherBookOpening(rawValue: UserDefaults.standard.string(forKey: OtherBooks.openingKey) ?? "") ?? .tab
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

/// The settings for references into other books: where they open, and the assigned files.
struct OtherBooksSettings: View {
    @AppStorage(OtherBooks.openingKey) private var opening = OtherBookOpening.tab.rawValue
    @State private var showsBooks = false
    private let books = OtherBooks.shared

    var body: some View {
        Section {
            Picker("Bücher öffnen", selection: $opening) {
                ForEach(OtherBookOpening.allCases) { Text($0.title).tag($0.rawValue) }
            }
            LabeledContent("Zugeordnete Bücher") {
                HStack {
                    Text(verbatim: "\(books.books.count)")
                        .foregroundStyle(.secondary)
                    Button("Bearbeiten …") { showsBooks = true }
                }
            }
        } header: {
            Text("Andere Bücher")
        } footer: {
            Text("Verweise wie „Kernregeln: Monster, S. 284“ öffnen das genannte Buch an dieser Seite. Beim ersten Mal fragt Leser, welche Datei zu dem Buch gehört.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showsBooks) {
            OtherBooksList()
        }
    }
}

private struct OtherBooksList: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String?
    private let books = OtherBooks.shared

    private var sorted: [OtherBooks.Book] {
        books.books.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zugeordnete Bücher")
                .font(.headline)
            Table(sorted, selection: $selection) {
                TableColumn("Buch", value: \.title)
                TableColumn("Datei", value: \.fileName)
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let book = ids.first.flatMap({ books.books[$0] }) {
                    Button("Andere Datei zuordnen …") { reassign(book) }
                    Button("Zuordnung entfernen") { books.remove(book) }
                }
            }
            .onDeleteCommand { removeSelection() }
            .overlay {
                if books.books.isEmpty {
                    Text("Noch keine Bücher zugeordnet")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Entfernen") { removeSelection() }
                    .disabled(selection == nil)
                Button("Andere Datei zuordnen …") {
                    if let book = selection.flatMap({ books.books[$0] }) { reassign(book) }
                }
                .disabled(selection == nil)
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 340)
    }

    private func removeSelection() {
        guard let book = selection.flatMap({ books.books[$0] }) else { return }
        books.remove(book)
        selection = nil
    }

    private func reassign(_ book: OtherBooks.Book) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.message = String(localized: "Welche Datei ist „\(book.title)“?")
        panel.prompt = String(localized: "Zuordnen")
        if panel.runModal() == .OK, let url = panel.url {
            books.assign(url, to: book.title)
        }
    }
}
