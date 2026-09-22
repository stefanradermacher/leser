import PDFKit
import SwiftUI

struct ContentView: View {
    let document: PDFDocument
    let fileURL: URL?
    private let wasLocked: Bool
    @State private var isUnlocked: Bool

    init(document: PDFDocument, fileURL: URL?) {
        self.document = document
        self.fileURL = fileURL
        wasLocked = document.isLocked
        _isUnlocked = State(initialValue: !document.isLocked)
    }

    var body: some View {
        Group {
            if isUnlocked {
                // After entering a password is a bad moment to ask about the default app.
            ReaderView(document: document, fileURL: fileURL, offerDefaultApp: !wasLocked)
                    .id(ObjectIdentifier(document))
            } else {
                UnlockView(document: document) { isUnlocked = true }
            }
        }
        .background(WindowFrameKeeper())
    }
}

struct ReaderView: View {
    @State private var state: ReaderState
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var showsGoToPage = false
    @State private var showDefaultAppBanner = false
    private let offerDefaultApp: Bool
    @FocusState private var searchFocused: Bool

    init(document: PDFDocument, fileURL: URL?, offerDefaultApp: Bool) {
        self.offerDefaultApp = offerDefaultApp
        let model = ViewerModel(document: document, fileURL: fileURL)
        _state = State(initialValue: ReaderState(primary: model, fileURL: fileURL))
        let showSidebar = switch Preferences.openSidebar {
        case .automatic: !model.outline.isEmpty
        case .always: true
        case .never: false
        }
        _columnVisibility = State(initialValue: showSidebar ? .all : .detailOnly)
    }

