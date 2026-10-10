import Foundation
import CoreGraphics
import ImageIO

enum ImageLoomError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let m) = self { return m }
        return nil
    }
}

enum ImageRenderer {
    struct Info {
        let storedW: Int
        let storedH: Int
        let orientation: Int
        var swap: Bool { orientation >= 5 && orientation <= 8 }
        var uprightW: Int { swap ? storedH : storedW }
        var uprightH: Int { swap ? storedW : storedH }
    }

    static func makeSource(_ path: String) throws -> CGImageSource {
        let opts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, opts) else {
            throw ImageLoomError.message("Cannot open image")
        }
        return src
    }

    static func readInfo(path: String) throws -> Info {
        let src = try makeSource(path)
        guard let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int,
              let h = p[kCGImagePropertyPixelHeight] as? Int else {
            throw ImageLoomError.message("Cannot read image properties")
        }
        let o = (p[kCGImagePropertyOrientation] as? Int) ?? 1
        return Info(storedW: w, storedH: h, orientation: o)
    }

    /// Maps stored pixel coords -> upright coords.
    static func exifTransform(_ o: Int, w: CGFloat, h: CGFloat) -> CGAffineTransform {
        switch o {
        case 2: return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)
        case 3: return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        case 4: return CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
        case 5: return CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case 6: return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        case 7: return CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: h, ty: w)
        case 8: return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        default: return .identity
        }
    }

    private static func makeContext(width: Int, height: Int, space: CGColorSpace,
                                    opaque: Bool) -> CGContext? {
        let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                         bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue)
    }

    static func render(path: String, outputPath: String, affine: [CGFloat],
                       outW: Int, outH: Int, format: String, quality: Int) throws -> String {
        guard affine.count == 6 else { throw ImageLoomError.message("affine must have 6 values") }
        guard outW > 0, outH > 0 else { throw ImageLoomError.message("Invalid output size") }

        let fmt = format.lowercased()
        let uti: String
        switch fmt {
        case "jpeg", "jpg": uti = "public.jpeg"
        case "png": uti = "public.png"
        case "heic": uti = "public.heic"
        default: throw ImageLoomError.message("Output format '\(format)' is not supported on Apple platforms")
        }
        let opaque = (fmt == "jpeg" || fmt == "jpg")

        let info = try readInfo(path: path)
        let sw = CGFloat(info.storedW), sh = CGFloat(info.storedH)

        // stored -> upright (EXIF) -> output (affine from Dart)
        let m = exifTransform(info.orientation, w: sw, h: sh)
            .concatenating(CGAffineTransform(a: affine[0], b: affine[1], c: affine[2],
                                             d: affine[3], tx: affine[4], ty: affine[5]))
        guard abs(m.a * m.d - m.b * m.c) > 1e-12 else {
            throw ImageLoomError.message("Non-invertible transform")
        }

        // Region of the stored image that the output touches
        let inv = m.inverted()
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: outW, y: 0),
                       CGPoint(x: outW, y: outH), CGPoint(x: 0, y: outH)]
            .map { $0.applying(inv) }
        let minX = corners.map { $0.x }.min()!, maxX = corners.map { $0.x }.max()!
        let minY = corners.map { $0.y }.min()!, maxY = corners.map { $0.y }.max()!
        let padded = CGRect(x: floor(minX) - 2, y: floor(minY) - 2,
                            width: ceil(maxX - minX) + 4, height: ceil(maxY - minY) + 4)
        let clipped = padded.intersection(CGRect(x: 0, y: 0, width: sw, height: sh))
        guard !clipped.isNull else { throw ImageLoomError.message("Crop is outside the image") }
        let region = clipped.integral
        guard region.width > 0, region.height > 0 else {
            throw ImageLoomError.message("Crop is outside the image")
        }

        let src = try makeSource(path)
        guard let full = CGImageSourceCreateImageAtIndex(
                src, 0, [kCGImageSourceShouldCacheImmediately: false] as CFDictionary),
              let piece = full.cropping(to: region) else {
            throw ImageLoomError.message("Decode failed")
        }

        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        var space = piece.colorSpace ?? srgb
        if space.model != .rgb { space = srgb }
        guard let ctx = makeContext(width: outW, height: outH, space: space, opaque: opaque)
                ?? makeContext(width: outW, height: outH, space: srgb, opaque: opaque) else {
            throw ImageLoomError.message("Cannot create context")
        }
        ctx.interpolationQuality = .high

        if opaque {
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
        }

        // 1. Switch to a top-left-origin, y-down space (matches the Dart matrix).
        ctx.translateBy(x: 0, y: CGFloat(outH))
        ctx.scaleBy(x: 1, y: -1)
        // 2. region pixel coords -> stored coords -> output coords.
        ctx.concatenate(CGAffineTransform(translationX: region.minX, y: region.minY)
            .concatenating(m))
        // 3. CGContext.draw expects y-up, so flip the image locally to keep it upright.
        ctx.translateBy(x: 0, y: region.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(piece, in: CGRect(x: 0, y: 0, width: region.width, height: region.height))

        guard let outImage = ctx.makeImage() else {
            throw ImageLoomError.message("Render failed")
        }

        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, 1, nil) else {
            throw ImageLoomError.message("Format not supported on this device")
        }
        let props = [kCGImageDestinationLossyCompressionQuality:
                        CGFloat(min(max(quality, 1), 100)) / 100.0] as CFDictionary
        CGImageDestinationAddImage(dest, outImage, props)
        guard CGImageDestinationFinalize(dest) else {
            throw ImageLoomError.message("Encode failed")
        }
        return outputPath
    }
}
