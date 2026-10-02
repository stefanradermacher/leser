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

/// Other documents that references and links lead to, and the files assigned to their titles.
@MainActor
@Suite(.serialized)
struct OtherDocumentTests {
    private let storageKey = "otherDocuments"

    @Test func titlesCompareWithoutCaseAndPunctuation() {
        #expect(OtherDocuments.key(for: "Handbuch: Technik") == "handbuch technik")
        #expect(OtherDocuments.key(for: "Handbuch:  Tech-\nnik") == "handbuch technik")
        #expect(OtherDocuments.key(for: "Atlas der Sterne 2") == "atlas der sterne 2")
        // A series name stays part of the title.
        #expect(OtherDocuments.key(for: "Explorer Field Guide") != OtherDocuments.key(for: "Field Guide"))
    }

    @Test func assigningAndRemovingAFile() async throws {
        try await keepingDefaults([storageKey]) {
            UserDefaults.standard.removeObject(forKey: storageKey)
            let store = OtherDocuments()
            let file = TestPDF(texts: ["Eins", "Zwei"]).write(named: "Regelwerk.pdf")
            let revision = store.revision
            store.assign(file, to: "Handbuch: Technik")
            #expect(store.revision > revision)

            let assignment = try #require(store.assignments[OtherDocuments.key(for: "Handbuch: Technik")])
            #expect(assignment.title == "Handbuch: Technik")
            #expect(assignment.fileName == "Regelwerk.pdf")
            #expect(store.file(for: "handbuch:  technik")?.standardizedFileURL.path == file.standardizedFileURL.path)

            // Kept for the next launch.
            #expect(OtherDocuments().assignments[assignment.id]?.fileName == "Regelwerk.pdf")

            store.remove(assignment)
            #expect(store.file(for: "Handbuch: Technik") == nil)
            #expect(OtherDocuments().assignments.isEmpty)
        }
    }

    @Test func storedAssignmentsAreFiledUnderTheirCurrentKey() async throws {
        try await keepingDefaults([storageKey]) {
            let file = TestPDF(texts: ["Eins"]).write(named: "Atlas.pdf")
            let bookmark = try file.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                 includingResourceValuesForKeys: nil, relativeTo: nil)
            // Stored by an earlier version under a key formed differently.
            let stored = ["atlas sterne": OtherDocuments.Assignment(title: "Atlas der Sterne", fileName: "Atlas.pdf", bookmark: bookmark)]
            UserDefaults.standard.set(try JSONEncoder().encode(stored), forKey: storageKey)
            let store = OtherDocuments()
            #expect(store.assignments[OtherDocuments.key(for: "Atlas der Sterne")] != nil)
            #expect(store.file(for: "Atlas der Sterne") != nil)
        }
    }

    @Test func pageOfAnotherDocumentByNumberOrPosition() async throws {
        try await keepingDefaults([storageKey]) {
            var pdf = TestPDF(texts: Array(repeating: "Text", count: 6))
            pdf.pageLabels = "0 << /S /r >> 2 << /S /D >>"
            UserDefaults.standard.removeObject(forKey: storageKey)
            let store = OtherDocuments()
            store.assign(pdf.write(named: "Handbuch.pdf"), to: "Handbuch")

            let byNumber = try #require(store.page(.number(3), of: "Handbuch"))
            #expect(byNumber.index == 4)
            #expect(byNumber.document.pageCount == 6)
            #expect(try #require(store.page(.index(1), of: "Handbuch")).index == 1)
            // A number or position the document does not have.
            #expect(try #require(store.page(.number(9), of: "Handbuch")).index == nil)
            #expect(try #require(store.page(.index(6), of: "Handbuch")).index == nil)
            #expect(store.page(.number(1), of: "Unbekannt") == nil)
        }
    }

    @Test func linkIntoAnotherFile() throws {
        var pdf = TestPDF(texts: ["Der Drache wirkt Feuerball (Regelwerk, Feuerball)."])
        pdf.links = [TestPDF.Link(page: 0, over: "(Regelwerk, Feuerball)", action: .file("Regelwerk.pdf", page: 6))]
        let page = try #require(pdf.document().page(at: 0))
        let link = try #require(page.annotations.first { $0.action is PDFActionRemoteGoTo })
        let target = try #require(RemoteLinks.target(of: link, on: page))
        #expect(target.file == "Regelwerk.pdf")
        #expect(target.page == 6)
    }

    @Test func linkInsideTheDocumentIsNoLinkIntoAnotherFile() throws {
        var pdf = TestPDF(texts: ["Mehr im Netz."])
        pdf.links = [TestPDF.Link(page: 0, over: "im Netz", action: .url("https://example.com"))]
        let page = try #require(pdf.document().page(at: 0))
        let link = try #require(page.annotations.first)
        #expect(RemoteLinks.target(of: link, on: page) == nil)
    }
}