    /// The view that toolbar, sidebar, search and menus act on.
    private var model: ViewerModel { state.active }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model, state: state)
                .navigationSplitViewColumnWidth(min: 180, ideal: 250, max: 450)
        } detail: {
            SplitPanes(state: state)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if showDefaultAppBanner {
                        DefaultAppBanner {
                            withAnimation { showDefaultAppBanner = false }
                            model.focusDocument()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                // Attached to the document area, so it starts below the toolbar.
                .inspector(isPresented: Binding(
                    get: { state.showsSearchResults },
                    set: { state.showsSearchResults = $0 }
                )) {
                    SearchResultsView(model: model)
                        .inspectorColumnWidth(min: 200, ideal: 270, max: 450)
                }
        }
        .task {
            DefaultAppOffer.recordUsage()
            guard offerDefaultApp else { return }
            // Let the document appear first.
            try? await Task.sleep(for: .seconds(1.5))
            if DefaultAppOffer.claimOffer() {
                withAnimation { showDefaultAppBanner = true }
            }
        }
        .searchable(
            text: Binding(get: { model.searchText }, set: { model.searchText = $0 }),
            placement: .toolbar,
            prompt: "Im Dokument suchen"
        )
        .searchFocused($searchFocused)
        .onSubmit(of: .search) {
            if !model.activeQuery.isEmpty { state.showsSearchResults = true }
            model.nextMatch()
        }
        .task(id: SearchRequest(model: ObjectIdentifier(model), text: model.searchText)) {
            // Short debounce while typing.
            if !model.searchText.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
            guard !Task.isCancelled else { return }
            model.performSearch()
        }
        .onChange(of: model.activeQuery) { _, query in
            // Results appear on the right while searching and go away with the search.
            withAnimation { state.showsSearchResults = !query.isEmpty }
        }
        .onChange(of: ObjectIdentifier(model)) {
            // In a split window the results belong to the active view.
            state.showsSearchResults = !model.activeQuery.isEmpty
        }
        .onChange(of: state.sidebarRevealRequest) {
            withAnimation { columnVisibility = .all }
        }
        .onChange(of: state.searchFocusRequest) { searchFocused = true }
        .onChange(of: state.goToPageRequest) { showsGoToPage = true }
        // As in Preview: the page number below the document name.
        .navigationSubtitle(pageSubtitle)
        .toolbar {
            separateItem { navigationGroup }
            separateItem { displayGroup }
            separateItem { zoomGroup }
        }
        .focusedSceneValue(\.viewer, model)
        .focusedSceneValue(\.reader, state)
        .sheet(isPresented: Binding(
            get: { state.documentInfo != nil },
            set: { if !$0 { state.documentInfo = nil } }
        )) {
            if let info = state.documentInfo {
                DocumentInfoView(info: info)
            }
        }
        .onDisappear {
            state.primary.saveReadingPosition()
            state.stop()
        }
    }

    /// A toolbar group in its own capsule, as in Preview. With Liquid Glass (macOS 26 and later)
    /// the toolbar would otherwise put neighbouring items into one shared capsule.
    @ToolbarContentBuilder
    private func separateItem<Content: View>(@ViewBuilder _ content: () -> Content) -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem {
                content()
                    .padding(.horizontal, 4)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem { content() }
        }
    }

    private var pageSubtitle: String {
        let number = model.pageIndex + 1
        let label = model.pageLabel
        // Some documents number their pages differently, e.g. with roman numerals.
        return label == "\(number)"
            ? "Seite \(number) von \(model.pageCount)"
            : "Seite \(label) (\(number) von \(model.pageCount))"
    }

    /// Previous and next page; "Go to page" opens below it.
    private var navigationGroup: some View {
        ToolbarSegments(segments: [
            ToolbarSegment(symbol: "chevron.up", label: "Vorherige Seite",
                           isEnabled: model.pageIndex > 0, action: { model.previousPage() }),
            ToolbarSegment(symbol: "chevron.down", label: "Nächste Seite",
                           isEnabled: model.pageIndex < model.pageCount - 1, action: { model.nextPage() }),
        ])
        .popover(isPresented: $showsGoToPage, arrowEdge: .bottom) {
            GoToPageView(model: model) { showsGoToPage = false }
        }
    }

    /// Page layout and split view.
    private var displayGroup: some View {
        let model = model
        let state = state
        return ToolbarSegments(segments: [
            ToolbarSegment(symbol: model.pageLayout.systemImage, label: "Anzeige: \(model.pageLayout.title)", menu: {
                let menu = NSMenu()
                for layout in PageLayout.allCases {
                    menu.addItem(ActionMenuItem(layout.title, symbol: layout.systemImage, checked: layout == model.pageLayout) {
                        model.setPageLayout(layout)
                    })
                }
                return menu
            }),
            ToolbarSegment(symbol: state.axis == .stacked ? "square.split.1x2" : "square.split.2x1",
                           label: state.isSplit ? "Geteilte Ansicht schließen" : "Ansicht teilen",
                           action: { state.toggleSplit() }),
        ])
    }

    /// Zoom out | zoom level with fit options | zoom in – like Preview's zoom group.
    private var zoomGroup: some View {
        let model = model
        return ToolbarSegments(segments: [
            ToolbarSegment(symbol: "minus.magnifyingglass", label: "Verkleinern", action: { model.zoomOut() }),
            ToolbarSegment(title: "\(Int((model.scale * 100).rounded())) %", label: "Zoomstufe", menu: {
                let menu = NSMenu()
                let fits: [(String, FitMode)] = [("Seitenbreite", .width), ("Seitenhöhe", .height), ("Ganze Seite", .page)]
                for (title, mode) in fits {
                    menu.addItem(ActionMenuItem(title, checked: model.fitMode == mode) { model.setFitMode(mode) })
                }
                menu.addItem(.separator())
                for level in ViewerModel.menuZoomLevels {
                    menu.addItem(ActionMenuItem("\(Int(level * 100)) %") { model.setZoom(level) })
                }
                return menu
            }),
            ToolbarSegment(symbol: "plus.magnifyingglass", label: "Vergrößern", action: { model.zoomIn() }),
        ])
    }
}

/// Small field to jump to a page, opened with "Go to page" (⌥⌘G).
private struct GoToPageView: View {
    let model: ViewerModel
    let close: () -> Void

    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("Seite")
            TextField("Seite", text: $input)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 56)
                .focused($focused)
                .onSubmit(go)
            Text("von \(model.pageCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button("Gehe zu", action: go)
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
        .onAppear {
            input = "\(model.pageIndex + 1)"
            focused = true
        }
    }

    private func go() {
        if let number = Int(input.trimmingCharacters(in: .whitespaces)) {
            model.goToPage(number - 1)
        }
        close()
        model.focusDocument()
    }
}

/// Identifies a search: the text typed and the view it applies to.
private struct SearchRequest: Equatable {
    let model: ObjectIdentifier
    let text: String
}

struct PDFKitView: NSViewRepresentable {
    let pdfView: PDFView

    func makeNSView(context: Context) -> PDFView { pdfView }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}

struct UnlockView: View {
    let document: PDFDocument
    let onUnlock: () -> Void

    @State private var password = ""
    @State private var failed = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.doc")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Dieses Dokument ist durch ein Passwort geschützt.")
                .font(.headline)
            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit(unlock)
            if failed {
                Text("Das Passwort ist nicht korrekt.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            Button("Entsperren", action: unlock)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unlock() {
        if document.unlock(withPassword: password) {
            onUnlock()
        } else {
            failed = true
            password = ""
        }
    }
}
