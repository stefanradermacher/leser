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
import PDFKit

/// Leser's own section of the print panel: how pages are fitted to the paper, and whether
/// they are turned to match it.
///
/// PDFKit keeps both choices in the print info under "PDFPrintScalingMode" and
/// "PDFPrintAutoRotate" and reads them when it lays out the pages, so the section only has
/// to change them there; the preview follows. The choice is remembered for the next print.
final class PrintOptions: NSViewController, NSPrintPanelAccessorizing {
    private static let scalingKey = "printScaling"
    private static let autoRotateKey = "printAutoRotate"
    private static let scalingInfoKey = NSPrintInfo.AttributeKey("PDFPrintScalingMode")
    private static let autoRotateInfoKey = NSPrintInfo.AttributeKey("PDFPrintAutoRotate")

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            scalingKey: PDFPrintScalingMode.pageScaleNone.rawValue,
            autoRotateKey: true,
        ])
    }

    static var scaling: PDFPrintScalingMode {
        PDFPrintScalingMode(rawValue: UserDefaults.standard.integer(forKey: scalingKey)) ?? .pageScaleNone
    }

    static var autoRotate: Bool {
        UserDefaults.standard.bool(forKey: autoRotateKey)
    }

    private let printInfo: NSPrintInfo

    /// The scaling as the raw value of `PDFPrintScalingMode`, observed by the print panel.
    @objc dynamic var scalingMode: Int {
        didSet {
            printInfo.dictionary()[Self.scalingInfoKey] = scalingMode
            UserDefaults.standard.set(scalingMode, forKey: Self.scalingKey)
            updateButtons()
        }
    }

    @objc dynamic var rotates: Bool {
        didSet {
            printInfo.dictionary()[Self.autoRotateInfoKey] = rotates
            UserDefaults.standard.set(rotates, forKey: Self.autoRotateKey)
            updateButtons()
        }
    }

    private let rotateButton = NSButton(checkboxWithTitle: String(localized: "Seiten automatisch drehen"),
                                        target: nil, action: nil)
    private let scalingButtons: [(PDFPrintScalingMode, NSButton)] = [
        (.pageScaleNone, NSButton(radioButtonWithTitle: String(localized: "Originalgröße"), target: nil, action: nil)),
        (.pageScaleDownToFit, NSButton(radioButtonWithTitle: String(localized: "Große Seiten verkleinern"), target: nil, action: nil)),
        (.pageScaleToFit, NSButton(radioButtonWithTitle: String(localized: "Auf Papierformat skalieren"), target: nil, action: nil)),
    ]

    init(printInfo: NSPrintInfo) {
        self.printInfo = printInfo
        scalingMode = Self.scaling.rawValue
        rotates = Self.autoRotate
        super.init(nibName: nil, bundle: nil)
        title = "Leser"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        rotateButton.target = self
        rotateButton.action = #selector(rotateChanged)
        for (_, button) in scalingButtons {
            button.target = self
            button.action = #selector(scalingChanged)
        }
        let scalingLabel = NSTextField(labelWithString: String(localized: "Seitenskalierung:"))
        let scalingStack = NSStackView(views: scalingButtons.map(\.1))
        scalingStack.orientation = .vertical
        scalingStack.alignment = .leading
        scalingStack.spacing = 6

        let stack = NSStackView(views: [rotateButton, scalingLabel, scalingStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(14, after: rotateButton)
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        view = stack
        updateButtons()
    }

    private func updateButtons() {
        guard isViewLoaded else { return }
        rotateButton.state = rotates ? .on : .off
        for (mode, button) in scalingButtons {
            button.state = mode.rawValue == scalingMode ? .on : .off
        }
    }

    @objc private func rotateChanged() {
        rotates = rotateButton.state == .on
    }

    @objc private func scalingChanged(_ sender: NSButton) {
        guard let mode = scalingButtons.first(where: { $0.1 === sender })?.0 else { return }
        scalingMode = mode.rawValue
    }

    // MARK: NSPrintPanelAccessorizing

    func localizedSummaryItems() -> [[NSPrintPanel.AccessorySummaryKey: String]] {
        let scaling = scalingButtons.first { $0.0.rawValue == scalingMode }?.1.title ?? ""
        return [
            [.itemName: String(localized: "Seitenskalierung"), .itemDescription: scaling],
            [.itemName: String(localized: "Seiten automatisch drehen"),
             .itemDescription: rotates ? String(localized: "Ein") : String(localized: "Aus")],
        ]
    }

    func keyPathsForValuesAffectingPreview() -> Set<String> {
        ["scalingMode", "rotates"]
    }
}
