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
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// A picture embedded in a page, as the PDF holds it: in its own resolution and with its
/// transparency, not as it happens to be shown on screen.
struct PageImage {
    let page: PDFPage
    let stream: CGPDFStreamRef
    /// Maps the unit square of the picture to page coordinates, as when it was drawn.
    let placement: CGAffineTransform

    /// Where the picture lies on the page.
    var bounds: CGRect { CGRect(x: 0, y: 0, width: 1, height: 1).applying(placement) }

    private var dictionary: CGPDFDictionaryRef? { CGPDFStreamGetDictionary(stream) }

    /// The picture with its transparency, if it has any.
    func image() -> CGImage? {
        guard let dictionary, let base = Self.decode(stream) else { return nil }
        var mask: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(dictionary, "SMask", &mask), let mask,
              let alpha = Self.decode(mask, colorSpace: CGColorSpaceCreateDeviceGray())
        else { return base }
        return Self.combine(base, alpha: alpha)
    }

    /// Whether the picture has a soft mask, that is shades of transparency.
    var hasTransparency: Bool {
        guard let dictionary else { return false }
        var mask: CGPDFStreamRef?
        return CGPDFDictionaryGetStream(dictionary, "SMask", &mask)
    }

    /// The picture as a file: a JPEG without transparency exactly as the PDF holds it,
    /// anything else as PNG with its transparency.
    func fileData() -> (data: Data, type: UTType)? {
        var format = CGPDFDataFormat.raw
        if !hasTransparency, let data = CGPDFStreamCopyData(stream, &format) as Data?, format == .jpegEncoded {
            return (data, .jpeg)
        }
        guard let image = image() else { return nil }
        return Self.png(image).map { ($0, .png) }
    }

    /// Puts the picture on the pasteboard as PNG and TIFF, both with their transparency.
    func copy() {
        guard let image = image(), let png = Self.png(image) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        pasteboard.setData(png, forType: .png)
        pasteboard.setData(NSBitmapImageRep(cgImage: image).tiffRepresentation, forType: .tiff)
    }

    /// Whether the picture shows something at a point of the page, rather than being clear there.
    func covers(_ point: CGPoint) -> Bool {
        let local = point.applying(placement.inverted())
        guard (0...1).contains(local.x), (0...1).contains(local.y) else { return false }
        guard let dictionary else { return true }
        var mask: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(dictionary, "SMask", &mask), let mask,
              let alpha = Self.decode(mask, colorSpace: CGColorSpaceCreateDeviceGray())
        else { return true }
        // Row 0 of a picture is its top edge.
        let x = min(Int(local.x * CGFloat(alpha.width)), alpha.width - 1)
        let y = min(Int((1 - local.y) * CGFloat(alpha.height)), alpha.height - 1)
        return Self.gray(of: alpha, x: x, y: y) > 12
    }

    // MARK: Decoding

    /// Decodes an image stream: JPEG and JPEG 2000 as such, everything else from its samples.
    /// Returns nil for what CoreGraphics does not decode, like CCITT or JBIG2 scans.
    static func decode(_ stream: CGPDFStreamRef, colorSpace fixed: CGColorSpace? = nil) -> CGImage? {
        guard let dictionary = CGPDFStreamGetDictionary(stream) else { return nil }
        var isMask: CGPDFBoolean = 0
        if CGPDFDictionaryGetBoolean(dictionary, "ImageMask", &isMask), isMask != 0 { return nil }
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) as Data? else { return nil }
        switch format {
        case .jpegEncoded, .JPEG2000:
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        case .raw:
            break
        @unknown default:
            return nil
        }
        let width = integer(dictionary, "Width"), height = integer(dictionary, "Height")
        let bits = integer(dictionary, "BitsPerComponent")
        guard width > 0, height > 0, [1, 2, 4, 8, 16].contains(bits),
              let space = fixed ?? colorSpace(of: dictionary)
        else { return nil }
        let components = space.model == .indexed ? 1 : space.numberOfComponents
        let bytesPerRow = (width * components * bits + 7) / 8
        guard data.count >= bytesPerRow * height, let provider = CGDataProvider(data: data as CFData) else { return nil }
        let decode = decodeArray(dictionary, components: components)
        // Samples of 16 bits are stored with the high byte first.
        var info = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        if bits == 16 { info.insert(.byteOrder16Big) }
        return CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits * components,
                       bytesPerRow: bytesPerRow, space: space, bitmapInfo: info,
                       provider: provider, decode: decode, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func integer(_ dictionary: CGPDFDictionaryRef, _ key: String) -> Int {
        var value: CGPDFInteger = 0
        return CGPDFDictionaryGetInteger(dictionary, key, &value) ? value : 0
    }

