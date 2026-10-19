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
import Testing
import UniformTypeIdentifiers
@testable import Leser

/// Pictures embedded in pages: found where they are drawn, read in their own resolution and
/// with their transparency.
@MainActor
struct PageImageTests {
    /// A picture of 40 × 20 pixels: its left half red and opaque, its right half clear.
    private func halfClear() -> CGImage {
        let context = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        return context.makeImage()!
    }

    /// An opaque blue picture of 30 × 30 pixels, stored as JPEG.
    private func jpeg() -> CGImage {
        let context = CGContext(data: nil, width: 30, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        let source = CGImageSourceCreateWithData(data, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }

    /// One page that draws pictures into rectangles, in this order.
    private func page(_ pictures: [(CGImage, CGRect)]) -> PDFPage {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 400, height: 400)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        for (image, rect) in pictures { context.draw(image, in: rect) }
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)!.page(at: 0)!
    }

    private func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return pixel[3]
    }

    @Test func picturesAreFoundWhereTheyAreDrawn() {
        let page = page([(halfClear(), CGRect(x: 100, y: 200, width: 80, height: 40))])
        let images = PageImages.images(on: page)
        #expect(images.count == 1)
        let bounds = images[0].bounds
        #expect(abs(bounds.minX - 100) < 0.5 && abs(bounds.minY - 200) < 0.5)
        #expect(abs(bounds.width - 80) < 0.5 && abs(bounds.height - 40) < 0.5)
    }

    @Test func pictureKeepsItsResolutionAndTransparency() throws {
        let page = page([(halfClear(), CGRect(x: 100, y: 200, width: 160, height: 80))])
        let found = try #require(PageImages.images(on: page).first)
        #expect(found.hasTransparency)
        let image = try #require(found.image())
        // The pixels of the picture, not its size on the page.
        #expect(image.width == 40 && image.height == 20)
        #expect(alpha(of: image, x: 5, y: 10) > 250)
        #expect(alpha(of: image, x: 35, y: 10) < 5)
        let file = try #require(found.fileData())
        #expect(file.type == .png)
    }

    @Test func clearPartsLetTheClickThrough() {
        // The half-clear picture lies over the blue one.
        let page = page([(jpeg(), CGRect(x: 100, y: 100, width: 100, height: 100)),
                         (halfClear(), CGRect(x: 100, y: 100, width: 100, height: 50))])
        // On its red half the top picture is hit, on its clear half the one below.
        #expect(PageImages.image(at: CGPoint(x: 120, y: 120), on: page)?.hasTransparency == true)
        #expect(PageImages.image(at: CGPoint(x: 180, y: 120), on: page)?.hasTransparency == false)
        // Outside both, nothing.
        #expect(PageImages.image(at: CGPoint(x: 300, y: 300), on: page) == nil)
    }

    @Test func jpegIsSavedAsItIs() throws {
        let page = page([(jpeg(), CGRect(x: 0, y: 0, width: 60, height: 60))])
        let found = try #require(PageImages.images(on: page).first)
        let file = try #require(found.fileData())
        // CoreGraphics may store the picture as JPEG or decoded; a JPEG is handed out unchanged.
        var format = CGPDFDataFormat.raw
        if let stored = CGPDFStreamCopyData(found.stream, &format) as Data?, format == .jpegEncoded {
            #expect(file.type == .jpeg && file.data == stored)
        } else {
            #expect(file.type == .png)
        }
        let image = try #require(found.image())
        #expect(image.width == 30 && image.height == 30)
    }

    @Test func pageWithoutPicturesHasNone() {
        let document = TestPDF(texts: ["Nur Text"]).document()
        #expect(PageImages.images(on: document.page(at: 0)!).isEmpty)
    }
}
