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

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct LeserApp: App {
    init() {
        Preferences.register()
        TipJar.shared.startListening()
        MenuCleaner.install()
    }

    var body: some Scene {
        DocumentGroup(viewing: PDFFile.self) { file in
            ContentView(document: file.document.pdf, fileURL: file.fileURL)
        }
        .defaultSize(width: 1120, height: 860)
        .commands {
            SidebarCommands()
            ViewerCommands()
        }

        Settings {
            SettingsView()
        }

        Window("Über Leser", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        Window("Leser unterstützen", id: "support") {
            SupportView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }
}

/// Read-only PDF document. Writing is intentionally unsupported.
struct PDFFile: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [] }

    let pdf: PDFDocument

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let pdf = PDFDocument(data: data)
        else { throw CocoaError(.fileReadCorruptFile) }
        self.pdf = pdf
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}

extension FocusedValues {
    @Entry var viewer: ViewerModel?
    @Entry var reader: ReaderState?
}
