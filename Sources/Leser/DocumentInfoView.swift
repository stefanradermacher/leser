import AppKit
import PDFKit
import SwiftUI

/// Facts about a document, gathered once when the window opens.
struct DocumentInfo {
    struct Entry: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    var file: [Entry] = []
    var metadata: [Entry] = []
    var pages: [Entry] = []
    var security: [Entry] = []
    var location: URL?

    init(document: PDFDocument, location: URL?, displayName: String) {
        self.location = location

        // File
        file.append(Entry(label: "Name", value: location?.lastPathComponent ?? displayName))
        if let location {
            file.append(Entry(label: "Ort", value: (location.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath))
            if let values = try? location.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]) {
                if let size = values.fileSize {
                    file.append(Entry(label: "Größe", value: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))
                }
                if let date = values.creationDate { file.append(Entry(label: "Erstellt", value: Self.format(date))) }
                if let date = values.contentModificationDate { file.append(Entry(label: "Geändert", value: Self.format(date))) }
            }
        }

        // Metadata stored in the PDF
        let attributes = document.documentAttributes ?? [:]
        func text(_ key: PDFDocumentAttribute) -> String? {
            let value: String?
            if let list = attributes[key] as? [String] {
                value = list.joined(separator: ", ")
            } else {
                value = attributes[key] as? String
            }
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        let texts: [(String, PDFDocumentAttribute)] = [
            ("Titel", .titleAttribute), ("Autor", .authorAttribute), ("Thema", .subjectAttribute),
            ("Stichwörter", .keywordsAttribute), ("Erstellt mit", .creatorAttribute), ("PDF erzeugt mit", .producerAttribute),
        ]
        for (label, key) in texts {
            if let value = text(key) { metadata.append(Entry(label: label, value: value)) }
        }
        if let date = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date {
            metadata.append(Entry(label: "Erstellt am", value: Self.format(date)))
        }
        if let date = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date {
            metadata.append(Entry(label: "Geändert am", value: Self.format(date)))
        }
        metadata.append(Entry(label: "PDF-Version", value: "\(document.majorVersion).\(document.minorVersion)"))

        // Pages
        pages.append(Entry(label: "Seiten", value: "\(document.pageCount)"))
        if let size = Self.pageSize(of: document) {
            pages.append(Entry(label: "Seitenformat", value: size))
        }
        pages.append(Entry(label: "Gliederung", value: document.outlineRoot?.numberOfChildren ?? 0 > 0 ? "Ja" : "Nein"))
        pages.append(Entry(label: "Durchsuchbarer Text", value: Self.hasText(document) ? "Ja" : "Nein (z. B. eingescannt)"))

        // Security
        security.append(Entry(label: "Verschlüsselt", value: document.isEncrypted ? "Ja" : "Nein"))
        security.append(Entry(label: "Drucken", value: document.allowsPrinting ? "Erlaubt" : "Nicht erlaubt"))
        security.append(Entry(label: "Text kopieren", value: document.allowsCopying ? "Erlaubt" : "Nicht erlaubt"))
    }

    private static func format(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }

    /// Size of the first page in millimeters, with the paper name where it matches.
    /// Notes when the pages differ in size.
    private static func pageSize(of document: PDFDocument) -> String? {
        func millimeters(_ page: PDFPage) -> CGSize {
            var size = page.bounds(for: .cropBox).size
            if page.rotation % 180 != 0 { swap(&size.width, &size.height) }
            return CGSize(width: size.width / 72 * 25.4, height: size.height / 72 * 25.4)
        }
        guard let first = document.page(at: 0) else { return nil }
        let size = millimeters(first)
        var text = "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) mm"

        let formats: [(String, CGFloat, CGFloat)] = [
            ("A3", 297, 420), ("A4", 210, 297), ("A5", 148, 210), ("A6", 105, 148),
            ("US Letter", 215.9, 279.4), ("US Legal", 215.9, 355.6),
        ]
        let short = min(size.width, size.height), long = max(size.width, size.height)
        let orientation = size.width > size.height ? "Querformat" : "Hochformat"
        if let format = formats.first(where: { abs($0.1 - short) < 2 && abs($0.2 - long) < 2 }) {
            text += " (\(format.0), \(orientation))"
        } else {
            text += " (\(orientation))"
        }

        let differs = (1..<min(document.pageCount, 500)).contains { index in
            guard let page = document.page(at: index) else { return false }
            let other = millimeters(page)
            return abs(other.width - size.width) > 1 || abs(other.height - size.height) > 1
        }
        if differs { text += ", Seiten unterschiedlich groß" }
        return text
    }

    /// Checks the first pages for a text layer.
    private static func hasText(_ document: PDFDocument) -> Bool {
        (0..<min(document.pageCount, 10)).contains { index in
            let text = document.page(at: index)?.string ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct DocumentInfoView: View {
    let info: DocumentInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                section("Datei", info.file)
                section("Dokument", info.metadata)
                section("Seiten", info.pages)
                section("Sicherheit", info.security)
            }
            .formStyle(.grouped)
            .textSelection(.enabled)

            HStack {
                if let location = info.location {
                    Button("Im Finder zeigen") {
                        NSWorkspace.shared.activateFileViewerSelecting([location])
                    }
                }
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        // Fits into smaller windows too; the list scrolls, the buttons stay visible.
        .frame(width: 480, height: 600)
    }

    @ViewBuilder
    private func section(_ title: String, _ entries: [DocumentInfo.Entry]) -> some View {
        if !entries.isEmpty {
            Section(title) {
                ForEach(entries) { entry in
                    LabeledContent(entry.label) {
                        Text(entry.value)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }
}
