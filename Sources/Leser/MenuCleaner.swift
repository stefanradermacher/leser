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
    /// Writing Tools and AutoFill. AppKit puts both into the Edit menu of any app that can
    /// show text, and there is no public way to keep them out: `writingToolsBehavior` sits on
    /// NSTextView, while Leser shows its text in a PDFView. Left alone, a viewer that never
    /// changes a document would offer to rephrase and summarise text, and to fill in a credit
    /// card.
    ///
    /// They are recognised by a fragment of their menu item identifier. Reading `identifier`
    /// is public API; its value is an AppKit implementation detail and not documented. If
    /// Apple renames it, the two submenus simply reappear — nothing else depends on the match,
    /// and matching a fragment rather than the whole name survives small renamings.
    private static let identifierFragments = ["writingtools", "autofill"]
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
                    // "Revert To ▸", which follows the hidden "Revert To Saved". Its position is
                    // the only public thing that sets it apart from "Share ▸": both have the
                    // action submenuAction:, tag 0 and no identifier, and both submenus are still
                    // empty here — AppKit fills them only when they open, and calling their
                    // delegate's menuNeedsUpdate(_:) does not fill them either. Replacing SwiftUI's
                    // .saveItem group would drop them, but also Close (⌘W), Close All, Open Recent
                    // and Share. So the anchor is the public action revertDocumentToSaved:. Should
                    // AppKit ever reorder this menu, the rule may miss "Revert To ▸" or hit another
                    // submenu — worth a look at the File menu after a major macOS update.
                    menu.removeItem(item)
                } else if actions.contains(action) || hasUnwantedIdentifier(item) {
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

    private static func hasUnwantedIdentifier(_ item: NSMenuItem) -> Bool {
        guard let identifier = item.identifier?.rawValue.lowercased() else { return false }
        return identifierFragments.contains { identifier.contains($0) }
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
