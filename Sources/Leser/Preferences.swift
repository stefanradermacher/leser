import AppKit
import SwiftUI

/// User settings, stored in UserDefaults.
enum Preferences {
    static let layoutKey = "openLayout"
    static let zoomKey = "openZoom"
    static let sidebarKey = "openSidebar"
    static let sidebarContentKey = "sidebarContent"
    static let tabbingKey = "tabbing"
    static let rememberPositionKey = "rememberPosition"
    static let showSingleTabBarKey = "showSingleTabBar"
    static let reloadOnChangeKey = "reloadOnChange"
    private static let positionsKey = "readingPositions"

    /// Value of `layoutKey` meaning "use the layout chosen last".
    static let lastUsedLayout = "last"

    static func register() {
        UserDefaults.standard.register(defaults: [
            layoutKey: lastUsedLayout,
            zoomKey: ZoomPreference.width.rawValue,
            sidebarKey: SidebarPreference.automatic.rawValue,
            sidebarContentKey: SidebarContentPreference.outline.rawValue,
            tabbingKey: TabbingPreference.system.rawValue,
            rememberPositionKey: true,
            showSingleTabBarKey: false,
            reloadOnChangeKey: true,
        ])
    }

    private static func string(_ key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    static var openLayout: PageLayout {
        PageLayout(rawValue: string(layoutKey)) ?? PageLayout.preferred
    }

    static var openZoom: ZoomPreference {
        ZoomPreference(rawValue: string(zoomKey)) ?? .width
    }

    static var openSidebar: SidebarPreference {
        SidebarPreference(rawValue: string(sidebarKey)) ?? .automatic
    }

    static var sidebarContent: SidebarContentPreference {
        SidebarContentPreference(rawValue: string(sidebarContentKey)) ?? .outline
    }

    static var tabbing: TabbingPreference {
        TabbingPreference(rawValue: string(tabbingKey)) ?? .system
    }

    static var showSingleTabBar: Bool {
        UserDefaults.standard.bool(forKey: showSingleTabBarKey)
    }

    static var reloadOnChange: Bool {
        UserDefaults.standard.bool(forKey: reloadOnChangeKey)
    }

    static var rememberPosition: Bool {
        UserDefaults.standard.bool(forKey: rememberPositionKey)
    }

    // MARK: Reading positions

    struct ReadingPosition: Codable {
        var page: Int
        var x: Double
        var y: Double
        var date: Date
    }

    private static let maxStoredPositions = 200

    static func readingPosition(for path: String) -> ReadingPosition? {
        positions()[path]
    }

    static func setReadingPosition(_ position: ReadingPosition, for path: String) {
        var all = positions()
        all[path] = position
        if all.count > maxStoredPositions {
            // Forget the documents read longest ago.
            let oldest = all.sorted { $0.value.date < $1.value.date }.prefix(all.count - maxStoredPositions)
            oldest.forEach { all.removeValue(forKey: $0.key) }
        }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: positionsKey)
        }
    }

    static func forgetReadingPositions() {
        UserDefaults.standard.removeObject(forKey: positionsKey)
    }

    private static func positions() -> [String: ReadingPosition] {
        guard let data = UserDefaults.standard.data(forKey: positionsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ReadingPosition].self, from: data)) ?? [:]
    }
}

enum ZoomPreference: String, CaseIterable, Identifiable {
    case width, height, page, actual

    var id: Self { self }

    var title: String {
        switch self {
        case .width: String(localized: "Seitenbreite")
        case .height: String(localized: "Seitenhöhe")
        case .page: String(localized: "Ganze Seite")
        case .actual: String(localized: "Originalgröße (100 %)")
        }
    }

    var fitMode: FitMode {
        switch self {
        case .width: .width
        case .height: .height
        case .page: .page
        case .actual: .none
        }
    }
}

