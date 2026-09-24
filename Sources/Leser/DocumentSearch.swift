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

/// A view that searches its document through `DocumentSearch`.
@MainActor
protocol DocumentSearchClient: AnyObject {
    func searchDidFind(_ selection: PDFSelection)
    func searchDidFinish()
    /// Another view's search took over the document. The search starts again from the
    /// beginning once that one has finished, so the results found so far are to be dropped.
    func searchWasInterrupted()
}

/// Runs the text searches of all views that show the same document.
///
/// PDFKit searches a document for one query at a time and posts every match and the end of the
/// search to whoever observes the document. The two halves of a split window share one document,
/// so on their own a search in one half would cancel a running search in the other, leaving it
/// with partial results, and would hand its matches to both halves. Here each search belongs to
/// one view: matches go only to that view, and a search interrupted by another view's search is
/// started again once that one has finished. The latest search runs first.
@MainActor
final class DocumentSearch {
    private struct Request {
        weak var client: (any DocumentSearchClient)?
        let query: String
        let options: NSString.CompareOptions
    }

    /// One coordinator per document, only while something is searched in it. Holding the
    /// document keeps its identifier from being reused for another one in the meantime.
    private static var searches: [ObjectIdentifier: DocumentSearch] = [:]

    private let document: PDFDocument
    private var current: Request?
    private var waiting: [Request] = []
    /// PDFKit notifies in order: begin, matches, end — also for a cancelled search, whose end
    /// may arrive right away or only later. Whatever comes before the current search has begun
    /// therefore belongs to an earlier one and is ignored.
    private var awaitingBegin = false
    private var observers: [NSObjectProtocol] = []

    static func start(_ query: String, options: NSString.CompareOptions,
                      in document: PDFDocument, for client: any DocumentSearchClient) {
        let search = searches[ObjectIdentifier(document)] ?? DocumentSearch(document: document)
        search.start(Request(client: client, query: query, options: options))
    }

    static func stop(in document: PDFDocument, for client: any DocumentSearchClient) {
        searches[ObjectIdentifier(document)]?.stop(for: client)
    }

    private init(document: PDFDocument) {
        self.document = document
        Self.searches[ObjectIdentifier(document)] = self
        let center = NotificationCenter.default
        func observe(_ name: Notification.Name, _ handler: @escaping (DocumentSearch, Notification) -> Void) {
            observers.append(center.addObserver(forName: name, object: document, queue: .main) { [weak self] note in
                nonisolated(unsafe) let note = note
                MainActor.assumeIsolated {
                    if let self { handler(self, note) }
                }
            })
        }
        observe(.PDFDocumentDidBeginFind) { search, _ in search.awaitingBegin = false }
        observe(.PDFDocumentDidFindMatch) { search, note in
            guard !search.awaitingBegin,
                  let selection = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection
            else { return }
            search.current?.client?.searchDidFind(selection)
        }
        observe(.PDFDocumentDidEndFind) { search, _ in search.searchEnded() }
    }

    private func start(_ request: Request) {
        waiting.removeAll { $0.client == nil || $0.client === request.client }
        if let running = current {
            cancelCurrent()
            if running.client !== request.client, let client = running.client {
                client.searchWasInterrupted()
                waiting.insert(running, at: 0)
            }
        }
        begin(request)
    }

    private func stop(for client: any DocumentSearchClient) {
        waiting.removeAll { $0.client == nil || $0.client === client }
        if current?.client === client {
            cancelCurrent()
            beginNextOrFinish()
        } else if current == nil {
            beginNextOrFinish()
        }
    }

    private func begin(_ request: Request) {
        current = request
        awaitingBegin = true
        document.beginFindString(request.query, withOptions: request.options)
    }

    private func cancelCurrent() {
        current = nil
        awaitingBegin = true
        document.cancelFindString()
    }

    private func searchEnded() {
        guard !awaitingBegin else { return }
        let finished = current
        current = nil
        finished?.client?.searchDidFinish()
        // Not from within the end notification itself: PDFKit is still winding down the
        // finished search at that point and drops a search begun there without a word.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.beginNextOrFinish() }
        }
    }

    private func beginNextOrFinish() {
        guard current == nil else { return }
        while !waiting.isEmpty {
            let next = waiting.removeFirst()
            if next.client != nil {
                begin(next)
                return
            }
        }
        // Nothing left to search: let go of the document. The end of a cancelled search may
        // still be on its way; it reaches nobody now, or is ignored by the next coordinator
        // because it arrives before that one's search has begun.
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        Self.searches[ObjectIdentifier(document)] = nil
    }
}
