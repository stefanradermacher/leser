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
import Observation
import PDFKit
import SwiftUI

enum FitMode: Hashable {
    case none, width, height, page
}

enum PageLayout: String, CaseIterable, Identifiable {
    case continuous, single, twoUp, book

    var id: Self { self }

    var title: String {
        switch self {
        case .continuous: String(localized: "Fortlaufend")
        case .single: String(localized: "Einzelseite")
        case .twoUp: String(localized: "Doppelseite")
        case .book: String(localized: "Doppelseite (erste Seite einzeln)")
        }
    }

    var systemImage: String {
        switch self {
        case .continuous: "scroll"
        case .single: "rectangle.portrait"
        case .twoUp: "rectangle.split.2x1"
        case .book: "book"
        }
    }

    fileprivate var displayMode: PDFDisplayMode {
        self == .continuous ? .singlePageContinuous : self == .single ? .singlePage : .twoUp
    }

    fileprivate init(of view: PDFView) {
        switch view.displayMode {
        case .singlePageContinuous: self = .continuous
        case .singlePage: self = .single
        default: self = view.displaysAsBook ? .book : .twoUp
        }
    }

    /// Last chosen layout, used for newly opened documents.
    static var preferred: PageLayout {
        get { UserDefaults.standard.string(forKey: "pageLayout").flatMap(PageLayout.init) ?? .continuous }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "pageLayout") }
    }
}

struct OutlineNode: Identifiable {
    let id: Int
    let title: String
    let pageIndex: Int?
    let pageLabel: String?
    /// Where on the page the entry points, in PDF coordinates, if the PDF says so.
    let point: CGPoint?
    let children: [OutlineNode]
}

struct SearchMatch: Identifiable {
    let id: Int
    let selection: PDFSelection
    let pageLabel: String
    let context: AttributedString
}

/// How a view shows its document, carried over when the document is reloaded.
struct ViewSnapshot {
    var page: Int
    var point: CGPoint
    var scale: CGFloat
    var fitMode: FitMode
    var layout: PageLayout
    var searchText: String
}

