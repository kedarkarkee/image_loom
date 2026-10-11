import Foundation

#if os(iOS)
    import Flutter
#elseif os(macOS)
    import FlutterMacOS
#endif

public class ImageLoomPlugin: NSObject, FlutterPlugin {
    private let queue = DispatchQueue(
        label: "image_loom.work",
        qos: .userInitiated,
        attributes: .concurrent
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
            let messenger = registrar.messenger()
        #else
            let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(
            name: "image_loom",
            binaryMessenger: messenger
        )
        registrar.addMethodCallDelegate(ImageLoomPlugin(), channel: channel)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard call.method == "getImageSize" || call.method == "render" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String
        else {
            result(
                FlutterError(
                    code: "BAD_ARGS",
                    message: "Missing path",
                    details: nil
                )
            )
            return
        }

        queue.async {
            do {
                if call.method == "getImageSize" {
                    let info = try ImageRenderer.readInfo(path: path)
                    let out: [String: Int] = [
                        "width": info.uprightW, "height": info.uprightH,
                    ]
                    DispatchQueue.main.async { result(out) }
                    return
                }

                guard let outputPath = args["outputPath"] as? String,
                    let affineRaw = args["affine"] as? [NSNumber],
                    affineRaw.count == 6,
                    let outW = (args["outWidth"] as? NSNumber)?.intValue,
                    let outH = (args["outHeight"] as? NSNumber)?.intValue
                else {
                    throw ImageLoomError.message("Invalid render arguments")
                }
                let out = try ImageRenderer.render(
                    path: path,
                    outputPath: outputPath,
                    affine: affineRaw.map { CGFloat($0.doubleValue) },
                    outW: outW,
                    outH: outH,
                    format: (args["format"] as? String) ?? "jpeg",
                    quality: (args["quality"] as? NSNumber)?.intValue ?? 92
                )
                DispatchQueue.main.async { result(out) }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "IMAGE_LOOM_FAILED",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }
}
