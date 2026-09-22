import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Offers to make Leser the default app for PDFs – rarely and only once Leser is really in use:
/// - never before PDFs were opened on three different days,
/// - at most twice, the second time 30 days and three more days of use after the first,
/// - never again once Leser was the default (switching back was a deliberate choice),
/// - only when Leser is installed in an Applications folder.
@MainActor
enum DefaultAppOffer {
    static let requiredUsageDays = 3
    static let repeatAfter: TimeInterval = 30 * 24 * 60 * 60
    static let maxOffers = 2

    private enum Key {
        static let usageDays = "defaultApp.usageDays"
        static let lastUsageDay = "defaultApp.lastUsageDay"
        static let offerCount = "defaultApp.offerCount"
        static let lastOfferDate = "defaultApp.lastOfferDate"
        static let usageDaysAtLastOffer = "defaultApp.usageDaysAtLastOffer"
        static let wasDefault = "defaultApp.wasDefault"
    }

    private static var defaults: UserDefaults { .standard }
    /// Only one window per app session shows the offer.
    private static var offeredThisSession = false

    // MARK: State of the system

    private static var currentDefaultURL: URL? {
        NSWorkspace.shared.urlForApplication(toOpen: .pdf)
    }

    static var isDefault: Bool {
        guard let url = currentDefaultURL else { return false }
        return Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// Name of the current default app for PDFs, e.g. "Vorschau".
    static var currentDefaultName: String? {
        currentDefaultURL.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    /// A copy outside the Applications folders (e.g. a build folder) must not become the default.
    static var isInstalled: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let folders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        return folders.contains { path.hasPrefix($0.resolvingSymlinksInPath().path + "/") }
    }

    static func makeDefault() async throws {
        // macOS asks the user to confirm the change.
        try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .pdf)
        defaults.set(true, forKey: Key.wasDefault)
    }

    // MARK: Usage and offers

    /// Counts the days on which Leser opened a document.
    static func recordUsage() {
        let today = Date.now.formatted(.iso8601.year().month().day())
        guard defaults.string(forKey: Key.lastUsageDay) != today else { return }
        defaults.set(today, forKey: Key.lastUsageDay)
        defaults.set(defaults.integer(forKey: Key.usageDays) + 1, forKey: Key.usageDays)
    }

    /// Returns true if the offer should be shown now, and records that it was shown.
    static func claimOffer() -> Bool {
        guard !offeredThisSession, shouldOffer() else { return false }
        offeredThisSession = true
        defaults.set(defaults.integer(forKey: Key.offerCount) + 1, forKey: Key.offerCount)
        defaults.set(Date.now, forKey: Key.lastOfferDate)
        defaults.set(defaults.integer(forKey: Key.usageDays), forKey: Key.usageDaysAtLastOffer)
        return true
    }

    private static func shouldOffer() -> Bool {
        if isDefault {
            defaults.set(true, forKey: Key.wasDefault)
            return false
        }
        guard isInstalled, !defaults.bool(forKey: Key.wasDefault) else { return false }

        let usageDays = defaults.integer(forKey: Key.usageDays)
        switch defaults.integer(forKey: Key.offerCount) {
        case 0:
            return usageDays >= requiredUsageDays
        case ..<maxOffers:
            guard let last = defaults.object(forKey: Key.lastOfferDate) as? Date else { return false }
            let newUsageDays = usageDays - defaults.integer(forKey: Key.usageDaysAtLastOffer)
            return Date.now.timeIntervalSince(last) >= repeatAfter && newUsageDays >= requiredUsageDays
        default:
            return false
        }
    }
}

/// Unobtrusive bar at the top of a document window.
struct DefaultAppBanner: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
            Text("Leser als Standard-App für PDFs verwenden?")
            Spacer(minLength: 8)
            Button("Als Standard festlegen") {
                Task {
                    try? await DefaultAppOffer.makeDefault()
                    onClose()
                }
            }
            Button("Nicht jetzt", action: onClose)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Settings row showing the current default app, with a button to change it.
struct DefaultAppSettingsRow: View {
    @State private var isDefault = DefaultAppOffer.isDefault
    @State private var currentName = DefaultAppOffer.currentDefaultName

    var body: some View {
        LabeledContent("Standard-App für PDF-Dokumente") {
            if isDefault {
                Label("Leser", systemImage: "checkmark")
            } else {
                HStack {
                    if let currentName {
                        Text(currentName).foregroundStyle(.secondary)
                    }
                    Button("Leser als Standard festlegen") {
                        Task {
                            try? await DefaultAppOffer.makeDefault()
                            refresh()
                        }
                    }
                    .disabled(!DefaultAppOffer.isInstalled)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isDefault = DefaultAppOffer.isDefault
        currentName = DefaultAppOffer.currentDefaultName
    }
}
