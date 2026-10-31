import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum BoothMapImporter {
    static let maxPixelSize = 3000
    static let boothImagePixelSize = 1600
    static let jpegQuality = 0.85

    static func makeMap(from data: Data) throws -> BoothMap {
        guard let image = decode(data, maxPixelSize: maxPixelSize), let jpeg = encodeJPEG(image) else {
            throw HostError.invalidImage
        }
        return BoothMap(jpeg: jpeg)
    }

    static func makeBoothImage(from data: Data) throws -> BoothImage {
        guard let image = decode(data, maxPixelSize: boothImagePixelSize), let jpeg = encodeJPEG(image) else {
            throw HostError.invalidImage
        }
        return BoothImage(jpeg: jpeg)
    }

    static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize, max(width, height))
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encodeJPEG(_ image: CGImage) -> Data? {
        guard let flat = flattenedOnWhite(image) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, flat, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private static func flattenedOnWhite(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }
}
