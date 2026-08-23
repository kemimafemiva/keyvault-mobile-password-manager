package com.oluwakemimafe.key_vault

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterFragmentActivity() {

    private val cryptoChannelHandler =
        CryptoChannelHandler()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oluwakemimafe.keyvault/crypto"
        )

        channel.setMethodCallHandler { call, result ->
            cryptoChannelHandler.handle(
                call,
                result
            )
        }
    }
}