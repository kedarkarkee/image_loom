package com.kedark.image_loom

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import androidx.core.graphics.createBitmap

internal object ImageRenderer {
    class Info(val storedW: Int, val storedH: Int, val orientation: Int) {
        private val swap = orientation in 5..8
        val uprightW get() = if (swap) storedH else storedW
        val uprightH get() = if (swap) storedW else storedH
    }

    /** A decoded piece. Bitmap pixel (px, py) is stored pixel (left + px * scaleX, top + py * scaleY). */
    private class Decoded(
        val bitmap: Bitmap,
        val left: Float,
        val top: Float,
        val scaleX: Float,
        val scaleY: Float,
    )

    fun readInfo(path: String): Info {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Cannot decode image bounds" }
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        return Info(bounds.outWidth, bounds.outHeight, orientation)
    }

    /** Maps stored pixel coords -> upright coords. */
    private fun exifMatrix(o: Int, w: Float, h: Float): Matrix {
        val v = when (o) {
            2 -> floatArrayOf(-1f, 0f, w, 0f, 1f, 0f)
            3 -> floatArrayOf(-1f, 0f, w, 0f, -1f, h)
            4 -> floatArrayOf(1f, 0f, 0f, 0f, -1f, h)
            5 -> floatArrayOf(0f, 1f, 0f, 1f, 0f, 0f)
            6 -> floatArrayOf(0f, -1f, h, 1f, 0f, 0f)
            7 -> floatArrayOf(0f, -1f, h, -1f, 0f, w)
            8 -> floatArrayOf(0f, 1f, 0f, -1f, 0f, w)
            else -> floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f)
        }
        return Matrix().apply {
            setValues(floatArrayOf(v[0], v[1], v[2], v[3], v[4], v[5], 0f, 0f, 1f))
        }
    }

    fun render(
        path: String,
        outputPath: String,
        affine: List<Float>,
        outW: Int,
        outH: Int,
        format: String,
        quality: Int,
    ): String {
        require(affine.size == 6) { "affine must have 6 values" }
        require(outW > 0 && outH > 0) { "Invalid output size" }
        val fmt = format.lowercase()
        require(fmt in setOf("jpeg", "jpg", "png", "webp")) {
            "Output format '$format' is not supported on Android"
        }

        val hasAlpha = fmt == "png" || fmt == "webp"

        val info = readInfo(path)
        val (a, b, c, d, tx, ty) = affine

        // stored -> upright (EXIF) -> output (affine from Dart)
        val m = exifMatrix(info.orientation, info.storedW.toFloat(), info.storedH.toFloat())
        // Android Matrix.setValues is row-major: [a c tx; b d ty; 0 0 1]
        m.postConcat(Matrix().apply {
            setValues(floatArrayOf(a, c, tx, b, d, ty, 0f, 0f, 1f))
        })

        // Decode at reduced resolution when the output is much smaller than the source.
        val v = FloatArray(9).also { m.getValues(it) }
        val scaleX = hypot(v[Matrix.MSCALE_X], v[Matrix.MSKEW_Y])
        val scaleY = hypot(v[Matrix.MSKEW_X], v[Matrix.MSCALE_Y])
        val sample = sampleSizeFor(max(scaleX, scaleY))

        // Region of the stored image that the output canvas touches
        val inv = Matrix()
        check(m.invert(inv)) { "Transform is not invertible" }
        val pts = floatArrayOf(
            0f, 0f, outW.toFloat(), 0f, outW.toFloat(), outH.toFloat(), 0f, outH.toFloat()
        )
        inv.mapPoints(pts)
        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        for (i in pts.indices step 2) {
            minX = min(minX, pts[i]); maxX = max(maxX, pts[i])
            minY = min(minY, pts[i + 1]); maxY = max(maxY, pts[i + 1])
        }
        val margin = 2 * sample
        val region = Rect(
            max(0, floor(minX).toInt() - margin),
            max(0, floor(minY).toInt() - margin),
            min(info.storedW, ceil(maxX).toInt() + margin),
            min(info.storedH, ceil(maxY).toInt() + margin),
        )
        require(region.width() > 0 && region.height() > 0) { "Crop is outside the image" }

        val decoded = decode(path, region, sample)
        val outBmp = createBitmap(outW, outH)
        try {
            val canvas = Canvas(outBmp)
            if (!hasAlpha) canvas.drawColor(Color.WHITE)

            // piece pixels -> stored pixels -> output
            val draw = Matrix(m)

            draw.preTranslate(decoded.left, decoded.top)
            draw.preScale(decoded.scaleX, decoded.scaleY)
            val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
            canvas.drawBitmap(decoded.bitmap, draw, paint)

            val q = quality.coerceIn(1, 100)
            File(outputPath).parentFile?.mkdirs()
            FileOutputStream(outputPath).use { os ->
                val ok = outBmp.compress(compressFormat(fmt, quality), q, os)
                check(ok) { "Bitmap.compress failed" }
            }
        } finally {
            decoded.bitmap.recycle()
            outBmp.recycle()
        }
        return outputPath
    }

    /** Largest power of two such that decoding at 1/n still has at least the output resolution. */
    private fun sampleSizeFor(scale: Float): Int {
        if (scale <= 0f) return 1
        return Integer.highestOneBit(floor(1f / scale).toInt().coerceAtLeast(1))
    }

    private fun decode(path: String, region: Rect, sample: Int): Decoded {
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = sample
        }

        var decoder: BitmapRegionDecoder? = null
        try {
            decoder = openRegionDecoder(path)
            val bitmap = decoder?.decodeRegion(region, options)
            if (bitmap != null) {
                return Decoded(
                    bitmap,
                    region.left.toFloat(),
                    region.top.toFloat(),
                    region.width().toFloat() / bitmap.width,
                    region.height().toFloat() / bitmap.height,
                )
            }
        } catch (_: Exception) {
            // Some formats (for example HEIC on some devices) have no region decoder.
        } finally {
            decoder?.recycle()
        }

        // Fallback: decode the whole image (still subsampled), then cut the piece out.
        val full = BitmapFactory.decodeFile(path, options) ?: error("Could not decode image: $path")
        val l = (region.left / sample).coerceIn(0, full.width - 1)
        val t = (region.top / sample).coerceIn(0, full.height - 1)
        val r = ((region.right + sample - 1) / sample).coerceIn(l + 1, full.width)
        val b = ((region.bottom + sample - 1) / sample).coerceIn(t + 1, full.height)
        val piece = Bitmap.createBitmap(full, l, t, r - l, b - t)
        if (piece !== full) full.recycle()
        return Decoded(
            piece,
            (l * sample).toFloat(),
            (t * sample).toFloat(),
            sample.toFloat(),
            sample.toFloat()
        )
    }

    private fun openRegionDecoder(path: String): BitmapRegionDecoder? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            BitmapRegionDecoder.newInstance(path)
        } else {
            @Suppress("DEPRECATION")
            BitmapRegionDecoder.newInstance(path, false)
        }

    private fun compressFormat(fmt: String, quality: Int): Bitmap.CompressFormat = when (fmt) {
        "png" -> Bitmap.CompressFormat.PNG
        "webp" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (quality >= 100) Bitmap.CompressFormat.WEBP_LOSSLESS
                else Bitmap.CompressFormat.WEBP_LOSSY
            } else {
                Bitmap.CompressFormat.WEBP
            }

        else -> Bitmap.CompressFormat.JPEG
    }
}

private operator fun <T> List<T>.component6(): T = this[5]