    private static func decodeArray(_ dictionary: CGPDFDictionaryRef, components: Int) -> [CGFloat]? {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Decode", &array), let array,
              CGPDFArrayGetCount(array) == components * 2
        else { return nil }
        return (0..<components * 2).map { index in
            var value: CGPDFReal = 0
            return CGPDFArrayGetNumber(array, index, &value) ? value : 0
        }
    }

    /// The colour space of a picture, for those CoreGraphics can build.
    private static func colorSpace(of dictionary: CGPDFDictionaryRef) -> CGColorSpace? {
        var object: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(dictionary, "ColorSpace", &object), let object else { return nil }
        return colorSpace(object)
    }

    private static func colorSpace(_ object: CGPDFObjectRef) -> CGColorSpace? {
        var name: UnsafePointer<CChar>?
        if CGPDFObjectGetValue(object, .name, &name), let name {
            switch String(cString: name) {
            case "DeviceRGB", "CalRGB": return CGColorSpaceCreateDeviceRGB()
            case "DeviceGray", "CalGray": return CGColorSpaceCreateDeviceGray()
            case "DeviceCMYK": return CGColorSpaceCreateDeviceCMYK()
            default: return nil
            }
        }
        var array: CGPDFArrayRef?
        guard CGPDFObjectGetValue(object, .array, &array), let array,
              CGPDFArrayGetName(array, 0, &name), let name
        else { return nil }
        switch String(cString: name) {
        case "CalRGB": return CGColorSpaceCreateDeviceRGB()
        case "CalGray": return CGColorSpaceCreateDeviceGray()
        case "ICCBased":
            var profile: CGPDFStreamRef?
            guard CGPDFArrayGetStream(array, 1, &profile), let profile else { return nil }
            var format = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(profile, &format), let space = CGColorSpace(iccData: data) {
                return space
            }
            // Without a usable profile, the number of components decides.
            switch CGPDFStreamGetDictionary(profile).map({ integer($0, "N") }) {
            case 1: return CGColorSpaceCreateDeviceGray()
            case 4: return CGColorSpaceCreateDeviceCMYK()
            default: return CGColorSpaceCreateDeviceRGB()
            }
        case "Indexed", "I":
            var baseObject: CGPDFObjectRef?
            var highest: CGPDFInteger = 0
            guard CGPDFArrayGetObject(array, 1, &baseObject), let baseObject,
                  let base = colorSpace(baseObject),
                  CGPDFArrayGetInteger(array, 2, &highest), highest >= 0, highest < 256
            else { return nil }
            var table: Data?
            var string: CGPDFStringRef?
            var stream: CGPDFStreamRef?
            if CGPDFArrayGetString(array, 3, &string), let string, let bytes = CGPDFStringGetBytePtr(string) {
                table = Data(bytes: bytes, count: CGPDFStringGetLength(string))
            } else if CGPDFArrayGetStream(array, 3, &stream), let stream {
                var format = CGPDFDataFormat.raw
                table = CGPDFStreamCopyData(stream, &format) as Data?
            }
            let needed = (highest + 1) * base.numberOfComponents
            guard let table, table.count >= needed else { return nil }
            return table.withUnsafeBytes { bytes in
                CGColorSpace(indexedBaseSpace: base, last: highest,
                             colorTable: bytes.bindMemory(to: UInt8.self).baseAddress!)
            }
        default:
            return nil
        }
    }

