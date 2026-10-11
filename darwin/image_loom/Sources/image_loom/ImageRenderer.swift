import CoreGraphics
import Foundation
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
        guard
            let src = CGImageSourceCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                opts
            )
        else {
            throw ImageLoomError.message("Cannot open image")
        }
        return src
    }

    static func readInfo(path: String) throws -> Info {
        let src = try makeSource(path)
        guard
            let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil)
                as? [CFString: Any],
            let w = p[kCGImagePropertyPixelWidth] as? Int,
            let h = p[kCGImagePropertyPixelHeight] as? Int
        else {
            throw ImageLoomError.message(
                "Cannot read image properties: \(path)"
            )
        }
        let o = (p[kCGImagePropertyOrientation] as? Int) ?? 1
        return Info(storedW: w, storedH: h, orientation: o)
    }

    /// Maps stored pixel coordinates to upright coordinates.
    static func exifTransform(_ o: Int, w: CGFloat, h: CGFloat)
        -> CGAffineTransform
    {
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

    private static func makeContext(
        width: Int,
        height: Int,
        space: CGColorSpace,
        opaque: Bool
    ) -> CGContext? {
        let alpha =
            opaque
            ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: alpha.rawValue
        )
    }

    static func render(
        path: String,
        outputPath: String,
        affine: [CGFloat],
        outW: Int,
        outH: Int,
        format: String,
        quality: Int
    ) throws -> String {
        guard affine.count == 6 else {
            throw ImageLoomError.message("affine must have 6 values")
        }
        guard outW > 0, outH > 0 else {
            throw ImageLoomError.message("Invalid output size")
        }

        let fmt = format.lowercased()
        let uti: String
        switch fmt {
        case "jpeg", "jpg": uti = "public.jpeg"
        case "png": uti = "public.png"
        case "heic": uti = "public.heic"
        default:
            throw ImageLoomError.message(
                "Output format '\(format)' is not supported on Apple platforms"
            )
        }
        let opaque = (fmt == "jpeg" || fmt == "jpg")

        let info = try readInfo(path: path)
        let sw = CGFloat(info.storedW)
        let sh = CGFloat(info.storedH)

        // stored -> upright (EXIF) -> output (affine from Dart)
        let m = exifTransform(info.orientation, w: sw, h: sh)
            .concatenating(
                CGAffineTransform(
                    a: affine[0],
                    b: affine[1],
                    c: affine[2],
                    d: affine[3],
                    tx: affine[4],
                    ty: affine[5]
                )
            )
        guard abs(m.a * m.d - m.b * m.c) > 1e-12 else {
            throw ImageLoomError.message("Transform is not invertible")
        }

        // Ask the decoder for a smaller image when the output is much smaller
        // than the source. Only JPEG honors this; other formats ignore it.
        let scale = max(hypot(m.a, m.b), hypot(m.c, m.d))
        let factor = subsampleFactor(for: scale)

        // Region of the stored image that the output touches
        let inv = m.inverted()
        let corners = [
            CGPoint(x: 0, y: 0), CGPoint(x: outW, y: 0),
            CGPoint(x: outW, y: outH), CGPoint(x: 0, y: outH),
        ]
        .map { $0.applying(inv) }
        let minX = corners.map { $0.x }.min()!
        let maxX = corners.map { $0.x }.max()!
        let minY = corners.map { $0.y }.min()!
        let maxY = corners.map { $0.y }.max()!
        let margin = CGFloat(2 * factor)
        let padded = CGRect(
            x: floor(minX) - margin,
            y: floor(minY) - margin,
            width: ceil(maxX - minX) + 2 * margin,
            height: ceil(maxY - minY) + 2 * margin
        )
        let clipped = padded.intersection(
            CGRect(x: 0, y: 0, width: sw, height: sh)
        )
        guard !clipped.isNull else {
            throw ImageLoomError.message("Crop is outside the image")
        }
        let region = clipped.integral
        guard region.width > 0, region.height > 0 else {
            throw ImageLoomError.message("Crop is outside the image")
        }

        // Decode. With a subsample factor the decoded image is smaller than the stored size.
        var decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: false
        ]
        if factor > 1 { decodeOptions[kCGImageSourceSubsampleFactor] = factor }

        let src = try makeSource(path)
        guard
            let full = CGImageSourceCreateImageAtIndex(
                src,
                0,
                decodeOptions as CFDictionary
            )
        else {
            throw ImageLoomError.message("Could not decode image: \(path)")
        }

        // Real ratio between decoded and stored pixels. It is 1 when the
        // subsample was ignored, so this is correct for every format.
        let rx = CGFloat(full.width) / sw
        let ry = CGFloat(full.height) / sh

        // The same region, expressed in decoded pixels.
        let pieceRect = CGRect(
            x: region.minX * rx,
            y: region.minY * ry,
            width: region.width * rx,
            height: region.height * ry
        )
        .integral
        .intersection(
            CGRect(x: 0, y: 0, width: full.width, height: full.height)
        )
        guard !pieceRect.isNull, pieceRect.width >= 1, pieceRect.height >= 1,
            let piece = full.cropping(to: pieceRect)
        else {
            throw ImageLoomError.message("Could not crop image")
        }

        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        var space = piece.colorSpace ?? srgb
        if space.model != .rgb { space = srgb }
        guard
            let ctx = makeContext(
                width: outW,
                height: outH,
                space: space,
                opaque: opaque
            )
                ?? makeContext(
                    width: outW,
                    height: outH,
                    space: srgb,
                    opaque: opaque
                )
        else {
            throw ImageLoomError.message("Cannot create drawing context")
        }
        ctx.interpolationQuality = .high

        if opaque {
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
        }

        // piece pixels -> stored pixels (undo the subsample) -> output
        let pieceToStored = CGAffineTransform(
            translationX: pieceRect.minX,
            y: pieceRect.minY
        )
        .concatenating(CGAffineTransform(scaleX: 1 / rx, y: 1 / ry))

        // 1. Switch to a top-left-origin, y-down space (matches the Dart matrix).
        ctx.translateBy(x: 0, y: CGFloat(outH))
        ctx.scaleBy(x: 1, y: -1)
        // 2. piece pixel coords -> stored coords -> output coords.
        ctx.concatenate(pieceToStored.concatenating(m))
        // 3. CGContext.draw expects y-up, so flip the image locally to keep it upright.
        ctx.translateBy(x: 0, y: CGFloat(piece.height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(
            piece,
            in: CGRect(x: 0, y: 0, width: piece.width, height: piece.height)
        )

        guard let outImage = ctx.makeImage() else {
            throw ImageLoomError.message("Render failed")
        }

        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard
            let dest = CGImageDestinationCreateWithURL(
                url as CFURL,
                uti as CFString,
                1,
                nil
            )
        else {
            throw ImageLoomError.message("Format not supported on this device")
        }
        let props =
            [
                kCGImageDestinationLossyCompressionQuality:
                    CGFloat(min(max(quality, 1), 100)) / 100.0
            ] as CFDictionary
        CGImageDestinationAddImage(dest, outImage, props)
        guard CGImageDestinationFinalize(dest) else {
            throw ImageLoomError.message("Encode failed")
        }
        return outputPath
    }

    /// 1, 2, 4 or 8: the largest factor that still keeps at least the output resolution.
    private static func subsampleFactor(for scale: CGFloat) -> Int {
        guard scale > 0 else { return 1 }
        let inverse = Int(floor(1 / scale))
        if inverse >= 8 { return 8 }
        if inverse >= 4 { return 4 }
        if inverse >= 2 { return 2 }
        return 1
    }
}
