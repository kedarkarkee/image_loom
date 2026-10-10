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
                        val info = ImageRenderer.readInfo(call.argument<String>("path")!!)
                        mapOf("width" to info.uprightW, "height" to info.uprightH)
                    }
                    else -> ImageRenderer.render(
                        path = call.argument<String>("path")!!,
                        outputPath = call.argument<String>("outputPath")!!,
                        affine = call.argument<List<Number>>("affine")!!.map { it.toFloat() },
                        outW = call.argument<Int>("outWidth")!!,
                        outH = call.argument<Int>("outHeight")!!,
                        format = call.argument<String>("format") ?: "jpeg",
                        quality = call.argument<Int>("quality") ?: 92,
                    )
                }
                main.post { result.success(out) }
            } catch (t: Throwable) {
                main.post { result.error("IMAGE_LOOM_FAILED", t.message, null) }
            }
        }
    }
}
