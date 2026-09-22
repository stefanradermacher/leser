import Foundation

/// Reports changes to a file. Also follows files that programs replace when saving
/// (write a new file, then move it over the old one), which ends the watch on the
/// old file: the watcher then waits for the file to appear again under the same path.
@MainActor
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var lastModification: Date?
    private var pendingNotification: DispatchWorkItem?
    private var reopenAttempts = 0

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        lastModification = Self.modificationDate(of: url)
        start()
    }

    func stop() {
        pendingNotification?.cancel()
        source?.cancel()
        source = nil
    }

    private func start() {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            reopenLater()
            return
        }
        reopenAttempts = 0
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let events = source.data
            MainActor.assumeIsolated {
                if !events.isDisjoint(with: [.delete, .rename]) {
                    // The file was replaced or removed: watch the path again.
                    self.source?.cancel()
                    self.source = nil
                    self.reopenLater()
                }
                self.scheduleNotification()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func reopenLater() {
        // Give up after about 10 seconds, e.g. when the file was deleted for good.
        guard reopenAttempts < 40 else { return }
        reopenAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.source == nil else { return }
            self.start()
            if self.source != nil { self.scheduleNotification() }
        }
    }

    /// Waits until writing has settled, then reports the change once.
    private func scheduleNotification() {
        pendingNotification?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let modification = Self.modificationDate(of: self.url)
            guard modification != nil, modification != self.lastModification else { return }
            self.lastModification = modification
            self.onChange()
        }
        pendingNotification = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
