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

import Foundation
import Testing
@testable import Leser

/// Watching a file for changes, for reloading it.
@MainActor
@Suite(.serialized)
struct FileWatcherTests {
    private func file() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LeserTests-\(UUID().uuidString).pdf")
        try Data("eins".utf8).write(to: url)
        return url
    }

    /// Changes a file so that its modification date certainly differs.
    private func change(_ url: URL, to text: String, secondsLater: TimeInterval = 2) throws {
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: secondsLater)], ofItemAtPath: url.path)
    }

    @Test func writingReportsOneChange() async throws {
        let url = try file()
        var changes = 0
        let watcher = FileWatcher(url: url) { changes += 1 }
        defer { watcher.stop() }
        // Written in several steps, as programs do: reported once, when writing has settled.
        try change(url, to: "zwei")
        try change(url, to: "drei", secondsLater: 3)
        #expect(await eventually { changes == 1 })
        try await Task.sleep(for: .seconds(1))
        #expect(changes == 1)
    }

    @Test func fileReplacedOnSavingIsFollowed() async throws {
        let url = try file()
        var changes = 0
        let watcher = FileWatcher(url: url) { changes += 1 }
        defer { watcher.stop() }
        // Saved by writing a new file and moving it over the old one.
        let replacement = url.deletingLastPathComponent().appendingPathComponent("LeserTests-\(UUID().uuidString).tmp")
        try Data("neu".utf8).write(to: replacement)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 2)], ofItemAtPath: replacement.path)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: replacement)
        #expect(await eventually { changes == 1 })
        // And still watched after that.
        try change(url, to: "noch neuer", secondsLater: 4)
        #expect(await eventually { changes == 2 })
    }

    @Test func stoppedWatcherReportsNothing() async throws {
        let url = try file()
        var changes = 0
        let watcher = FileWatcher(url: url) { changes += 1 }
        watcher.stop()
        try change(url, to: "zwei")
        try await Task.sleep(for: .seconds(1))
        #expect(changes == 0)
    }
}

/// When Leser offers to become the default app for PDFs.
@MainActor
struct DefaultAppOfferTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    @Test func firstOfferAfterThreeDaysOfUse() {
        #expect(!DefaultAppOffer.isDue(usageDays: 2, offers: 0, lastOffer: nil, usageDaysAtLastOffer: 0, now: now))
        #expect(DefaultAppOffer.isDue(usageDays: 3, offers: 0, lastOffer: nil, usageDaysAtLastOffer: 0, now: now))
    }

    @Test func secondOfferAfterThirtyDaysAndThreeMoreDaysOfUse() {
        let lastOffer = now.addingTimeInterval(-31 * day)
        #expect(DefaultAppOffer.isDue(usageDays: 7, offers: 1, lastOffer: lastOffer, usageDaysAtLastOffer: 4, now: now))
        // Too soon after the first.
        #expect(!DefaultAppOffer.isDue(usageDays: 7, offers: 1, lastOffer: now.addingTimeInterval(-20 * day), usageDaysAtLastOffer: 4, now: now))
        // Not used enough since.
        #expect(!DefaultAppOffer.isDue(usageDays: 6, offers: 1, lastOffer: lastOffer, usageDaysAtLastOffer: 4, now: now))
        #expect(!DefaultAppOffer.isDue(usageDays: 7, offers: 1, lastOffer: nil, usageDaysAtLastOffer: 4, now: now))
    }

    @Test func neverMoreThanTwice() {
        #expect(!DefaultAppOffer.isDue(usageDays: 100, offers: 2, lastOffer: now.addingTimeInterval(-365 * day),
                                       usageDaysAtLastOffer: 0, now: now))
    }

    @Test func usageCountsEachDayOnce() async {
        await keepingDefaults(["defaultApp.usageDays", "defaultApp.lastUsageDay"]) {
            UserDefaults.standard.removeObject(forKey: "defaultApp.usageDays")
            UserDefaults.standard.removeObject(forKey: "defaultApp.lastUsageDay")
            DefaultAppOffer.recordUsage()
            DefaultAppOffer.recordUsage()
            #expect(UserDefaults.standard.integer(forKey: "defaultApp.usageDays") == 1)
            UserDefaults.standard.set("2000-01-01", forKey: "defaultApp.lastUsageDay")
            DefaultAppOffer.recordUsage()
            #expect(UserDefaults.standard.integer(forKey: "defaultApp.usageDays") == 2)
        }
    }
}
