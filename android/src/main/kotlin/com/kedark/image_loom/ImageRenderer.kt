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
import kotlin.math.max
import kotlin.math.min

internal object ImageRenderer {
    class Info(val storedW: Int, val storedH: Int, val orientation: Int) {
        private val swap = orientation in 5..8
        val uprightW get() = if (swap) storedH else storedW
        val uprightH get() = if (swap) storedW else storedH
    }

    fun readInfo(path: String): Info {
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, o)
        require(o.outWidth > 0 && o.outHeight > 0) { "Cannot decode image bounds" }
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        return Info(o.outWidth, o.outHeight, orientation)
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

        val info = readInfo(path)
        val (a, b, c, d, tx, ty) = affine

        // stored -> upright (EXIF) -> output (affine from Dart)
        val m = exifMatrix(info.orientation, info.storedW.toFloat(), info.storedH.toFloat())
        // Android Matrix.setValues is row-major: [a c tx; b d ty; 0 0 1]
        m.postConcat(Matrix().apply {
            setValues(floatArrayOf(a, c, tx, b, d, ty, 0f, 0f, 1f))
        })

        // Region of the stored image that the output touches
        val inv = Matrix()
        check(m.invert(inv)) { "Non-invertible transform" }
        val pts = floatArrayOf(
            0f, 0f, outW.toFloat(), 0f, outW.toFloat(), outH.toFloat(), 0f, outH.toFloat()
        )
        inv.mapPoints(pts)
        var l = Float.MAX_VALUE; var t = Float.MAX_VALUE
        var r = -Float.MAX_VALUE; var bt = -Float.MAX_VALUE
        for (i in pts.indices step 2) {
            l = min(l, pts[i]); r = max(r, pts[i])
            t = min(t, pts[i + 1]); bt = max(bt, pts[i + 1])
        }
        val region = Rect(
            max(0, floor(l).toInt() - 2),
            max(0, floor(t).toInt() - 2),
            min(info.storedW, ceil(r).toInt() + 2),
            min(info.storedH, ceil(bt).toInt() + 2),
        )
        require(region.width() > 0 && region.height() > 0) { "Crop is outside the image" }

        val regionBmp = decodeRegion(path, region)
        val outBmp = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(outBmp)
            if (fmt == "jpeg" || fmt == "jpg") canvas.drawColor(Color.WHITE)
            // region bitmap coords -> stored coords, then through m
            m.preTranslate(region.left.toFloat(), region.top.toFloat())
            val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
            canvas.drawBitmap(regionBmp, m, paint)

            File(outputPath).parentFile?.mkdirs()
            FileOutputStream(outputPath).use { os ->
                val ok = outBmp.compress(compressFormat(fmt, quality), quality.coerceIn(1, 100), os)
                check(ok) { "Bitmap.compress failed" }
            }
        } finally {
            regionBmp.recycle()
            outBmp.recycle()
        }
        return outputPath
    }

    private fun decodeRegion(path: String, rect: Rect): Bitmap {
        val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        var decoder: BitmapRegionDecoder? = null
        try {
            decoder = openRegionDecoder(path)
            val bmp = decoder?.decodeRegion(rect, opts)
            if (bmp != null) return bmp
        } catch (_: Exception) {
            // some formats (e.g. HEIC/AVIF on certain devices) don't support region decoding
        } finally {
            decoder?.recycle()
        }
        // Fallback: full decode, then cut out the region
        val full = BitmapFactory.decodeFile(path, opts) ?: error("Decode failed")
        return try {
            Bitmap.createBitmap(full, rect.left, rect.top, rect.width(), rect.height())
        } finally {
            full.recycle()
        }
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
                legacyWebp()
            }
        else -> Bitmap.CompressFormat.JPEG
    }

    @Suppress("DEPRECATION")
    private fun legacyWebp() = Bitmap.CompressFormat.WEBP
}

private operator fun <T> List<T>.component6(): T = this[5]
