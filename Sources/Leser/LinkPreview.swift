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
/// there: the target page from the place the link points to, in a small popover.
@MainActor
final class LinkPreview {
    private weak var view: PDFView?
    private var timer: Timer?
    private var popover: NSPopover?
    /// The link the pointer is on, or whose preview is shown.
    private var current: PDFAnnotation?

    /// How long the pointer has to rest on a link before its preview appears.
    private static let delay: TimeInterval = 0.5
    /// Width of the preview in points.
    private static let width: CGFloat = 420

    init(view: PDFView) {
        self.view = view
    }

    /// Follows the pointer: starts the preview for a link it rests on, ends it when it leaves.
    func pointerMoved(to location: NSPoint) {
        let link = internalLink(at: location)
        if link != nil { removeLinkToolTips() }
        guard link !== current else { return }
        close()
        current = link
        guard link != nil else { return }
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
        guard let view, let link = current, let page = link.page,
              let destination = Self.destination(of: link),
              let image = Self.image(of: destination)
        else { return }

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleNone
        imageView.frame = NSRect(origin: .zero, size: image.size)
        PageTone.apply(to: imageView)
        let controller = NSViewController()
        controller.view = imageView

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.contentSize = image.size
        popover.behavior = .applicationDefined
        popover.animates = true
        let anchor = view.convert(link.bounds, from: page)
        popover.show(relativeTo: anchor, of: view, preferredEdge: .maxY)
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

    /// A link at a point of the view that leads somewhere in this document.
    private func internalLink(at location: NSPoint) -> PDFAnnotation? {
        guard let view, let page = view.page(for: location, nearest: false) else { return nil }
        let point = view.convert(location, to: page)
        guard let annotation = page.annotation(at: point), annotation.type == "Link",
              let destination = Self.destination(of: annotation),
              let target = destination.page, target.document === page.document
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
