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
import SwiftUI
import Testing
@testable import Leser

/// The split of the sidebar: the bookmark area fitted to its rows, up to its share.
@MainActor
struct SplitViewTests {
    /// A list of rows standing in for the bookmarks.
    private final class Rows: NSObject, NSTableViewDataSource {
        var count: Int
        init(_ count: Int) { self.count = count }
        func numberOfRows(in tableView: NSTableView) -> Int { count }
    }

    private typealias Container = SplitContainer<EmptyView, EmptyView>

    /// A stacked split view of 600 points whose first half holds a list of `rows` rows.
    private func split(rows: Int) -> (NSSplitView, NSTableView, Rows, Container.Coordinator) {
        let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("Name")))
        // Plain, so that the rows start right at the top; the inset style adds room of its own.
        table.style = .plain
        table.rowHeight = 24
        table.intercellSpacing = .zero
        let rows = Rows(rows)
        table.dataSource = rows
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        scrollView.documentView = table
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsetsZero
        let first = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        first.addSubview(scrollView)
        splitView.addSubview(first)
        splitView.addSubview(NSView(frame: NSRect(x: 0, y: 301, width: 300, height: 299)))
        table.reloadData()

        let coordinator = Container.Coordinator(share: 0.3)
        coordinator.minimum = 60
        coordinator.fitShare = 0.5
        splitView.delegate = coordinator
        return (splitView, table, rows, coordinator)
    }

    private func firstHeight(_ splitView: NSSplitView) -> CGFloat {
        splitView.subviews[0].frame.height
    }

    private func relayout(_ splitView: NSSplitView, _ coordinator: Container.Coordinator) async {
        coordinator.relayoutSoon(splitView)
        // The new size is set on the next turn of the main queue.
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test func fittedToTheRowsWithRoomBelow() async {
        let (splitView, _, _, coordinator) = split(rows: 3)
        await relayout(splitView, coordinator)
        #expect(abs(firstHeight(splitView) - (3 * 24 + 10)) <= 1)
    }

    @Test func followsRowsAddedAndRemoved() async {
        let (splitView, table, rows, coordinator) = split(rows: 3)
        await relayout(splitView, coordinator)
        rows.count = 5
        table.reloadData()
        await relayout(splitView, coordinator)
        #expect(abs(firstHeight(splitView) - (5 * 24 + 10)) <= 1)
        rows.count = 3
        table.reloadData()
        await relayout(splitView, coordinator)
        #expect(abs(firstHeight(splitView) - (3 * 24 + 10)) <= 1)
        // Both halves fill the split view, with the divider between them.
        let second = splitView.subviews[1].frame
        #expect(abs(second.minY - (firstHeight(splitView) + splitView.dividerThickness)) <= 1)
        #expect(abs(second.maxY - 600) <= 1)
    }

    @Test func neverLessThanTheMinimum() async {
        let (splitView, _, _, coordinator) = split(rows: 1)
        await relayout(splitView, coordinator)
        #expect(firstHeight(splitView) == 60)
    }

    @Test func neverMoreThanItsShare() async {
        let (splitView, _, _, coordinator) = split(rows: 40)
        await relayout(splitView, coordinator)
        let available = 600 - splitView.dividerThickness
        #expect(abs(firstHeight(splitView) - available * 0.5) <= 1)
    }

    @Test func fittingIsNotTakenForTheReaderMovingTheDivider() async {
        let (splitView, table, rows, coordinator) = split(rows: 3)
        var moved: [CGFloat] = []
        coordinator.dividerMoved = { moved.append($0) }
        await relayout(splitView, coordinator)
        rows.count = 6
        table.reloadData()
        await relayout(splitView, coordinator)
        #expect(moved.isEmpty)
    }
}
