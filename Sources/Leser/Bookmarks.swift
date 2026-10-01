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

import Observation
import PDFKit
import SwiftUI

/// A place in a document the reader wants to come back to. Stored by Leser, not in the PDF.
struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var page: Int
    /// Point on the page in PDF coordinates, shown at the top left when going there.
    var x: Double
    var y: Double

    /// Order in the document: by page, and on a page from top to bottom.
    static func documentOrder(_ a: Bookmark, _ b: Bookmark) -> Bool {
        a.page != b.page ? a.page < b.page : a.y > b.y
    }
}

/// Where a new bookmark is to point, with the names it could get.
struct BookmarkDraft: Identifiable {
    let id = UUID()
    let model: ViewerModel
    let page: Int
    let point: CGPoint
    /// The suggested name first, then the alternatives.
    let names: [String]
}

/// The bookmarks of one document, shared by every view showing it.
@MainActor
@Observable
final class BookmarkList {
    private static let storageKey = "bookmarks"
    private static let paneKey = "bookmarkPaneShares"
    private static var lists: [String: BookmarkList] = [:]

    /// The list for a document, see `DocumentKey`.
    static func list(for key: String) -> BookmarkList {
        if let list = lists[key] { return list }
        let list = BookmarkList(key: key, items: stored()[key] ?? [], paneShare: storedPaneShares()[key])
        lists[key] = list
        return list
    }

    /// A document written anew, a PDF exported again for instance, may get a new identifier.
    /// When it is reloaded in an open window, its bookmarks go along to the new version.
    static func carryOver(from old: String?, to new: String?) {
        guard let old, let new, old != new else { return }
        let source = list(for: old), target = list(for: new)
        guard !source.items.isEmpty, target.items.isEmpty else { return }
        target.items = source.items
        target.save()
    }

    let key: String
    private(set) var items: [Bookmark]
    /// Share of the sidebar the bookmarks take after the reader moved the divider; nil while
    /// the area fits itself to the bookmarks.
    private(set) var paneShare: Double?

    private init(key: String, items: [Bookmark], paneShare: Double?) {
        self.key = key
        self.items = items.sorted(by: Bookmark.documentOrder)
        self.paneShare = paneShare
    }

    func setPaneShare(_ share: Double?) {
        paneShare = share
        var all = Self.storedPaneShares()
        all[key] = share
        UserDefaults.standard.set(all, forKey: Self.paneKey)
    }

    func add(name: String, page: Int, point: CGPoint) {
        items.append(Bookmark(name: name, page: page, x: point.x, y: point.y))
        items.sort(by: Bookmark.documentOrder)
        save()
    }

    func rename(_ id: Bookmark.ID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].name = name
        save()
    }

    func remove(_ id: Bookmark.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    private func save() {
        var all = Self.stored()
        all[key] = items.isEmpty ? nil : items
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func storedPaneShares() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: paneKey) as? [String: Double] ?? [:]
    }

    private static func stored() -> [String: [Bookmark]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [Bookmark]].self, from: data)) ?? [:]
    }
}

// MARK: - Sidebar

/// The bookmarks at the top of the sidebar. A click goes there; a double click, the context
/// menu or Return renames, Delete removes.
struct BookmarkListView: View {
    let model: ViewerModel
    let list: BookmarkList

    @State private var selection: Bookmark.ID?
    @State private var renaming: Bookmark.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Lesezeichen") {
                ForEach(list.items) { bookmark in
                    BookmarkRow(bookmark: bookmark, model: model, list: list, renaming: $renaming)
                        .tag(bookmark.id)
                        .contextMenu {
                            Button("Umbenennen") { renaming = bookmark.id }
                            Button("Löschen") { list.remove(bookmark.id) }
                        }
                }
            }
        }
        .onDeleteCommand {
            if let selection { list.remove(selection) }
        }
        .onKeyPress(.return) {
            guard renaming == nil, let selection else { return .ignored }
            renaming = selection
            return .handled
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let model: ViewerModel
    let list: BookmarkList
    @Binding var renaming: Bookmark.ID?

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if renaming == bookmark.id {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onAppear {
                        name = bookmark.name
                        focused = true
                    }
                    .onSubmit(finish)
                    .onExitCommand { renaming = nil }
                    .onChange(of: focused) { _, isFocused in if !isFocused { finish() } }
            } else {
                Text(bookmark.name)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(model.label(ofPage: bookmark.page))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .help(bookmark.name)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.goTo(bookmark) })
        .simultaneousGesture(TapGesture(count: 2).onEnded { renaming = bookmark.id })
    }

    private func finish() {
        guard renaming == bookmark.id else { return }
        list.rename(bookmark.id, to: name)
        renaming = nil
    }
}

// MARK: - Adding

/// Asks for the name of a new bookmark. The name is suggested from the outline, otherwise
/// the page; the other headings of the page are offered in the menu next to it.
struct AddBookmarkView: View {
    let draft: BookmarkDraft
    let close: () -> Void

    @State private var name: String
    @FocusState private var focused: Bool

    init(draft: BookmarkDraft, close: @escaping () -> Void) {
        self.draft = draft
        self.close = close
        _name = State(initialValue: draft.names.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lesezeichen hinzufügen")
                .font(.headline)
            HStack(spacing: 6) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                    .focused($focused)
                if draft.names.count > 1 {
                    Menu {
                        ForEach(draft.names, id: \.self) { suggestion in
                            Button(suggestion) { name = suggestion }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Namen aus der Gliederung oder der Seite wählen")
                    .accessibilityLabel("Namensvorschläge")
                }
            }
            Text("Seite \(draft.model.label(ofPage: draft.page))")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Abbrechen", action: close)
                    .keyboardShortcut(.cancelAction)
                Button("Hinzufügen", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .onAppear { focused = true }
    }

    private func add() {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        draft.model.bookmarks?.add(name: name, page: draft.page, point: draft.point)
        BookmarkPreferences.reveal()
        close()
    }
}

enum BookmarkPreferences {
    static let showKey = "showBookmarks"

    /// Shows the bookmarks again after one was added, in case they were hidden.
    static func reveal() {
        UserDefaults.standard.set(true, forKey: showKey)
    }
}
