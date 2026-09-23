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

enum SidebarMode: String, CaseIterable, Identifiable {
    case outline, thumbnails

    var id: Self { self }

    var title: String {
        switch self {
        case .outline: String(localized: "Gliederung")
        case .thumbnails: String(localized: "Miniaturen")
        }
    }

    var systemImage: String {
        switch self {
        case .outline: "list.bullet.indent"
        case .thumbnails: "square.grid.2x2"
        }
    }
}

struct SidebarView: View {
    let model: ViewerModel
    let state: ReaderState

    var body: some View {
        Group {
            switch state.sidebarMode {
            case .outline: OutlineListView(model: model, state: state)
            case .thumbnails: ThumbnailSidebar(pdfView: model.pdfView)
            }
        }
        // Fill the sidebar so the switcher stays at the top, whatever the content.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Seitenleiste", selection: Binding(
                get: { state.sidebarMode },
                set: { state.sidebarMode = $0 }
            )) {
                ForEach(SidebarMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .labelStyle(.iconOnly)
                        .help(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Thumbnails

/// PDFKit's thumbnail list, linked to the PDF view: it marks the current page
/// and a click shows that page.
struct ThumbnailSidebar: NSViewRepresentable {
    let pdfView: PDFView

    func makeNSView(context: Context) -> SidebarThumbnailView {
        let view = SidebarThumbnailView()
        view.pdfView = pdfView
        return view
    }

    func updateNSView(_ nsView: SidebarThumbnailView, context: Context) {
        // In a split window the sidebar follows the active view.
        if nsView.pdfView !== pdfView {
            nsView.pdfView = pdfView
            nsView.revealCurrentPageSoon()
        }
    }
}

final class SidebarThumbnailView: PDFThumbnailView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        maximumNumberOfColumns = 1
        allowsDragging = false
        allowsMultipleSelection = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { revealCurrentPageSoon() }
    }

    /// The list follows page changes by itself, but starts at the top when it appears.
    func revealCurrentPageSoon() {
        DispatchQueue.main.async { [weak self] in self?.revealCurrentPage() }
    }

    private func revealCurrentPage() {
        guard let pdfView, let document = pdfView.document, document.pageCount > 0,
              let page = pdfView.currentPage,
              let scrollView = firstScrollView(in: self),
              let content = scrollView.documentView
        else { return }
        let index = document.index(for: page)
        guard index != NSNotFound else { return }

        // Let the list mark the current page, as it does on every page change.
        NotificationCenter.default.post(name: .PDFViewPageChanged, object: pdfView)

        // One column of equally tall rows: center the row of the current page.
        let rowHeight = content.frame.height / CGFloat(document.pageCount)
        let visibleHeight = scrollView.contentView.bounds.height
        var y = rowHeight * CGFloat(index) - (visibleHeight - rowHeight) / 2
        if !content.isFlipped { y = content.frame.height - y - visibleHeight }
        y = min(max(0, y), max(0, content.frame.height - visibleHeight))
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        for subview in view.subviews {
            if let scrollView = subview as? NSScrollView { return scrollView }
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    /// Thumbnails fill the width of the sidebar.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let width = max(60, newSize.width - 48)
        let size = NSSize(width: width, height: (width * 1.45).rounded())
        if thumbnailSize != size { thumbnailSize = size }
    }
}

// MARK: - Outline

struct OutlineListView: View {
    let model: ViewerModel
    let state: ReaderState

    var body: some View {
        if model.outline.isEmpty {
            ContentUnavailableView {
                Label("Keine Gliederung", systemImage: "list.bullet.indent")
            } description: {
                Text("Dieses Dokument enthält kein Inhaltsverzeichnis.")
            } actions: {
                Button("Miniaturen anzeigen") { state.sidebarMode = .thumbnails }
            }
            .padding(.top, 16)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            List(selection: Binding(
                get: { model.selectedOutlineID },
                set: { if let id = $0 { model.selectOutline(id) } }
            )) {
                ForEach(model.outline) { node in
                    OutlineRow(node: node, model: model)
                }
            }
        }
    }
}

struct OutlineRow: View {
    let node: OutlineNode
    let model: ViewerModel

    var body: some View {
        if node.children.isEmpty {
            label
        } else {
            DisclosureGroup(isExpanded: Binding(
                get: { model.expandedOutlineIDs.contains(node.id) },
                set: { expanded in
                    if expanded {
                        model.expandedOutlineIDs.insert(node.id)
                    } else {
                        model.expandedOutlineIDs.remove(node.id)
                    }
                }
            )) {
                ForEach(node.children) { child in
                    OutlineRow(node: child, model: model)
                }
            } label: {
                label
            }
        }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(node.title)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let pageLabel = node.pageLabel {
                Text(pageLabel)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .help(node.title)
        .tag(node.id)
    }
}

// MARK: - Search results

struct SearchResultsView: View {
    let model: ViewerModel

    var body: some View {
        if model.matches.isEmpty {
            if model.isFinding {
                ProgressView("Suche …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView.search(text: model.activeQuery)
            }
        } else {
            List(selection: Binding(
                get: { model.currentMatchIndex },
                set: { if let index = $0 { model.goToMatch(index) } }
            )) {
                Section {
                    ForEach(model.matches) { match in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.context)
                                .lineLimit(2)
                            Text("Seite \(match.pageLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .tag(match.id)
                    }
                } header: {
                    Text(model.matches.count == 1
                         ? String(localized: "1 Treffer")
                         : String(localized: "\(model.matches.count) Treffer"))
                }
            }
        }
    }
}
