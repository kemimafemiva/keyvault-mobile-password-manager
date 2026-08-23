import Flutter
import UIKit

@main
@objc class AppDelegate:
    FlutterAppDelegate,
    FlutterImplicitEngineDelegate {

    private let cryptoChannelHandler = CryptoChannelHandler()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        GeneratedPluginRegistrant.register(
            with: engineBridge.pluginRegistry
        )

        let messenger =
            engineBridge.applicationRegistrar.messenger()

        let cryptoChannel = FlutterMethodChannel(
            name: "com.oluwakemimafe.keyvault/crypto",
            binaryMessenger: messenger
        )

        cryptoChannel.setMethodCallHandler {
            [weak self] call, result in

            guard let self else {
                result(
                    FlutterError(
                        code: "UNAVAILABLE",
                        message: "Crypto handler is unavailable.",
                        details: nil
                    )
                )
                return
            }

            self.cryptoChannelHandler.handle(
                call: call,
                result: result
            )
        }

        let privacyChannel = FlutterMethodChannel(
            name: "com.oluwakemimafe.keyvault/privacy",
            binaryMessenger: messenger
        )

        privacyChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "hidePrivacyOverlay":
                let scenes = UIApplication.shared.connectedScenes

                let sceneDelegate = scenes
                    .compactMap {
                        $0.delegate as? SceneDelegate
                    }
                    .first

                sceneDelegate?.hidePrivacyView()

                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
