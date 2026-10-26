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
import Testing
@testable import Leser

/// Sepia: a cream laid over the pages instead of a filter on them, so the text stays sharp.
@MainActor
@Suite(.serialized)
struct PageToneTests {
    @Test func creamLiesOverThePagesOnly() async throws {
        try await keepingDefaults([PageTone.sepiaKey]) {
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
            let page = CGRect(x: 20, y: 30, width: 200, height: 300)
            UserDefaults.standard.set(true, forKey: PageTone.sepiaKey)
            let overlay = try #require(PageTone.apply(to: view) { [page] })
            // The pages are not filtered, only covered.
            #expect(view.layer?.filters?.isEmpty ?? true)
            #expect(overlay.layer?.compositingFilter != nil)
            let mask = try #require(overlay.layer?.mask as? CAShapeLayer)
            #expect(mask.path?.boundingBox == page)
            // Applied again with the same setting, nothing is added.
            PageTone.apply(to: view) { [page] }
            #expect(view.subviews.filter { $0 is SepiaOverlay }.count == 1)

            UserDefaults.standard.set(false, forKey: PageTone.sepiaKey)
            PageTone.apply(to: view)
            #expect(!view.subviews.contains { $0 is SepiaOverlay })
        }
    }

    @Test func withoutPagesTheWholeViewIsTinted() async throws {
        try await keepingDefaults([PageTone.sepiaKey]) {
            UserDefaults.standard.set(true, forKey: PageTone.sepiaKey)
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            let overlay = try #require(PageTone.apply(to: view))
            #expect(overlay.layer?.mask == nil)
            #expect(overlay.frame == view.bounds)
        }
    }
}
