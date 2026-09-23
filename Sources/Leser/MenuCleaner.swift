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

/// Removes menu items that make no sense in a viewer that never changes documents:
/// saving, duplicating, renaming, moving and reverting documents, creating new ones,
/// Writing Tools and AutoFill, and the help book Leser does not have.
///
/// Undo, Redo, Cut, Paste and Delete are hidden as well, but keep their keyboard shortcuts,
/// so that ⌘Z, ⌘X and ⌘V still work in the search field and the page field.
/// SwiftUI rebuilds the menu bar now and then, so the cleanup runs at launch, whenever
/// items are added to the menu bar and every time a menu opens.
@MainActor
enum MenuCleaner {
    private static let actions: Set<String> = [
        "newDocument:",
        "saveDocument:",
        "saveDocumentAs:",
        "duplicateDocument:",
        "renameDocument:",
        "moveDocument:",
        "revertDocumentToSaved:",
        "showHelp:",
    ]
    /// Hidden, but their shortcuts stay active for text fields.
    private static let hiddenActions: Set<String> = [
        "undo:",
        "redo:",
        "cut:",
        "paste:",
        "delete:",
    ]
    private static let identifiers: Set<String> = [
        "__NSTextViewContextSubmenuIdentifierWritingTools",
        "_NSMenuItemAutoFillIdentifier",
    ]
    private static var observers: [NSObjectProtocol] = []
    private static var cleanupScheduled = false

    static func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        for name in [NSApplication.didFinishLaunchingNotification, NSMenu.didBeginTrackingNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { clean() }
            })
        }
        observers.append(center.addObserver(forName: NSMenu.didAddItemNotification, object: nil, queue: .main) { note in
            let menu = note.object as? NSMenu
            MainActor.assumeIsolated {
                // Only menus of the menu bar, not context menus.
                guard let menu, menu.supermenu != nil, menu.supermenu === NSApp.mainMenu else { return }
                scheduleCleanup()
            }
        })
    }

    /// SwiftUI adds items one by one; clean up once it is done.
    private static func scheduleCleanup() {
        guard !cleanupScheduled else { return }
        cleanupScheduled = true
        DispatchQueue.main.async {
            cleanupScheduled = false
            clean()
        }
    }

    static func clean() {
        for top in NSApp.mainMenu?.items ?? [] {
            guard let menu = top.submenu else { continue }
            var removeNext = false
            for item in menu.items {
                let action = item.action.map(NSStringFromSelector) ?? ""
                if removeNext && item.submenu != nil {
                    // "Revert To…", which follows the hidden "Revert To Saved".
                    menu.removeItem(item)
                } else if actions.contains(action) || identifiers.contains(item.identifier?.rawValue ?? "") {
                    menu.removeItem(item)
                } else if hiddenActions.contains(action), !item.isHidden {
                    item.isHidden = true
                    item.allowsKeyEquivalentWhenHidden = true
                }
                removeNext = action == "revertDocumentToSaved:"
            }
            removeDoubleSeparators(in: menu)
        }
    }

    /// Removing and hiding items can leave separators next to each other or at the ends.
    private static func removeDoubleSeparators(in menu: NSMenu) {
        var previousWasSeparator = true
        for item in menu.items {
            if item.isSeparatorItem {
                if previousWasSeparator { menu.removeItem(item) } else { previousWasSeparator = true }
            } else if !item.isHidden {
                previousWasSeparator = false
            }
        }
        if let last = menu.items.last(where: { !$0.isHidden }), last.isSeparatorItem { menu.removeItem(last) }
    }
}
