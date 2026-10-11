package com.kedark.image_loom

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class ImageLoomPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "image_loom")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getImageSize" && call.method != "render") {
            result.notImplemented()
            return
        }
        executor.execute {
            try {
                val out: Any = when (call.method) {
                    "getImageSize" -> {
                        val info = ImageRenderer.readInfo(call.require("path"))
                        mapOf("width" to info.uprightW, "height" to info.uprightH)
                    }

                    else -> ImageRenderer.render(
                        path = call.require("path"),
                        outputPath = call.require("outputPath"),
                        affine = call.require<List<*>>("affine").map { (it as Number).toFloat() },
                        outW = call.require<Number>("outWidth").toInt(),
                        outH = call.require<Number>("outHeight").toInt(),
                        format = call.argument<String>("format") ?: "jpeg",
                        quality = call.argument<Number>("quality")?.toInt() ?: 92,
                    )
                }
                main.post { result.success(out) }
            } catch (t: Throwable) {
                main.post { result.error("IMAGE_LOOM_FAILED", t.message, null) }
            }
        }
    }

    private fun <T> MethodCall.require(key: String): T =
        argument<T>(key) ?: throw IllegalArgumentException("Missing argument: $key")
}
