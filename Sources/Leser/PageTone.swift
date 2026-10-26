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
import CoreImage

/// Sepia: the pages tinted like warm paper, gentler on the eyes than bright white for long
/// reading. Only the display changes; printing, copying and the file stay as they are.
///
/// A dark page as in Preview is left out on purpose: Preview uses a part of PDFKit that is not
/// public and so not open to apps in the App Store, and inverting the colours instead turns
/// every picture into a negative.
enum PageTone {
    static let sepiaKey = "sepiaPages"

    static var isSepia: Bool {
        UserDefaults.standard.bool(forKey: sepiaKey)
    }

    /// Tints a view, or takes the tint off again, with a cream laid over it. `pages` gives the
    /// rectangles to tint, in the view's coordinates; without it, the whole view is tinted.
    /// Does nothing if the view already shows the setting, since it is called on every change
    /// of the user defaults, and Leser writes those while turning pages.
    @discardableResult
    static func apply(to view: NSView?, pages: (() -> [CGRect])? = nil) -> SepiaOverlay? {
        guard let view else { return nil }
        let overlay = view.subviews.first { $0 is SepiaOverlay } as? SepiaOverlay
        if (overlay != nil) == isSepia { return overlay }
        if isSepia {
            view.wantsLayer = true
            view.layerUsesCoreImageFilters = true
            let tint = SepiaOverlay(frame: view.bounds)
            tint.autoresizingMask = [.width, .height]
            tint.pages = pages
            view.addSubview(tint)
            tint.updateMask()
            return tint
        }
        overlay?.removeFromSuperview()
        return nil
    }

    /// Tints the thumbnails with a filter on their own layer. A cream laid over them would
    /// also tint the sidebar around them, and the filter's slight softness does not matter
    /// for pictures this small.
    static func applyFilter(to view: NSView?) {
        guard let view else { return }
        let tinted = !(view.layer?.filters?.isEmpty ?? true)
        guard tinted != isSepia else { return }
        view.wantsLayer = true
        view.layerUsesCoreImageFilters = true
        view.layer?.filters = isSepia ? [sepiaFilter()] : nil
    }

    /// White becomes a warm cream; black and the colours of pictures stay close to themselves.
    private static func sepiaFilter() -> CIFilter {
        let filter = CIFilter(name: "CIColorMatrix")!
        filter.setValue(CIVector(x: 0.98, y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0, y: 0.93, z: 0, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0.80, w: 0), forKey: "inputBVector")
        return filter
    }
}

/// A warm cream laid over the pages and multiplied with them: white becomes cream, black stays
/// black, and the colours of pictures stay close to themselves, exactly as the colour matrix
/// of the filter does. A filter on the pages' own layer renders them through an image of its
/// own, which made the text look soft; this way the pages are drawn in full sharpness and
/// only tinted.
final class SepiaOverlay: NSView {
    /// What white turns into: each colour multiplied by these shares of red, green and blue.
    static let cream = CGColor(srgbRed: 0.98, green: 0.93, blue: 0.80, alpha: 1)

    /// The rectangles to tint, in the coordinates of the view below; nil tints all of it.
    var pages: (() -> [CGRect])?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Self.cream
        layer?.compositingFilter = CIFilter(name: "CIMultiplyBlendMode")
        // Above the views PDFKit adds for pages as they come into view, below the frame of a
        // rectangular selection.
        layer?.zPosition = 999
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Clicks go through to the pages.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        updateMask()
    }

    /// Limits the tint to the pages, so the background around them stays as it is.
    func updateMask() {
        guard let pages, let superview, let layer else {
            layer?.mask = nil
            return
        }
        let path = CGMutablePath()
        for page in pages() { path.addRect(convert(page, from: superview)) }
        let mask = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        mask.frame = bounds
        mask.path = path
        layer.mask = mask
    }
}
