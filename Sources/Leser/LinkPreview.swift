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
import PDFKit

/// Shows where a link inside the document leads while the pointer rests on it, without going
/// there: the target page from the place the link points to, in a small popover. Page
/// references in the text, like "(page 359)", count as links too, and so do references into
/// other documents, like "(Handbuch: Technik, S. 284)", once a file is assigned to their title.
@MainActor
final class LinkPreview {
    /// Something the pointer can rest on that leads elsewhere in the document.
    private struct Target {
        /// Tells targets apart: the link annotation, or the reference's page and position.
        let id: AnyHashable
        let page: PDFPage
        /// The area on the page the popover points at, in page coordinates.
        let bounds: CGRect
        let content: Content
    }

    private enum Content {
        /// The place the target leads to, shown as a picture of its page.
        case destination(PDFDestination)
        /// A note instead, for a title not assigned to a file yet, for instance.
        case message(String)
    }

    private weak var view: ReaderPDFView?
    private var timer: Timer?
    private var popover: NSPopover?
    /// The target the pointer is on, or whose preview is shown.
    private var current: Target?

    /// How long the pointer has to rest on a link before its preview appears.
    private static let delay: TimeInterval = 0.5
    /// Width of the preview in points.
    private static let width: CGFloat = 420

    init(view: ReaderPDFView) {
        self.view = view
    }

    /// Follows the pointer: starts the preview for a link it rests on, ends it when it leaves.
    func pointerMoved(to location: NSPoint) {
        let target = target(at: location)
        guard target?.id != current?.id else { return }
        close()
        current = target
        guard target != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.show() }
        }
    }

    /// Ends the preview, for instance on a click, a scroll or when the pointer leaves the view.
    func close() {
        timer?.invalidate()
        timer = nil
        popover?.close()
        popover = nil
        current = nil
    }

    private func show() {
        guard let view, let target = current else { return }
        let content: NSView
        switch target.content {
        case .destination(let destination):
            guard let image = Self.image(of: destination) else { return }
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleNone
            imageView.frame = NSRect(origin: .zero, size: image.size)
            PageTone.apply(to: imageView)
            content = imageView
        case .message(let text):
            content = Self.messageView(text)
        }
        let controller = NSViewController()
        controller.view = content

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.contentSize = content.frame.size
        popover.behavior = .applicationDefined
        popover.animates = true
        let anchor = view.convert(target.bounds, from: target.page)
        // Above a reference in the lower half of the view, below one in the upper half, so
        // that the preview stays over the document rather than the toolbar.
        let upper = view.isFlipped ? anchor.midY < view.bounds.midY : anchor.midY > view.bounds.midY
        popover.show(relativeTo: anchor, of: view, preferredEdge: upper != view.isFlipped ? .minY : .maxY)
        self.popover = popover
    }

    /// PDFKit shows its own tooltip on a link, "Go to page 84", which would cover the preview
    /// and counts the position in the file rather than the printed page number. It sets the
    /// tooltip up as the pointer moves, so it is taken off again right after, through the
    /// public tooltip methods of the views showing the pages; only while the pointer is on a
    /// link inside the document, so that other tooltips, of notes for instance, stay.
    private func removeLinkToolTips() {
        func remove(in view: NSView) {
            view.removeAllToolTips()
            view.subviews.forEach(remove)
        }
        if let documentView = view?.documentView { remove(in: documentView) }
    }

    /// A link or page reference at a point of the view that leads somewhere in this document,
    /// or into another one.
    private func target(at location: NSPoint) -> Target? {
        if let link = internalLink(at: location), let page = link.page,
           let destination = Self.destination(of: link) {
            removeLinkToolTips()
            return Target(id: ObjectIdentifier(link), page: page, bounds: link.bounds,
                          content: .destination(destination))
        }
        if let remote = view?.remoteLink(at: location), let page = remote.link.page {
            removeLinkToolTips()
            return Target(id: ObjectIdentifier(remote.link), page: page, bounds: remote.link.bounds,
                          content: Self.content(of: .index(remote.page), in: remote.file))
        }
        guard let view, let (page, reference) = view.pageReference(at: location) else { return nil }
        let content: Content
        switch reference.target {
        case .page(let index):
            guard let targetPage = view.document?.page(at: index) else { return nil }
            content = .destination(Self.top(of: targetPage))
        case .document(let title, let number):
            content = Self.content(of: .number(number), in: title)
        }
        let bounds = reference.bounds.dropFirst().reduce(reference.bounds[0]) { $0.union($1) }
        return Target(id: [ObjectIdentifier(page), reference.location] as [AnyHashable],
                      page: page, bounds: bounds, content: content)
    }

    /// The page of another document, or what keeps it from being shown.
    private static func content(of pointer: OtherDocuments.Page, in title: String) -> Content {
        guard OtherDocuments.isKnown(title) else {
            return .message(String(localized: "„\(title)“ ist noch keiner Datei zugeordnet. Klicke, um die Datei zu wählen."))
        }
        guard let other = OtherDocuments.shared.page(pointer, of: title) else {
            return .message(String(localized: "Die Datei für „\(title)“ fehlt oder kann nicht gelesen werden."))
        }
        guard let index = other.index, let page = other.document.page(at: index) else {
            switch pointer {
            case .number(let number):
                return .message(String(localized: "„\(title)“ hat keine Seite \(number)."))
            case .index(let index):
                return .message(String(localized: "„\(title)“ hat keine Seite \(index + 1)."))
            }
        }
        return .destination(top(of: page))
    }

    private static func top(of page: PDFPage) -> PDFDestination {
        let unspecified = CGFloat(kPDFDestinationUnspecifiedValue)
        return PDFDestination(page: page, at: CGPoint(x: unspecified, y: unspecified))
    }

    private static func messageView(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = 260
        let size = label.fittingSize
        label.frame = NSRect(x: 12, y: 10, width: size.width, height: size.height)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: size.width + 24, height: size.height + 20))
        container.addSubview(label)
        return container
    }

    /// A link at a point of the view that leads somewhere in this document.
    private func internalLink(at location: NSPoint) -> PDFAnnotation? {
        guard let annotation = link(at: location), let page = annotation.page,
              let destination = Self.destination(of: annotation),
              let target = destination.page, target.document === page.document
        else { return nil }
        return annotation
    }

    private func link(at location: NSPoint) -> PDFAnnotation? {
        guard let view, let page = view.page(for: location, nearest: false),
              let annotation = page.annotation(at: view.convert(location, to: page)),
              annotation.type == "Link"
        else { return nil }
        return annotation
    }

    private static func destination(of link: PDFAnnotation) -> PDFDestination? {
        link.destination ?? (link.action as? PDFActionGoTo)?.destination
    }

    /// The target page from the place the link points to, or from its top if the link names
    /// no place, as wide as the page and about half as high.
    private static func image(of destination: PDFDestination) -> NSImage? {
        guard let page = destination.page else { return nil }
        let box = page.bounds(for: .cropBox)
        let unspecified = CGFloat(kPDFDestinationUnspecifiedValue)
        let pointY = destination.point.y
        let top = pointY == unspecified || !pointY.isFinite ? box.maxY : min(box.maxY, pointY + 12)
        let height = min(box.height, box.width * 0.55)
        let rect = CGRect(x: box.minX, y: max(box.minY, top - height), width: box.width, height: height)
        let scale = width / rect.width
        let size = CGSize(width: width, height: (rect.height * scale).rounded())
        return NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -rect.minX, y: -rect.minY)
            page.draw(with: .cropBox, to: context)
            return true
        }
    }
}
