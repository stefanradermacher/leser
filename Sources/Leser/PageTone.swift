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

    /// Tints a view showing pages, or takes the tint off again. Does nothing if the view
    /// already shows the setting, since it is called on every change of the user defaults,
    /// and Leser writes those while turning pages.
    static func apply(to view: NSView?) {
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
