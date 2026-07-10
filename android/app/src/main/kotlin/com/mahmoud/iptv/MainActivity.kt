package com.mahmoud.iptv

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mahmoud.iptv/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkSecurity") {
                val shouldBlock = isSnifferAppInstalled()
                result.success(mapOf("shouldBlock" to shouldBlock))
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isSnifferAppInstalled(): Boolean {
        val sniffers = listOf(
            "com.guoshi.httpcanary",
            "com.guoshi.httpcanary.premium",
            "com.reqable.android",
            "com.sandro.packetcapture",
            "org.sandrop.packetcapture",
            "com.minhui.networkcapture",
            "com.evozi.networksniffer"
        )
        val pm = packageManager
        for (pkg in sniffers) {
            try {
                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
                return true
            } catch (e: PackageManager.NameNotFoundException) {
                // Not found
            }
        }
        return false
    }
}
