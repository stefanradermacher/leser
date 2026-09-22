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


    @ObservationIgnored private var outlineItems: [Int: PDFOutline] = [:]
    @ObservationIgnored private var outlineNodes: [Int: OutlineNode] = [:]
    @ObservationIgnored private var requestedScale: CGFloat?
    @ObservationIgnored private var didInitialLayout = false
    /// Path of the PDF file, used to remember the reading position.
    @ObservationIgnored private let filePath: String?
    @ObservationIgnored nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    /// Page shown first when no reading position is remembered.
    @ObservationIgnored private let startPage: Int
    /// State to restore after reloading the document.
    @ObservationIgnored private let restoring: ViewSnapshot?
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
        self.filePath = fileURL?.standardizedFileURL.path
        self.displayName = displayName ?? fileURL?.lastPathComponent ?? document.documentURL?.lastPathComponent ?? String(localized: "Dokument")
        self.location = location ?? fileURL ?? document.documentURL
        self.startPage = startPage
        self.restoring = restoring
        if let restoring {
            pageLayout = restoring.layout
            fitMode = restoring.fitMode
            searchText = restoring.searchText
        }

        pdfView.document = document
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
        if isFinding { document.cancelFindString() }
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
        } else if Preferences.rememberPosition, let filePath,
           let saved = Preferences.readingPosition(for: filePath),
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
              let operation = document.printOperation(for: info, scalingMode: .pageScaleDownToFit, autoRotate: true)
        else { return }
        operation.jobTitle = displayName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.printPanel.options.formUnion([.showsPageRange, .showsCopies, .showsPaperSize, .showsOrientation, .showsScaling, .showsPreview])
        if let window = pdfView.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    func saveReadingPosition() {
        guard didInitialLayout, Preferences.rememberPosition, let filePath,
              let destination = pdfView.currentDestination,
              let page = destination.page
        else { return }
        let index = document.index(for: page)
        guard index != NSNotFound else { return }
        Preferences.setReadingPosition(
            .init(page: index, x: destination.point.x, y: destination.point.y, date: .now),
            for: filePath
        )
    }

    private func scaleDidChange() {
        scale = pdfView.scaleFactor
        if let requestedScale, abs(requestedScale - scale) < 0.0005 { return }
        // User zoomed by pinch or context menu – leave fit mode.
        fitMode = .none
    }

    // MARK: - Outline

    func selectOutline(_ id: Int) {
        selectedOutlineID = id
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

                let page = child.destination?.page ?? (child.action as? PDFActionGoTo)?.destination.page
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
                    children: children(of: child)
                )
                outlineNodes[id] = node
                return node
            }
        }
        return children(of: root)
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

        if document.isFinding { document.cancelFindString() }
        activeQuery = query
        matches = []
        currentMatchIndex = nil
        pdfView.highlightedSelections = nil
        pdfView.setCurrentSelection(nil, animate: false)

        guard !query.isEmpty else {
            isFinding = false
            return
        }
        isFinding = true
        document.beginFindString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
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
        matches.append(SearchMatch(
            id: matches.count,
            selection: selection,
            pageLabel: page.label ?? "\(index + 1)",
            context: Self.context(for: selection)
        ))
        if matches.count == 1 { goToMatch(0) }
    }

    private func finishSearch() {
        isFinding = false
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
        }
        observe(.PDFViewScaleChanged) { model, _ in model.scaleDidChange() }
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
        observe(.PDFDocumentDidFindMatch, of: document) { model, note in
            if let selection = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection {
                model.addMatch(selection)
            }
        }
        observe(.PDFDocumentDidEndFind, of: document) { model, _ in model.finishSearch() }
    }
}

/// PDFView that takes keyboard focus when it appears, so arrow keys and space scroll right away,
/// and turns pages with the left and right arrow keys.
final class ReaderPDFView: PDFView {
    /// Called when the view gets keyboard focus, used to track the active view of a split window.
    var onFocus: (() -> Void)?
    /// Called once the view is in a window.
    var onAttach: (() -> Void)?

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

    override func keyDown(with event: NSEvent) {
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
