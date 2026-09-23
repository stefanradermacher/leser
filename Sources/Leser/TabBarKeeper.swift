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

/// Shows or hides the tab bar of document windows that hold a single document,
/// according to the user setting. With several tabs macOS always shows the bar.
@MainActor
enum TabBarKeeper {
    private static let windows = NSHashTable<NSWindow>.weakObjects()
    private static var observers: [NSObjectProtocol] = []

    static func track(_ window: NSWindow) {
        startObservingIfNeeded()
        windows.add(window)
        update(window)
    }

    /// Applies the setting to all open document windows.
    static func updateAll() {
        windows.allObjects.forEach(update)
    }

    private static func update(_ window: NSWindow) {
        guard window.isVisible || window.tabbedWindows != nil else { return }
        let group = window.tabGroup
        let isSingle = (group?.windows.count ?? 1) <= 1
        guard isSingle else { return }

        let isVisible = group?.isTabBarVisible ?? false
        if isVisible != Preferences.showSingleTabBar {
            window.toggleTabBar(nil)
        }
    }

    private static func startObservingIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Becoming key covers switching tabs and opening documents;
        // closing a tab can leave a single document behind.
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let window, windows.contains(window) else { return }
                    // Let AppKit finish regrouping the tabs first.
                    DispatchQueue.main.async { updateAll() }
                }
            })
        }
    }
}