/// State and actions for one document window.
@MainActor
@Observable
final class ViewerModel {
    static let zoomSteps: [CGFloat] = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5, 6, 8]
    static let menuZoomLevels: [CGFloat] = [0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]

    let document: PDFDocument
    let pageCount: Int
    @ObservationIgnored let pdfView = ReaderPDFView()

    // Navigation
    private(set) var pageIndex = 0
    private(set) var canGoBack = false
    private(set) var canGoForward = false

    // Zoom
    private(set) var scale: CGFloat = 1
    private(set) var fitMode = Preferences.openZoom.fitMode

    // Page layout
    private(set) var pageLayout = Preferences.openLayout

    // Outline
    private(set) var outline: [OutlineNode] = []
    private(set) var selectedOutlineID: Int?
    var expandedOutlineIDs: Set<Int> = []

    // Search
    var searchText = ""
    private(set) var activeQuery = ""
    private(set) var matches: [SearchMatch] = []
    private(set) var currentMatchIndex: Int?
    private(set) var isFinding = false
    /// Matches found but not yet shown. Every change to `matches` makes SwiftUI compare the whole
    /// results list again, so with tens of thousands of matches one change per match kept the
    /// interface busy for over a minute. They are handed over in batches instead.
    @ObservationIgnored private var pendingMatches: [SearchMatch] = []
    @ObservationIgnored private var flushScheduled = false
    /// The page the search started on. The view goes to the first match on it or after it;
    /// only if there is none, to the first match of the document.
    @ObservationIgnored private var searchStartPage = 0
    /// The view has not gone to a match of the current search yet.
    @ObservationIgnored private var awaitsFirstMatch = false


    @ObservationIgnored private var outlineItems: [Int: PDFOutline] = [:]
    @ObservationIgnored private var outlineNodes: [Int: OutlineNode] = [:]
    @ObservationIgnored private var requestedScale: CGFloat?
    @ObservationIgnored private var didInitialLayout = false
    /// Identifies the document for its bookmarks and reading position, see `DocumentKey`.
    let documentKey: String?
    /// Whether this view remembers the reading position: only the main view of a window does.
    @ObservationIgnored private let remembersPosition: Bool
    /// Path under which older versions stored the reading position, to take it over once.
    @ObservationIgnored private let legacyPath: String?
    /// The bookmarks of the document, shared with every other view of it.
    let bookmarks: BookmarkList?
    @ObservationIgnored nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    /// Page shown first when no reading position is remembered.
    @ObservationIgnored private let startPage: Int
    /// Page shown first instead of the remembered reading position, for a document opened
    /// from a reference into it.
    @ObservationIgnored private var openingPage: Int?
    /// State to restore after reloading the document.
    @ObservationIgnored private let restoring: ViewSnapshot?
    /// The second view of a split window, stored with the reading position of the main view.
    @ObservationIgnored var splitPosition: (() -> Preferences.SplitPosition?)?
    /// Called when the shown page changes, for a second view to have the position stored.
    @ObservationIgnored var onPageChange: (() -> Void)?
    let displayName: String
    /// File the document comes from, for the document information.
    let location: URL?

    /// `fileURL` is used to remember the reading position; pass nil for views that should not.
    init(
        document: PDFDocument,
        fileURL: URL?,
        displayName: String? = nil,
        location: URL? = nil,
        startPage: Int = 0,
        restoring: ViewSnapshot? = nil
    ) {
        self.document = document
        self.pageCount = document.pageCount
        documentKey = DocumentKey.key(for: document, fileURL: fileURL ?? location)
        remembersPosition = fileURL != nil
        legacyPath = fileURL?.standardizedFileURL.path
        bookmarks = documentKey.map(BookmarkList.list(for:))
        self.displayName = displayName ?? fileURL?.lastPathComponent ?? document.documentURL?.lastPathComponent ?? String(localized: "Dokument")
        self.location = location ?? fileURL ?? document.documentURL
        self.startPage = startPage
        self.restoring = restoring
        openingPage = DocumentTabs.takePendingPage(for: fileURL)
        if let restoring {
            pageLayout = restoring.layout
            fitMode = restoring.fitMode
            searchText = restoring.searchText
        }

        pdfView.document = document
        pdfView.documentName = self.displayName
        pdfView.displayMode = pageLayout.displayMode
        pdfView.displaysAsBook = pageLayout == .book
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = false
        pdfView.minScaleFactor = Self.zoomSteps.first!
        pdfView.maxScaleFactor = Self.zoomSteps.last!
        pdfView.backgroundColor = .underPageBackgroundColor
        pdfView.postsFrameChangedNotifications = true

        outline = buildOutline()
        syncOutlineSelection()
        observeView()
        pdfView.onAttach = { [weak self] in self?.performInitialLayoutIfReady() }
    }

    /// Ends this view's work when it is removed from a window.
    func stop() {
        DocumentSearch.stop(in: document, for: self)
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        pdfView.onFocus = nil
        pdfView.onAttach = nil
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Page navigation

    var pageLabel: String {
        document.page(at: pageIndex)?.label ?? "\(pageIndex + 1)"
    }

    /// The labels of all pages, as printed on them when the PDF says so ("xi", "12"), otherwise
    /// the page numbers. Read once, when first needed.
    @ObservationIgnored private lazy var pageLabels: [String] = (0..<pageCount).map { index in
        document.page(at: index)?.label ?? "\(index + 1)"
    }

    /// Room for the longest page label in the toolbar, so the page buttons keep their size.
    @ObservationIgnored lazy var pageLabelWidth: CGFloat = {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let widest = pageLabels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return ceil(max(widest, 16)) + 16
    }()

    /// Whether the document numbers its pages differently from their position, for instance
    /// with roman numerals for the front matter.
    var hasPageLabels: Bool {
        pageLabels.enumerated().contains { $0.element != "\($0.offset + 1)" }
    }

    /// The page for what was typed into "Go to page": a page label first, as printed on the
    /// page, otherwise the position in the document.
    func pageIndex(for input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if let index = pageLabels.firstIndex(where: { $0.compare(text, options: [.caseInsensitive]) == .orderedSame }) {
            return index
        }
        if let number = Int(text), (1...pageCount).contains(number) { return number - 1 }
        return nil
    }

    func goToPage(_ index: Int) {
        guard let page = document.page(at: min(max(index, 0), pageCount - 1)) else { return }
        pdfView.go(to: page)
    }

    func nextPage() { pdfView.goToNextPage(nil) }
    func previousPage() { pdfView.goToPreviousPage(nil) }
    func firstPage() { pdfView.goToFirstPage(nil) }
    func lastPage() { pdfView.goToLastPage(nil) }
    func goBack() { pdfView.goBack(nil) }
    func goForward() { pdfView.goForward(nil) }

    func focusDocument() {
        pdfView.window?.makeFirstResponder(pdfView)
    }


    // MARK: - Page tone

    func applyPageTone() {
        PageTone.apply(to: pdfView.documentView)
    }

    // MARK: - Page layout

    func setPageLayout(_ layout: PageLayout) {
        guard layout != PageLayout(of: pdfView) else { return }
        let page = pdfView.currentPage
        pageLayout = layout
        PageLayout.preferred = layout
        pdfView.displaysAsBook = layout == .book
        pdfView.displayMode = layout.displayMode
        pdfView.layoutDocumentView()
        if let page { pdfView.go(to: page) }
        applyFit(scrollToPage: true)
    }

    // MARK: - Zoom

    func zoomIn() {
        let current = pdfView.scaleFactor
        setZoom(Self.zoomSteps.first { $0 > current * 1.01 } ?? Self.zoomSteps.last!)
    }

    func zoomOut() {
        let current = pdfView.scaleFactor
        setZoom(Self.zoomSteps.last { $0 < current * 0.99 } ?? Self.zoomSteps.first!)
    }

    func setZoom(_ newScale: CGFloat) {
        fitMode = .none
        applyScale(newScale)
    }

    func setFitMode(_ mode: FitMode) {
        fitMode = mode
        applyFit(scrollToPage: mode != .width)
    }

    private func applyScale(_ newScale: CGFloat) {
        let clamped = min(max(newScale, pdfView.minScaleFactor), pdfView.maxScaleFactor)
        requestedScale = clamped
        pdfView.autoScales = false
        pdfView.scaleFactor = clamped
        scale = pdfView.scaleFactor
    }

    private func applyFit(scrollToPage: Bool) {
        guard fitMode != .none,
              let page = pdfView.currentPage ?? document.page(at: 0)
        else { return }

        // Size of the page row (one page or a spread, including margins) at scale 1.
        // In book mode the first row holds one page, so also measure the following row.
        let index = document.index(for: page)
        let rows = [page, document.page(at: index + 1)].compactMap { $0 }
        let currentScale = pdfView.scaleFactor
        let rowSize = rows.reduce(CGSize.zero) { size, page in
            let row = pdfView.rowSize(for: page)
            return CGSize(width: max(size.width, row.width / currentScale),
                          height: max(size.height, row.height / currentScale))
        }
        guard rowSize.width > 0, rowSize.height > 0 else { return }

        // Available area without scrollers. With a mouse attached macOS shows permanent (legacy)
        // scrollers; the vertical one takes width as soon as the content is taller than the view.
        let scrollView = pdfView.documentView?.enclosingScrollView
        let viewport = scrollView?.frame.size ?? pdfView.bounds.size
        guard viewport.width > 1, viewport.height > 1 else { return }
        let scrollerWidth = NSScroller.preferredScrollerStyle == .legacy
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
        let contentHeight = pdfView.documentView?.bounds.height ?? rowSize.height

        func fit(_ available: CGFloat) -> CGFloat {
            let widthScale = available / rowSize.width
            let heightScale = viewport.height / rowSize.height
            switch fitMode {
            case .width: return widthScale
            case .height: return heightScale
            case .page, .none: return min(widthScale, heightScale)
            }
        }
        var target = fit(viewport.width)
        if contentHeight * target > viewport.height + 0.5 {
            target = fit(viewport.width - scrollerWidth)
        }
        // Keep the reading position.
        let anchor = pdfView.currentDestination
        // Stay a hair below the exact fit so no scroller appears from rounding.
        applyScale(target * 0.998)
        if scrollToPage {
            pdfView.go(to: page)
        } else if let anchor {
            pdfView.go(to: anchor)
        }
    }

    // MARK: - Initial layout and reading position

    /// Applies the opening zoom and position once the window is on screen with its final size.
    func performInitialLayoutIfReady() {
        guard !didInitialLayout,
              let window = pdfView.window, window.isVisible,
              pdfView.bounds.width > 1, pdfView.bounds.height > 1
        else { return }
        didInitialLayout = true

        pdfView.displaysAsBook = pageLayout == .book
        pdfView.displayMode = pageLayout.displayMode
        pdfView.layoutDocumentView()
        applyPageTone()

        if fitMode == .none {
            applyScale(restoring?.scale ?? 1)
        } else {
            applyFit(scrollToPage: false)
        }

        if let restoring {
            // After a reload: same place, even if the document got shorter.
            let index = min(max(restoring.page, 0), pageCount - 1)
            if let page = document.page(at: index) {
                pdfView.go(to: PDFDestination(page: page, at: restoring.point))
            }
        } else if let openingPage, let page = document.page(at: openingPage) {
            pdfView.go(to: page)
        } else if let saved = savedReadingPosition(),
           let page = document.page(at: saved.page) {
            pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: saved.x, y: saved.y)))
        } else if let first = document.page(at: startPage) ?? document.page(at: 0) {
            pdfView.go(to: first)
        }
    }

    func snapshot() -> ViewSnapshot {
        let destination = pdfView.currentDestination
        let page = destination?.page.map { document.index(for: $0) } ?? pageIndex
        return ViewSnapshot(
            page: page == NSNotFound ? pageIndex : page,
            point: destination?.point ?? .zero,
            scale: pdfView.scaleFactor,
            fitMode: fitMode,
            layout: pageLayout,
            searchText: searchText
        )
    }

    // MARK: - Printing

    var canPrint: Bool { document.allowsPrinting }

    func print() {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        guard canPrint,
              let operation = document.printOperation(for: info, scalingMode: PrintOptions.scaling,
                                                       autoRotate: PrintOptions.autoRotate)
        else { return }
        operation.jobTitle = displayName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.printPanel.options.formUnion([.showsPageRange, .showsCopies, .showsPaperSize, .showsOrientation, .showsScaling, .showsPreview])
        operation.printPanel.addAccessoryController(PrintOptions(printInfo: operation.printInfo))
        if let window = pdfView.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    /// The stored reading position, if this view remembers one.
    func savedReadingPosition() -> Preferences.ReadingPosition? {
        guard Preferences.rememberPosition, remembersPosition, let documentKey else { return nil }
        return Preferences.readingPosition(for: documentKey, legacyPath: legacyPath)
    }

    func saveReadingPosition() {
        guard didInitialLayout, Preferences.rememberPosition, remembersPosition, let documentKey,
              let destination = pdfView.currentDestination,
              let page = destination.page
        else { return }
        let index = document.index(for: page)
        guard index != NSNotFound else { return }
        Preferences.setReadingPosition(
            .init(page: index, x: destination.point.x, y: destination.point.y, date: .now, split: splitPosition?()),
            for: documentKey
        )
    }

    private func scaleDidChange() {
        scale = pdfView.scaleFactor
        if let requestedScale, abs(requestedScale - scale) < 0.0005 { return }
        // User zoomed by pinch or context menu – leave fit mode.
        fitMode = .none
    }

    // MARK: - Outline

    /// The last jump from the outline, so a click that both selects a row and is seen as a tap
    /// on it goes there only once.
    @ObservationIgnored private var lastOutlineJump: (id: Int, date: Date)?

    func selectOutline(_ id: Int) {
        selectedOutlineID = id
        if let last = lastOutlineJump, last.id == id, Date.now.timeIntervalSince(last.date) < 0.5 { return }
        lastOutlineJump = (id, .now)
        guard let item = outlineItems[id] else { return }
        if let destination = item.destination {
            pdfView.go(to: destination)
        } else if let action = item.action {
            pdfView.perform(action)
        }
    }

    private func buildOutline() -> [OutlineNode] {
        guard let root = document.outlineRoot else { return [] }
        var nextID = 0

        func children(of item: PDFOutline) -> [OutlineNode] {
            (0..<item.numberOfChildren).compactMap { i in
                guard let child = item.child(at: i) else { return nil }
                let id = nextID
                nextID += 1

                let destination = child.destination ?? (child.action as? PDFActionGoTo)?.destination
                let page = destination?.page
                let index = page.map { document.index(for: $0) }.flatMap { $0 == NSNotFound ? nil : $0 }
                let title = (child.label ?? "")
                    .components(separatedBy: .newlines)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)

                if child.isOpen { expandedOutlineIDs.insert(id) }
                outlineItems[id] = child

                let node = OutlineNode(
                    id: id,
                    title: title.isEmpty ? String(localized: "Ohne Titel") : title,
                    pageIndex: index,
                    pageLabel: page?.label ?? index.map { "\($0 + 1)" },
                    point: destination.flatMap { Self.specifiedPoint(of: $0) },
                    children: children(of: child)
                )
                outlineNodes[id] = node
                return node
            }
        }
        return children(of: root)
    }

    /// The point of a destination, unless the PDF left it open ("anywhere on the page").
    private static func specifiedPoint(of destination: PDFDestination) -> CGPoint? {
        let point = destination.point
        let unspecified = CGFloat(kPDFDestinationUnspecifiedValue)
        guard point.y != unspecified, point.y.isFinite else { return nil }
        return CGPoint(x: point.x == unspecified || !point.x.isFinite ? 0 : point.x, y: point.y)
    }

    // MARK: - Bookmarks

    /// The label of a page as printed on it, otherwise its number.
    func label(ofPage index: Int) -> String {
        index < pageCount ? pageLabels[index] : "\(index + 1)"
    }

    func goTo(_ bookmark: Bookmark) {
        guard let page = document.page(at: min(max(bookmark.page, 0), pageCount - 1)) else { return }
        pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: bookmark.x, y: bookmark.y)))
    }

    /// Adds the place an outline entry points to, under the entry's name.
    func addBookmark(for node: OutlineNode) {
        guard let page = node.pageIndex, let bookmarks else { return }
        bookmarks.add(name: node.title, page: page, point: node.point ?? topOfPage(page))
        BookmarkPreferences.reveal()
    }

    /// A new bookmark for the place shown at the top of the view.
    func bookmarkDraftForCurrentPlace() -> BookmarkDraft? {
        guard let destination = pdfView.currentDestination, let page = destination.page else { return nil }
        let index = document.index(for: page)
        guard index != NSNotFound else { return nil }
        return bookmarkDraft(page: index, point: destination.point)
    }

    /// A new bookmark for a place on a page. Suggested is the outline entry the place belongs
    /// to; the menu also offers the other entries on the page and the page itself.
    func bookmarkDraft(page: Int, point: CGPoint) -> BookmarkDraft? {
        guard bookmarks != nil else { return nil }
        var entries: [OutlineNode] = []
        func flatten(_ nodes: [OutlineNode]) {
            for node in nodes {
                if node.pageIndex != nil { entries.append(node) }
                flatten(node.children)
            }
        }
        flatten(outline)

        // An entry is at or before the place if it is on an earlier page, or above it.
        func isBefore(_ node: OutlineNode) -> Bool {
            guard let index = node.pageIndex else { return false }
            if index != page { return index < page }
            return (node.point?.y ?? .greatestFiniteMagnitude) >= point.y - 2
        }
        let current = entries.last(where: isBefore)
        let onPage = entries.filter { $0.pageIndex == page }

        let pageName = pageLabels[page].allSatisfy(\.isNumber)
            ? String(localized: "Seite \(pageLabels[page])")
            : pageLabels[page]
        var names: [String] = []
        for name in [current?.title] + onPage.map(\.title) + [pageName] {
            if let name, !names.contains(name) { names.append(name) }
        }
        return BookmarkDraft(model: self, page: page, point: point, names: names)
    }

    private func topOfPage(_ index: Int) -> CGPoint {
        CGPoint(x: 0, y: document.page(at: index)?.bounds(for: .cropBox).maxY ?? 0)
    }

    /// Highlights the outline entry for the current page among the visible (expanded) entries.
    private func syncOutlineSelection() {
        if let id = selectedOutlineID, outlineNodes[id]?.pageIndex == pageIndex { return }

        var best: Int?
        func visit(_ nodes: [OutlineNode]) {
            for node in nodes {
                if let index = node.pageIndex, index <= pageIndex { best = node.id }
                if expandedOutlineIDs.contains(node.id) { visit(node.children) }
            }
        }
        visit(outline)
        if best != selectedOutlineID { selectedOutlineID = best }
    }

    // MARK: - Search

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != activeQuery else { return }

        activeQuery = query
        matches = []
        pendingMatches = []
        currentMatchIndex = nil
        pdfView.highlightedSelections = nil
        pdfView.setCurrentSelection(nil, animate: false)

        guard !query.isEmpty else {
            isFinding = false
            DocumentSearch.stop(in: document, for: self)
            return
        }
        isFinding = true
        searchStartPage = Preferences.searchFromCurrentPage ? pageIndex : 0
        awaitsFirstMatch = true
        // The document is shared with the other half of a split window; DocumentSearch keeps
        // the two searches apart.
        DocumentSearch.start(query, options: [.caseInsensitive, .diacriticInsensitive], in: document, for: self)
    }

    func goToMatch(_ index: Int) {
        guard matches.indices.contains(index) else { return }
        currentMatchIndex = index
        let selection = matches[index].selection
        pdfView.go(to: selection)
        pdfView.setCurrentSelection(selection, animate: true)
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        goToMatch(currentMatchIndex.map { ($0 + 1) % matches.count } ?? 0)
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        goToMatch(currentMatchIndex.map { ($0 - 1 + matches.count) % matches.count } ?? matches.count - 1)
    }

    private func addMatch(_ selection: PDFSelection) {
        // Ignore late results from a search that has been replaced.
        guard !activeQuery.isEmpty,
              Self.normalized(selection.string ?? "").compare(
                  Self.normalized(activeQuery), options: [.caseInsensitive, .diacriticInsensitive]
              ) == .orderedSame,
              let page = selection.pages.first
        else { return }

        selection.color = .findHighlightColor
        let index = document.index(for: page)
        let match = SearchMatch(
            id: matches.count + pendingMatches.count,
            selection: selection,
            pageLabel: page.label ?? "\(index + 1)",
            context: Self.context(for: selection)
        )
        // PDFKit finds the matches in page order. The first one on the start page or after it
        // is shown right away, so the view goes there without delay.
        if awaitsFirstMatch, index >= searchStartPage {
            awaitsFirstMatch = false
            flushMatches()
            matches.append(match)
            goToMatch(matches.count - 1)
            return
        }
        pendingMatches.append(match)
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            MainActor.assumeIsolated { self?.flushMatches() }
        }
    }

    private func flushMatches() {
        flushScheduled = false
        guard !pendingMatches.isEmpty else { return }
        matches.append(contentsOf: pendingMatches)
        pendingMatches = []
    }

    private func finishSearch() {
        flushMatches()
        isFinding = false
        // All matches lie before the start page: back to the first one, as searching wraps around.
        if awaitsFirstMatch, !matches.isEmpty {
            awaitsFirstMatch = false
            goToMatch(0)
        }
        pdfView.highlightedSelections = matches.isEmpty ? nil : matches.map(\.selection)
    }

    private static func normalized(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The line around a match, with the match in bold.
    private static func context(for selection: PDFSelection) -> AttributedString {
        let match = normalized(selection.string ?? "")
        guard let line = selection.copy() as? PDFSelection else { return AttributedString(match) }
        line.extendForLineBoundaries()
        var text = normalized(line.string ?? "")

        if let range = text.range(of: match, options: [.caseInsensitive, .diacriticInsensitive]) {
            let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
            if start > text.startIndex { text = "…" + text[start...] }
        }
        var result = AttributedString(text)
        if let range = result.range(of: match, options: [.caseInsensitive, .diacriticInsensitive]) {
            result[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }

    // MARK: - Observation of the PDF view

    private func observeView() {
        let center = NotificationCenter.default
        func observe(_ name: Notification.Name, of object: AnyObject? = nil, _ handler: @escaping (ViewerModel, Notification) -> Void) {
            observers.append(center.addObserver(forName: name, object: object ?? pdfView, queue: .main) { [weak self] note in
                nonisolated(unsafe) let note = note
                MainActor.assumeIsolated {
                    if let self { handler(self, note) }
                }
            })
        }

        observe(.PDFViewPageChanged) { model, _ in
            guard let page = model.pdfView.currentPage else { return }
            let index = model.document.index(for: page)
            if index != NSNotFound, index != model.pageIndex { model.pageIndex = index }
            model.syncOutlineSelection()
            model.saveReadingPosition()
            model.onPageChange?()
        }
        observe(.PDFViewScaleChanged) { model, _ in model.scaleDidChange() }
        observe(UserDefaults.didChangeNotification, of: UserDefaults.standard) { model, _ in
            model.applyPageTone()
        }
        observe(.PDFViewDisplayModeChanged) { model, _ in
            // Also changeable from the PDF view's context menu. Changes before the window is
            // shown are ignored; the chosen layout is applied again in the initial layout.
            guard model.didInitialLayout else { return }
            let layout = PageLayout(of: model.pdfView)
            guard layout != model.pageLayout else { return }
            model.pageLayout = layout
            model.applyFit(scrollToPage: true)
        }
        observe(.PDFViewChangedHistory) { model, _ in
            model.canGoBack = model.pdfView.canGoBack
            model.canGoForward = model.pdfView.canGoForward
        }
        observe(NSView.frameDidChangeNotification) { model, _ in
            model.applyFit(scrollToPage: false)
            model.performInitialLayoutIfReady()
        }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let self, window === self.pdfView.window else { return }
                    self.performInitialLayoutIfReady()
                }
            })
        }
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveReadingPosition() }
        })
        // Posted without an object when a mouse is attached or removed.
        observers.append(center.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyFit(scrollToPage: false) }
        })
    }
}

