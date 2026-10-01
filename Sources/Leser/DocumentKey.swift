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

import CryptoKit
import Foundation
import PDFKit

/// Identifies a PDF by what it is rather than where its file lies, for the reading position
/// and the bookmarks.
///
/// The program that creates a PDF gives it an identifier, of which the first half is meant to
/// stay the same for good, also when the document is changed later. Copies of a file share it,
/// moving or renaming the file keeps it, and it says nothing about the user, unlike a path with
/// the user's name in it. The page count is added, so that a document derived from another one
/// that kept its identifier, an extract for instance, is told apart. A PDF without an
/// identifier is recognised by a checksum of its content instead, which a change to the file
/// does not survive.
enum DocumentKey {
    static func key(for document: PDFDocument, fileURL: URL?) -> String? {
        let pages = document.pageCount
        if let identifier = permanentIdentifier(of: document) {
            return "id:\(identifier):\(pages)"
        }
        let data = (fileURL ?? document.documentURL).flatMap { try? Data(contentsOf: $0, options: .mappedIfSafe) }
            ?? document.dataRepresentation()
        guard let data, !data.isEmpty else { return nil }
        return "sha256:\(hex(Array(SHA256.hash(data: data)))):\(pages)"
    }

    private static func permanentIdentifier(of document: PDFDocument) -> String? {
        guard let identifiers = document.documentRef?.fileIdentifier else { return nil }
        var first: CGPDFStringRef?
        guard CGPDFArrayGetString(identifiers, 0, &first), let first,
              let bytes = CGPDFStringGetBytePtr(first)
        else { return nil }
        let value = Array(UnsafeBufferPointer(start: bytes, count: CGPDFStringGetLength(first)))
        // Some programs write an empty or all-zero identifier, which identifies nothing.
        guard value.contains(where: { $0 != 0 }) else { return nil }
        return hex(value)
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
