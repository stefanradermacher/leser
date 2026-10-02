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

import Foundation
import PDFKit
import Testing
@testable import Leser

/// What Leser remembers about documents: their key, reading positions and bookmarks.
@MainActor
@Suite(.serialized)
struct StorageTests {
    // MARK: Document key

    @Test func keyFromTheDocumentIdentifier() {
        var pdf = TestPDF(texts: ["Eins", "Zwei", "Drei"])
        pdf.identifier = .bytes([0x01, 0xab, 0xff, 0x10])
        #expect(DocumentKey.key(for: pdf.document(), fileURL: nil) == "id:01abff10:3")
    }

    @Test func sameIdentifierOtherPageCountIsAnotherDocument() {
        var long = TestPDF(texts: ["Eins", "Zwei", "Drei"]), short = TestPDF(texts: ["Eins"])
        long.identifier = .bytes([7, 7, 7]); short.identifier = .bytes([7, 7, 7])
        #expect(DocumentKey.key(for: long.document(), fileURL: nil) != DocumentKey.key(for: short.document(), fileURL: nil))
    }

    @Test func withoutUsableIdentifierTheContentCounts() throws {
        var none = TestPDF(texts: ["Eins", "Zwei"])
        none.identifier = .none
        let data = none.data()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LeserTests-\(UUID().uuidString).pdf")
        try data.write(to: url)
        let key = try #require(DocumentKey.key(for: PDFDocument(data: data)!, fileURL: url))
        #expect(key.hasPrefix("sha256:") && key.hasSuffix(":2"))
        // A copy of the file elsewhere is the same document.
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("LeserTests-\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: url, to: copy)
        #expect(DocumentKey.key(for: PDFDocument(url: copy)!, fileURL: copy) == key)

        var zero = TestPDF(texts: ["Eins"])
        zero.identifier = .bytes([0, 0, 0, 0])
        #expect(DocumentKey.key(for: zero.document(), fileURL: nil)?.hasPrefix("sha256:") == true)
    }

    // MARK: Reading positions

    private let positionsKey = "readingPositions"

    private func position(page: Int, daysAgo: Double = 0) -> Preferences.ReadingPosition {
        Preferences.ReadingPosition(page: page, x: 10, y: 20, date: Date(timeIntervalSinceNow: -daysAgo * 86_400))
    }

    @Test func readingPositionIsStoredByKey() async {
        await keepingDefaults([positionsKey]) {
            Preferences.setReadingPosition(position(page: 4), for: "id:test:1")
            #expect(Preferences.readingPosition(for: "id:test:1", legacyPath: nil)?.page == 4)
            #expect(Preferences.readingPosition(for: "id:other:1", legacyPath: nil) == nil)
        }
    }

    @Test func positionStoredUnderAPathMovesToTheKey() async {
        await keepingDefaults([positionsKey]) {
            Preferences.setReadingPosition(position(page: 7), for: "/Users/someone/Dokument.pdf")
            #expect(Preferences.readingPosition(for: "id:neu:1", legacyPath: "/Users/someone/Dokument.pdf")?.page == 7)
            // Moved, not copied: the path is gone, the key stays.
            #expect(Preferences.readingPosition(for: "/Users/someone/Dokument.pdf", legacyPath: nil) == nil)
            #expect(Preferences.readingPosition(for: "id:neu:1", legacyPath: nil)?.page == 7)
        }
    }

    @Test func onlyTheMostRecentPositionsAreKept() async {
        await keepingDefaults([positionsKey]) {
            Preferences.forgetReadingPositions()
            for index in 0..<205 {
                Preferences.setReadingPosition(position(page: index, daysAgo: Double(300 - index)), for: "id:viele:\(index)")
            }
            #expect(Preferences.readingPosition(for: "id:viele:0", legacyPath: nil) == nil)
            #expect(Preferences.readingPosition(for: "id:viele:4", legacyPath: nil) == nil)
            #expect(Preferences.readingPosition(for: "id:viele:5", legacyPath: nil)?.page == 5)
            #expect(Preferences.readingPosition(for: "id:viele:204", legacyPath: nil)?.page == 204)
            Preferences.forgetReadingPositions()
            #expect(Preferences.readingPosition(for: "id:viele:204", legacyPath: nil) == nil)
        }
    }

    // MARK: Bookmarks

    private let bookmarkKeys = ["bookmarks", "bookmarkPaneShares"]

    private func storedBookmarks(_ key: String) -> [Bookmark]? {
        guard let data = UserDefaults.standard.data(forKey: "bookmarks"),
              let all = try? JSONDecoder().decode([String: [Bookmark]].self, from: data)
        else { return nil }
        return all[key]
    }

    @Test func bookmarksAreKeptInDocumentOrder() async {
        await keepingDefaults(bookmarkKeys) {
            let list = BookmarkList.list(for: "test:\(UUID())")
            list.add(name: "Später", page: 5, point: CGPoint(x: 0, y: 300))
            list.add(name: "Oben", page: 2, point: CGPoint(x: 0, y: 700))
            list.add(name: "Unten", page: 2, point: CGPoint(x: 0, y: 100))
            #expect(list.items.map(\.name) == ["Oben", "Unten", "Später"])
            #expect(storedBookmarks(list.key)?.map(\.name) == ["Oben", "Unten", "Später"])
        }
    }

    @Test func renamingAndRemoving() async throws {
        try await keepingDefaults(bookmarkKeys) {
            let list = BookmarkList.list(for: "test:\(UUID())")
            list.add(name: "Erstes", page: 1, point: .zero)
            let id = try #require(list.items.first?.id)
            list.rename(id, to: "  Neuer Name  ")
            #expect(list.items.first?.name == "Neuer Name")
            list.rename(id, to: "   ")
            #expect(list.items.first?.name == "Neuer Name")
            list.remove(id)
            #expect(list.items.isEmpty)
            // An empty list leaves nothing behind in the settings.
            #expect(storedBookmarks(list.key) == nil)
        }
    }

    @Test func bookmarksGoAlongToAReloadedVersion() async {
        await keepingDefaults(bookmarkKeys) {
            let old = BookmarkList.list(for: "test:\(UUID())"), new = BookmarkList.list(for: "test:\(UUID())")
            old.add(name: "Mitnehmen", page: 3, point: .zero)
            BookmarkList.carryOver(from: old.key, to: new.key)
            #expect(new.items.map(\.name) == ["Mitnehmen"])

            // A version that has bookmarks of its own keeps them.
            let other = BookmarkList.list(for: "test:\(UUID())")
            other.add(name: "Eigenes", page: 1, point: .zero)
            BookmarkList.carryOver(from: old.key, to: other.key)
            #expect(other.items.map(\.name) == ["Eigenes"])
        }
    }

    @Test func paneShareIsRememberedPerDocument() async {
        await keepingDefaults(bookmarkKeys) {
            let list = BookmarkList.list(for: "test:\(UUID())")
            list.setPaneShare(0.4)
            #expect((UserDefaults.standard.dictionary(forKey: "bookmarkPaneShares")?[list.key] as? Double) == 0.4)
            list.setPaneShare(nil)
            #expect(UserDefaults.standard.dictionary(forKey: "bookmarkPaneShares")?[list.key] == nil)
            #expect(list.paneShare == nil)
        }
    }
}