extension ViewerModel: DocumentSearchClient {
    func searchDidFind(_ selection: PDFSelection) { addMatch(selection) }

    func searchDidFinish() { finishSearch() }

    func searchWasInterrupted() {
        // The search runs again once the other view's search has finished; until then the
        // results pane shows that it is still searching.
        matches = []
        pendingMatches = []
        currentMatchIndex = nil
        pdfView.highlightedSelections = nil
        awaitsFirstMatch = true
    }
}

/// PDFView that takes keyboard focus when it appears, so arrow keys and space scroll right away,
/// and turns pages with the left and right arrow keys.
final class ReaderPDFView: PDFView {
    /// Called when the view gets keyboard focus, used to track the active view of a split window.
    var onFocus: (() -> Void)?
    /// Called once the view is in a window.
    var onAttach: (() -> Void)?
    /// Called to add a bookmark at a point on a page (page index, point in page coordinates).
    var onAddBookmark: ((Int, CGPoint) -> Void)?
    /// Called to follow a reference into another book (its title, the page number given).
    var onOpenBook: ((String, Int) -> Void)?
    /// The name of the document, taken as its title when telling its own page references
    /// from those into other books.
    var documentName: String?

    /// Shows where a link in the document leads while the pointer rests on it.
    private lazy var linkPreview = LinkPreview(view: self)

