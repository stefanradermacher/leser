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

struct ViewerCommands: Commands {
    @FocusedValue(\.viewer) private var viewer
    @FocusedValue(\.reader) private var reader
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("Über Leser") { openWindow(id: "about") }
        }

        CommandGroup(replacing: .help) {
            Button("Hilfe zu Leser …") { NSWorkspace.shared.open(AppLinks.help) }
                .keyboardShortcut("?")
            Button("Leser im Web") { NSWorkspace.shared.open(AppLinks.productPage) }
            Divider()
            Button("Leser auf GitHub") { NSWorkspace.shared.open(AppLinks.sourceCode) }
            Button("Fehler melden oder Idee vorschlagen …") { NSWorkspace.shared.open(AppLinks.reportIssue) }
            Divider()
            Button("Leser unterstützen …") { openWindow(id: "support") }
        }

        CommandGroup(replacing: .printItem) {
            Button("Dokumentinformationen") { reader?.showDocumentInfo() }
                .keyboardShortcut("i")
                .disabled(reader == nil)
            Divider()
            Button("Papierformat …") { NSApp.runPageLayout(nil) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Drucken …") { viewer?.print() }
                .keyboardShortcut("p")
                .disabled(!(viewer?.canPrint ?? false))
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Suchen …") { reader?.requestSearchFocus() }
                .keyboardShortcut("f")
                .disabled(viewer == nil)
            Button("Weitersuchen") { viewer?.nextMatch() }
                .keyboardShortcut("g")
                .disabled(viewer?.matches.isEmpty ?? true)
            Button("Rückwärts suchen") { viewer?.previousMatch() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(viewer?.matches.isEmpty ?? true)
            Button(reader?.showsSearchResults == true ? "Suchergebnisse ausblenden" : "Suchergebnisse einblenden") {
                reader?.showsSearchResults.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(viewer?.activeQuery.isEmpty ?? true)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            ForEach(Array(SidebarMode.allCases.enumerated()), id: \.element) { index, mode in
                Toggle(mode.title, isOn: Binding(
                    get: { reader?.sidebarMode == mode },
                    set: { _ in reader?.showSidebar(mode) }
                ))
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .control])
                .disabled(reader == nil)
            }
            Divider()
            Button("Originalgröße") { viewer?.setZoom(1) }
                .keyboardShortcut("0")
            Button("Vergrößern") { viewer?.zoomIn() }
                .keyboardShortcut("+")
            Button("Verkleinern") { viewer?.zoomOut() }
                .keyboardShortcut("-")
            Divider()
            fitToggle("Seitenbreite", .width, key: "1")
            fitToggle("Seitenhöhe", .height, key: "2")
            fitToggle("Ganze Seite", .page, key: "3")
            Divider()
            Divider()
            Button(reader?.isSplit == true ? "Geteilte Ansicht schließen" : "Ansicht teilen") {
                reader?.toggleSplit()
            }
            .keyboardShortcut("t", modifiers: [.command, .control])
            .disabled(reader == nil)
            Button("Anderes Dokument in zweiter Ansicht öffnen …") { reader?.chooseOtherDocument() }
                .disabled(reader == nil)
            Toggle("Nebeneinander", isOn: Binding(
                get: { reader?.axis == .sideBySide },
                set: { _ in reader?.setAxis(.sideBySide) }
            ))
            .disabled(reader == nil)
            Toggle("Untereinander", isOn: Binding(
                get: { reader?.axis == .stacked },
                set: { _ in reader?.setAxis(.stacked) }
            ))
            .disabled(reader == nil)
            Divider()
            ForEach(Array(PageLayout.allCases.enumerated()), id: \.element) { index, layout in
                Toggle(layout.title, isOn: Binding(
                    get: { viewer?.pageLayout == layout },
                    set: { _ in viewer?.setPageLayout(layout) }
                ))
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
                .disabled(viewer == nil)
            }
        }

        CommandMenu("Gehe zu") {
            Button("Vorherige Seite") { viewer?.previousPage() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled((viewer?.pageIndex ?? 0) == 0)
            Button("Nächste Seite") { viewer?.nextPage() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(viewer.map { $0.pageIndex >= $0.pageCount - 1 } ?? true)
            Divider()
            Button("Erste Seite") { viewer?.firstPage() }
                .keyboardShortcut(.home, modifiers: [.command, .option])
                .disabled(viewer == nil)
            Button("Letzte Seite") { viewer?.lastPage() }
                .keyboardShortcut(.end, modifiers: [.command, .option])
                .disabled(viewer == nil)
            Divider()
            Button("Zurück") { viewer?.goBack() }
                .keyboardShortcut("[")
                .disabled(!(viewer?.canGoBack ?? false))
            Button("Vorwärts") { viewer?.goForward() }
                .keyboardShortcut("]")
                .disabled(!(viewer?.canGoForward ?? false))
            Divider()
            Button("Gehe zu Seite …") { reader?.requestGoToPage() }
                .keyboardShortcut("g", modifiers: [.command, .option])
                .disabled(viewer == nil)
        }
    }

    private func fitToggle(_ title: LocalizedStringKey, _ mode: FitMode, key: KeyEquivalent) -> some View {
        Toggle(title, isOn: Binding(
            get: { viewer?.fitMode == mode },
            set: { _ in viewer?.setFitMode(mode) }
        ))
        .keyboardShortcut(key)
        .disabled(viewer == nil)
    }
}
