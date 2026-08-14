package com.mahmoud.livestreampro

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // تم إزالة FLAG_SECURE للسماح بتصوير الشاشة وتسجيل الفيديو.
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    // تم تعطيل جميع القيود الأمنية لضمان عمل التطبيق على جميع الأجهزة.
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