    /// Page references in the text, like "(page 359)", found while the pointer passes them.
    private var pageReferences: PageReferences?
    /// The page reference a click started on, followed if the click ends on it too.
    private var clickedReference: (page: PDFPage, reference: PageReferences.Reference)?

    /// The page reference in the text at a point of the view.
    func pageReference(at location: NSPoint) -> (page: PDFPage, reference: PageReferences.Reference)? {
        guard let document, let page = page(for: location, nearest: false) else { return nil }
        if pageReferences?.document !== document || pageReferences?.booksRevision != OtherBooks.revision {
            pageReferences = PageReferences(document: document, name: documentName)
        }
        guard let reference = pageReferences?.reference(at: convert(location, to: page), on: page)
        else { return nil }
        return (page, reference)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = convert(event.locationInWindow, from: nil)
        linkPreview.pointerMoved(to: location)
        if pageReference(at: location) != nil { NSCursor.pointingHand.set() }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        linkPreview.close()
    }

    override func mouseDown(with event: NSEvent) {
        linkPreview.close()
        let location = convert(event.locationInWindow, from: nil)
        let plainClick = event.clickCount == 1
            && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        clickedReference = plainClick ? pageReference(at: location) : nil
        super.mouseDown(with: event)
        // PDFKit may follow the mouse until it is released before returning.
        if clickedReference != nil, NSEvent.pressedMouseButtons & 1 == 0, let window {
            followClickedReference(endingAt: convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        followClickedReference(endingAt: convert(event.locationInWindow, from: nil))
    }

    /// Goes to the page a reference names if a click on it ends there without selecting text.
    private func followClickedReference(endingAt location: NSPoint) {
        guard let clicked = clickedReference else { return }
        clickedReference = nil
        guard let (page, reference) = pageReference(at: location), page === clicked.page,
              reference.location == clicked.reference.location,
              currentSelection?.string?.isEmpty ?? true
        else { return }
        switch reference.target {
        case .page(let index):
            if let target = document?.page(at: index) { go(to: target) }
        case .book(let title, let number):
            onOpenBook?(title, number)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        linkPreview.close()
        super.scrollWheel(with: event)
    }

    /// The side buttons of a mouse go back and forward, as in a browser, for instance after
    /// following a link. Mouse drivers send them in different forms: as buttons 4 and 5, or –
    /// like SteerMouse's "Back" and "Forward" – as the swipe of a trackpad or Magic Mouse.
    override func otherMouseDown(with event: NSEvent) {
        switch event.buttonNumber {
        case 3: goBackOrForward(-1)
        case 4: goBackOrForward(1)
        default: super.otherMouseDown(with: event)
        }
    }

    override func swipe(with event: NSEvent) {
        // A swipe to the right, like turning a page back.
        if event.deltaX > 0 { goBackOrForward(-1) }
        else if event.deltaX < 0 { goBackOrForward(1) }
        else { super.swipe(with: event) }
    }

    private func goBackOrForward(_ direction: Int) {
        linkPreview.close()
        if direction < 0 { goBack(nil) } else { goForward(nil) }
    }

    /// PDFKit's context menu, with a bookmark for the place clicked at.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let location = convert(event.locationInWindow, from: nil)
        guard onAddBookmark != nil, let document,
              let page = page(for: location, nearest: true)
        else { return menu }
        let index = document.index(for: page)
        guard index != NSNotFound else { return menu }
        // A little above the click, so that the line clicked at is in view when going there.
        let clicked = convert(location, to: page)
        let point = CGPoint(x: 0, y: min(clicked.y + 14, page.bounds(for: displayBox).maxY))
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        menu.addItem(ActionMenuItem(String(localized: "Lesezeichen hinzufügen …")) { [weak self] in
            self?.onAddBookmark?(index, point)
        })
        return menu
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.onAttach?()
            // Take the focus only if nothing else has it: not from the other view
            // of a split window, and not from the search field after a reload.
            if window.firstResponder == nil || window.firstResponder === window {
                window.makeFirstResponder(self)
            }
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    /// Copies the selected text with its paragraphs rejoined instead of one line break per
    /// line of the page, so it can be pasted into a word processor as running text. Fonts,
    /// and with them bold and italic, are kept as PDFKit's own copy keeps them.
    override func copy(_ sender: Any?) {
        guard let selection = currentSelection, document?.allowsCopying == true else {
            super.copy(sender)
            return
        }
        let text = Self.readableOnWhite(ParagraphText.text(of: selection))
        guard text.length > 0 else {
            super.copy(sender)
            return
        }
        // Formatted for word processors, which keep bold and italic, and plain for the rest.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let rtf = try? text.data(from: NSRange(location: 0, length: text.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        pasteboard.setString(text.string, forType: .string)
    }

    /// Text that is white or nearly so, as on the coloured bands of headings, turns black:
    /// pasted into a document it would otherwise be invisible on the white page.
    private static func readableOnWhite(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let color = (value as? NSColor)?.usingColorSpace(.sRGB) else { return }
            let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent
                + 0.0722 * color.blueComponent
            if luminance > 0.85 {
                result.addAttribute(.foregroundColor, value: NSColor.black, range: range)
            }
        }
        return result
    }

    override func keyDown(with event: NSEvent) {
        linkPreview.close()
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers.isEmpty, let key = event.specialKey else {
            super.keyDown(with: event)
            return
        }
        switch key {
        case .leftArrow where !canScrollHorizontally(towardsEnd: false):
            goToPreviousPage(nil)
        case .rightArrow where !canScrollHorizontally(towardsEnd: true):
            goToNextPage(nil)
        default:
            super.keyDown(with: event)
        }
    }

    /// When zoomed wider than the window, the arrow keys scroll sideways first and turn the page only at the edge.
    private func canScrollHorizontally(towardsEnd: Bool) -> Bool {
        guard let scrollView = documentView?.enclosingScrollView,
              let documentView = scrollView.documentView
        else { return false }
        let visible = scrollView.contentView.documentVisibleRect
        let bounds = documentView.bounds
        return towardsEnd ? visible.maxX < bounds.maxX - 1 : visible.minX > bounds.minX + 1
    }
}
