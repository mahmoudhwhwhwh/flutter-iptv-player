package com.mahmoud.iptv

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // السماح بتسجيل الشاشة وعدم حظر أي لقطات
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    // إلغاء أي حظر أمني تماماً لضمان فتح التطبيق بسلاسة تامة بدون شاشة سوداء
                    result.success(
                        mapOf(
                            "shouldBlock" to false,
                            "snifferInstalled" to false,
                            "vpnActive" to false,
                            "proxyActive" to false,
                            "debuggerDetected" to false,
                            "compromisedDevice" to false,
                            "signatureValid" to true
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
