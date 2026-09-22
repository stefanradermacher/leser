import AppKit
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum SplitAxis: String {
    case sideBySide, stacked

    static var preferred: SplitAxis {
        get { UserDefaults.standard.string(forKey: "splitAxis").flatMap(SplitAxis.init) ?? .sideBySide }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "splitAxis") }
    }
}

/// The views of one document window: the main view and an optional second view
/// showing the same document or another one. Toolbar, sidebar, search and menu
/// commands act on the active view, the one that last had keyboard focus.
@MainActor
@Observable
final class ReaderState {
    private(set) var primary: ViewerModel
    private(set) var secondary: ViewerModel?
    /// Another document chosen for the second view that still needs its password.
    private(set) var lockedSecondary: (document: PDFDocument, url: URL)?
    private(set) var isSecondaryActive = false
    private(set) var axis = SplitAxis.preferred
    var sidebarMode: SidebarMode
    /// Whether the search results are shown in the sidebar on the right.
    var showsSearchResults = false
    /// Information about the active document while its window is open.
    var documentInfo: DocumentInfo?

    func showDocumentInfo() {
        documentInfo = DocumentInfo(document: active.document, location: active.location, displayName: active.displayName)
    }
    /// Incremented to ask the window to show its sidebar.
    private(set) var sidebarRevealRequest = 0
    /// Incremented to put the focus into the search field. Kept per window, not per view,
    /// so that switching between the views of a split window does not trigger it.
    private(set) var searchFocusRequest = 0
    /// Incremented to open the "Go to page" field.
    private(set) var goToPageRequest = 0

    func requestSearchFocus() { searchFocusRequest += 1 }
    func requestGoToPage() { goToPageRequest += 1 }
    /// View that should get the focus while the split is being set up.
    @ObservationIgnored private weak var pendingFocus: ViewerModel?

    @ObservationIgnored private let primaryURL: URL?
    @ObservationIgnored private var primaryWatcher: FileWatcher?
    /// File of another document shown in the second view.
    @ObservationIgnored private var secondaryURL: URL?
    @ObservationIgnored private var secondaryWatcher: FileWatcher?

    init(primary: ViewerModel, fileURL: URL?) {
        self.primary = primary
        primaryURL = fileURL
        sidebarMode = Preferences.sidebarContent.mode(hasOutline: !primary.outline.isEmpty)
        watchFocus(of: primary)
        if let fileURL {
            primaryWatcher = FileWatcher(url: fileURL) { [weak self] in self?.reloadPrimary() }
        }
    }

    /// Ends file watching when the window closes.
    func stop() {
        primaryWatcher?.stop()
        secondaryWatcher?.stop()
    }

    /// Shows the sidebar with the given content.
    func showSidebar(_ mode: SidebarMode) {
        sidebarMode = mode
        sidebarRevealRequest += 1
    }

    var isSplit: Bool { secondary != nil || lockedSecondary != nil }

    var active: ViewerModel {
        isSecondaryActive ? secondary ?? primary : primary
    }

    func isActive(_ model: ViewerModel) -> Bool {
        isSplit && model === active
    }

    func activate(_ model: ViewerModel) {
        let secondaryActive = model === secondary
        if secondaryActive != isSecondaryActive { isSecondaryActive = secondaryActive }
    }

    // MARK: Opening and closing

    func toggleSplit() {
        if isSplit { closeSplit() } else { splitSameDocument() }
    }

    /// Shows the main document a second time, starting at the current page.
    func splitSameDocument() {
        showSecondary(ViewerModel(
            document: primary.document,
            fileURL: nil,
            displayName: primary.displayName,
            location: primary.location,
            startPage: primary.pageIndex
        ))
    }

    func closeSplit() {
        pendingFocus = nil
        secondary?.stop()
        secondary = nil
        stopWatchingSecondary()
        lockedSecondary = nil
        isSecondaryActive = false
        primary.focusDocument()
    }

    func setAxis(_ newAxis: SplitAxis) {
        guard newAxis != axis else { return }
        // Rearranging the views must not change which one is active.
        if isSplit {
            let current = active
            pendingFocus = current
            DispatchQueue.main.async { current.focusDocument() }
        }
        axis = newAxis
        SplitAxis.preferred = newAxis
    }