    /// The picture with the soft mask as its alpha channel, in sRGB.
    private static func combine(_ image: CGImage, alpha: CGImage) -> CGImage? {
        // A grey image as mask gives the alpha of each pixel; it is scaled to the picture.
        guard let masked = image.masking(alpha),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(masked, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private static func gray(of image: CGImage, x: Int, y: Int) -> UInt8 {
        var pixel: UInt8 = 0
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return 255 }
        // Draws the picture so that its pixel (x, y), counted from the top, lands on the one pixel.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return pixel
    }

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

/// Finds the pictures a page draws and where, by going through its content as a renderer
/// would: the transformation in effect at each picture, also inside form XObjects.
enum PageImages {
    /// The pictures of a page in the order they are drawn, the topmost last.
    static func images(on page: PDFPage) -> [PageImage] {
        guard let pageRef = page.pageRef else { return [] }
        let state = ScanState(page: page)
        let contentStream = CGPDFContentStreamCreateWithPage(pageRef)
        state.scan(contentStream)
        CGPDFContentStreamRelease(contentStream)
        return state.found
    }

    /// The topmost picture showing something at a point of the page.
    static func image(at point: CGPoint, on page: PDFPage) -> PageImage? {
        images(on: page).last { $0.covers(point) }
    }

    fileprivate final class ScanState {
        let page: PDFPage
        var found: [PageImage] = []
        var transform = CGAffineTransform.identity
        var saved: [CGAffineTransform] = []
        var depth = 0
        let table: CGPDFOperatorTableRef

        /// The resources of the page itself.
        var pageResources: CGPDFDictionaryRef? {
            var resources: CGPDFDictionaryRef?
            guard let dictionary = page.pageRef?.dictionary,
                  CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources)
            else { return nil }
            return resources
        }

        init(page: PDFPage) {
            self.page = page
            table = CGPDFOperatorTableCreate()!
            CGPDFOperatorTableSetCallback(table, "q") { _, info in
                let state = ScanState.from(info)
                state.saved.append(state.transform)
            }
            CGPDFOperatorTableSetCallback(table, "Q") { _, info in
                let state = ScanState.from(info)
                if let last = state.saved.popLast() { state.transform = last }
            }
            CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
                var values = [CGPDFReal](repeating: 0, count: 6)
                for index in (0..<6).reversed() {
                    guard CGPDFScannerPopNumber(scanner, &values[index]) else { return }
                }
                let state = ScanState.from(info)
                let matrix = CGAffineTransform(a: values[0], b: values[1], c: values[2],
                                               d: values[3], tx: values[4], ty: values[5])
                state.transform = matrix.concatenating(state.transform)
            }
            CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
                var name: UnsafePointer<CChar>?
                guard CGPDFScannerPopName(scanner, &name), let name else { return }
                let state = ScanState.from(info)
                let contentStream = CGPDFScannerGetContentStream(scanner)
                guard let object = CGPDFContentStreamGetResource(contentStream, "XObject", name) else { return }
                var stream: CGPDFStreamRef?
                guard CGPDFObjectGetValue(object, .stream, &stream), let stream,
                      let dictionary = CGPDFStreamGetDictionary(stream)
                else { return }
                var subtype: UnsafePointer<CChar>?
                guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else { return }
                switch String(cString: subtype) {
                case "Image":
                    state.found.append(PageImage(page: state.page, stream: stream, placement: state.transform))
                case "Form":
                    state.scanForm(stream, dictionary: dictionary, parent: contentStream)
                default:
                    break
                }
            }
        }

        deinit { CGPDFOperatorTableRelease(table) }

        static func from(_ info: UnsafeMutableRawPointer?) -> ScanState {
            Unmanaged<ScanState>.fromOpaque(info!).takeUnretainedValue()
        }

        func scan(_ contentStream: CGPDFContentStreamRef) {
            let scanner = CGPDFScannerCreate(contentStream, table, Unmanaged.passUnretained(self).toOpaque())
            CGPDFScannerScan(scanner)
            CGPDFScannerRelease(scanner)
        }

        /// A form XObject draws its content with its own matrix and resources.
        func scanForm(_ stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, parent: CGPDFContentStreamRef) {
            // Forms may contain forms; a document that loops would otherwise never end.
            guard depth < 12 else { return }
            depth += 1
            let outer = transform, outerSaved = saved
            var array: CGPDFArrayRef?
            if CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array, CGPDFArrayGetCount(array) == 6 {
                var values = [CGPDFReal](repeating: 0, count: 6)
                for index in 0..<6 { CGPDFArrayGetNumber(array, index, &values[index]) }
                transform = CGAffineTransform(a: values[0], b: values[1], c: values[2],
                                              d: values[3], tx: values[4], ty: values[5]).concatenating(transform)
            }
            // Old documents leave out a form's resources; it then uses those of the page.
            var resources: CGPDFDictionaryRef?
            CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources)
            if let resources = resources ?? pageResources {
                let contentStream = CGPDFContentStreamCreateWithStream(stream, resources, parent)
                scan(contentStream)
                CGPDFContentStreamRelease(contentStream)
            }
            transform = outer
            saved = outerSaved
            depth -= 1
        }
    }
}

extension ReaderPDFView {
    /// "Copy Image" and "Save Image As …" for the picture at a point, as in Safari. Greyed out
    /// where the document does not allow copying.
    func addImageItems(to menu: NSMenu, at location: NSPoint) {
        guard let document, let page = page(for: location, nearest: false),
              let image = PageImages.image(at: convert(location, to: page), on: page)
        else { return }
        let allowed = document.allowsCopying
        if !menu.items.isEmpty { menu.insertItem(.separator(), at: 0) }
        menu.insertItem(ActionMenuItem(String(localized: "Bild sichern unter …"), enabled: allowed) { [weak self] in
            self?.save(image)
        }, at: 0)
        menu.insertItem(ActionMenuItem(String(localized: "Bild kopieren"), enabled: allowed) {
            image.copy()
        }, at: 0)
    }

    /// Asks where to save a picture, named after the document and the page.
    private func save(_ image: PageImage) {
        guard let window, let file = image.fileData() else {
            NSSound.beep()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [file.type]
        let name = (documentName as NSString?)?.deletingPathExtension ?? String(localized: "Bild")
        let label = image.page.label ?? "\((document?.index(for: image.page) ?? 0) + 1)"
        panel.nameFieldStringValue = String(localized: "\(name), Seite \(label)")
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try file.data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).beginSheetModal(for: window)
            }
        }
    }
}