enum SidebarPreference: String, CaseIterable, Identifiable {
    case automatic, always, never

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Wenn das Dokument eine Gliederung hat")
        case .always: String(localized: "Immer")
        case .never: String(localized: "Nie")
        }
    }
}

enum SidebarContentPreference: String, CaseIterable, Identifiable {
    case outline, thumbnails

    var id: Self { self }

    var title: String {
        switch self {
        case .outline: String(localized: "Gliederung, sonst Miniaturen")
        case .thumbnails: String(localized: "Miniaturen")
        }
    }

    /// What the sidebar of a newly opened document shows.
    func mode(hasOutline: Bool) -> SidebarMode {
        self == .outline && hasOutline ? .outline : .thumbnails
    }
}

enum TabbingPreference: String, CaseIterable, Identifiable {
    case system, tabs, windows

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "Wie in den Systemeinstellungen")
        case .tabs: String(localized: "Als Tab im vorhandenen Fenster")
        case .windows: String(localized: "In einem neuen Fenster")
        }
    }

    var tabbingMode: NSWindow.TabbingMode {
        switch self {
        case .system: .automatic
        case .tabs: .preferred
        case .windows: .disallowed
        }
    }
}

struct SettingsView: View {
    @AppStorage(Preferences.layoutKey) private var layout = Preferences.lastUsedLayout
    @AppStorage(Preferences.zoomKey) private var zoom = ZoomPreference.width.rawValue
    @AppStorage(Preferences.sidebarKey) private var sidebar = SidebarPreference.automatic.rawValue
    @AppStorage(Preferences.sidebarContentKey) private var sidebarContent = SidebarContentPreference.outline.rawValue
    @AppStorage(Preferences.tabbingKey) private var tabbing = TabbingPreference.system.rawValue
    @AppStorage(Preferences.rememberPositionKey) private var rememberPosition = true
    @AppStorage(Preferences.showSingleTabBarKey) private var showSingleTabBar = false
    @AppStorage(Preferences.reloadOnChangeKey) private var reloadOnChange = true

    var body: some View {
        Form {
            Section {
                DefaultAppSettingsRow()
            } footer: {
                if !DefaultAppOffer.isInstalled {
                    Text("Um Leser als Standard festzulegen, muss die App im Ordner „Programme“ liegen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Beim Öffnen eines Dokuments") {
                Picker("Anzeige", selection: $layout) {
                    Text("Zuletzt verwendet").tag(Preferences.lastUsedLayout)
                    Divider()
                    ForEach(PageLayout.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Zoom", selection: $zoom) {
                    ForEach(ZoomPreference.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Seitenleiste anzeigen", selection: $sidebar) {
                    ForEach(SidebarPreference.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Seitenleiste zeigt", selection: $sidebarContent) {
                    ForEach(SidebarContentPreference.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .disabled(sidebar == SidebarPreference.never.rawValue)
                Picker("Neue Dokumente öffnen", selection: $tabbing) {
                    ForEach(TabbingPreference.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section {
                Toggle("Tableiste auch bei nur einem Dokument anzeigen", isOn: $showSingleTabBar)
                    .onChange(of: showSingleTabBar) { TabBarKeeper.updateAll() }
            }
            Section {
                Toggle("Dokument neu laden, wenn sich die Datei ändert", isOn: $reloadOnChange)
            } footer: {
                Text("Praktisch für PDFs, die ein anderes Programm erzeugt, etwa beim Export oder mit LaTeX. Seite, Zoom und Anzeige bleiben dabei erhalten.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("An der zuletzt gelesenen Stelle weiterlesen", isOn: $rememberPosition)
                    .onChange(of: rememberPosition) { _, remember in
                        if !remember { Preferences.forgetReadingPositions() }
                    }
            } footer: {
                Text("Leser merkt sich für jedes Dokument die Seite, auf der du zuletzt warst. Beim Ausschalten werden alle gespeicherten Stellen gelöscht.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