    func chooseOtherDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.message = "Dokument für die zweite Ansicht wählen"
        panel.prompt = "Öffnen"

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.openOtherDocument(at: url) }
        }
        if let window = primary.pdfView.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func openOtherDocument(at url: URL) {
        guard let document = PDFDocument(url: url) else {
            let alert = NSAlert()
            alert.messageText = "Das Dokument „\(url.lastPathComponent)“ konnte nicht geöffnet werden."
            alert.informativeText = "Die Datei ist beschädigt oder kein PDF-Dokument."
            if let window = primary.pdfView.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
            return
        }
        if document.isLocked {
            secondary?.stop()
            secondary = nil
            stopWatchingSecondary()
            lockedSecondary = (document, url)
            isSecondaryActive = false
        } else {
            showOtherDocument(document, url: url)
        }
    }

    func finishUnlocking() {
        guard let locked = lockedSecondary else { return }
        lockedSecondary = nil
        showOtherDocument(locked.document, url: locked.url)
    }

    private func showOtherDocument(_ document: PDFDocument, url: URL) {
        // A guest in this window: its reading position is not remembered.
        showSecondary(ViewerModel(document: document, fileURL: nil, displayName: url.lastPathComponent))
        secondaryURL = url
        secondaryWatcher = FileWatcher(url: url) { [weak self] in self?.reloadSecondary() }
    }

    private func stopWatchingSecondary() {
        secondaryWatcher?.stop()
        secondaryWatcher = nil
        secondaryURL = nil
    }

    private func showSecondary(_ model: ViewerModel) {
        stopWatchingSecondary()
        secondary?.stop()
        lockedSecondary = nil
        secondary = model
        watchFocus(of: model)
        // The new view becomes active once it is on screen.
        isSecondaryActive = true
        pendingFocus = model
        DispatchQueue.main.async { model.focusDocument() }
    }

    // MARK: Reloading changed files

    private func reloadPrimary() {
        guard Preferences.reloadOnChange, let url = primaryURL else { return }
        loadChangedDocument(at: url) { [weak self] document in
            guard let self else { return }
            let old = self.primary
            let focus = self.focusedModel()
            let replacement = ViewerModel(
                document: document, fileURL: url, displayName: old.displayName, restoring: old.snapshot()
            )
            // A second view of the same document is reloaded along with it.
            if let secondary = self.secondary, secondary.document === old.document {
                let newSecondary = ViewerModel(
                    document: document, fileURL: nil, displayName: secondary.displayName,
                    location: url, restoring: secondary.snapshot()
                )
                self.replaceSecondary(with: newSecondary, focus: focus === secondary)
            }
            old.stop()
            self.primary = replacement
            self.watchFocus(of: replacement)
            if focus === old { self.focusSoon(replacement) }
        }
    }

    private func reloadSecondary() {
        guard Preferences.reloadOnChange, let url = secondaryURL else { return }
        loadChangedDocument(at: url) { [weak self] document in
            guard let self, let old = self.secondary, self.secondaryURL == url else { return }
            let replacement = ViewerModel(
                document: document, fileURL: nil, displayName: old.displayName, restoring: old.snapshot()
            )
            self.replaceSecondary(with: replacement, focus: self.focusedModel() === old)
        }
    }

    private func replaceSecondary(with model: ViewerModel, focus: Bool) {
        secondary?.stop()
        secondary = model
        watchFocus(of: model)
        if focus { focusSoon(model) }
    }

    /// The view that has keyboard focus, if any (not the search field, for example).
    private func focusedModel() -> ViewerModel? {
        [primary, secondary].compactMap { $0 }.first { $0.pdfView.window?.firstResponder === $0.pdfView }
    }

    private func focusSoon(_ model: ViewerModel) {
        pendingFocus = model
        DispatchQueue.main.async { model.focusDocument() }
    }

    /// Loads the changed file; a program may still be writing it, so try again a few times.
    private func loadChangedDocument(at url: URL, attempt: Int = 1, then use: @escaping (PDFDocument) -> Void) {
        if let document = PDFDocument(url: url), document.pageCount > 0, !document.isLocked {
            use(document)
        } else if attempt < 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadChangedDocument(at: url, attempt: attempt + 1, then: use)
            }
        }
    }

    private func watchFocus(of model: ViewerModel) {
        model.pdfView.onFocus = { [weak self, weak model] in
            guard let self, let model else { return }
            // While the views are rearranged, the main view may grab the focus back.
            if let pending = self.pendingFocus {
                if pending === model {
                    self.pendingFocus = nil
                } else {
                    DispatchQueue.main.async { pending.focusDocument() }
                    return
                }
            }
            self.activate(model)
        }
    }
}

// MARK: - Views

/// The document area of a window: one view or two views with a movable divider.
struct SplitPanes: View {
    let state: ReaderState

    var body: some View {
        if state.isSplit {
            switch state.axis {
            case .sideBySide:
                HSplitView {
                    primaryPane.frame(minWidth: 200, maxWidth: .infinity)
                    secondaryPane.frame(minWidth: 200, maxWidth: .infinity)
                }
            case .stacked:
                VSplitView {
                    primaryPane.frame(minHeight: 150, maxHeight: .infinity)
                    secondaryPane.frame(minHeight: 150, maxHeight: .infinity)
                }
            }
        } else {
            PDFKitView(pdfView: state.primary.pdfView)
                .id(ObjectIdentifier(state.primary))
        }
    }

    private var primaryPane: some View {
        PaneView(state: state, model: state.primary, isSecondary: false)
    }

    @ViewBuilder
    private var secondaryPane: some View {
        if let secondary = state.secondary {
            PaneView(state: state, model: secondary, isSecondary: true)
        } else if let locked = state.lockedSecondary {
            VStack(spacing: 0) {
                PaneHeader(state: state, title: locked.url.lastPathComponent, isSecondary: true, isActive: false) {}
                UnlockView(document: locked.document) { state.finishUnlocking() }
            }
        }
    }
}

private struct PaneView: View {
    let state: ReaderState
    let model: ViewerModel
    let isSecondary: Bool

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(state: state, title: model.displayName, isSecondary: isSecondary, isActive: state.isActive(model)) {
                model.focusDocument()
            }
            PDFKitView(pdfView: model.pdfView)
                // A new document in this view brings its own PDF view.
                .id(ObjectIdentifier(model))
        }
    }
}

/// Small bar above each view of a split window, showing the document name.
/// The active view is marked with a line in the accent color.
private struct PaneHeader: View {
    let state: ReaderState
    let title: String
    let isSecondary: Bool
    let isActive: Bool
    let activate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isActive ? .primary : .secondary)
                .help(title)
            Spacer(minLength: 4)
            if isSecondary {
                Button("Anderes Dokument …") { state.chooseOtherDocument() }
                    .help("Ein anderes PDF in dieser Ansicht öffnen")
                Button {
                    state.closeSplit()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Geteilte Ansicht schließen")
                .accessibilityLabel("Geteilte Ansicht schließen")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator))
                .frame(height: isActive ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activate)
    }
}
