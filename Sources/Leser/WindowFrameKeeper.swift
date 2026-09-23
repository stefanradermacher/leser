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
import SwiftUI

/// Remembers the size and position of the last used document window
/// and opens new windows (also after a restart) with the same frame.
struct WindowFrameKeeper: NSViewRepresentable {
    private static let frameName = "LeserDocumentWindow"

    func makeNSView(context: Context) -> NSView {
        FrameView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class FrameView: NSView {
        private var observers: [NSObjectProtocol] = []
        private weak var trackedWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== trackedWindow else { return }
            trackedWindow = window
            window.tabbingMode = Preferences.tabbing.tabbingMode
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []

            // SwiftUI applies its default size after attaching the view, so restore afterwards.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.restoreFrame(of: window)
                self.observe(window)
                TabBarKeeper.track(window)
            }
        }

        private func restoreFrame(of window: NSWindow) {
            guard window.tabbedWindows == nil || window.tabbedWindows?.count == 1,
                  window.setFrameUsingName(WindowFrameKeeper.frameName)
            else { return }

            // Don't stack a new window exactly on top of an open one.
            let others = NSApp.windows.filter { $0 !== window && $0.isVisible && $0.frame.origin == window.frame.origin }
            if !others.isEmpty {
                var frame = window.frame
                frame.origin.x += 24
                frame.origin.y -= 24
                window.setFrame(window.constrainFrameRect(frame, to: window.screen), display: true)
            }
        }

        private func observe(_ window: NSWindow) {
            let names: [Notification.Name] = [
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
                NSWindow.willCloseNotification,
            ]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { note in
                    guard let window = note.object as? NSWindow,
                          !window.styleMask.contains(.fullScreen)
                    else { return }
                    window.saveFrame(usingName: WindowFrameKeeper.frameName)
                }
            }
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}
