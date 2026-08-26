package com.mahmoud.iptv

import android.os.Bundle
import android.view.WindowManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // السماح الصريح بالتقاط الشاشة وتسجيل الفيديو.
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun checkSnifferOrProxy(): Boolean {
        // فحص وجود برامج اقتناص الروابط الشهيرة أو بروكسي محلي
        val knownPackages = arrayOf(
            "app.greyshirts.sslcapture",
            "com.guoshi.httpcanary",
            "com.guoshi.httpcanary.premium",
            "com.charles.proxy",
            "com.packetcapture",
            "com.minhui.networkcapture"
        )
        for (pkg in knownPackages) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                return true
            } catch (e: Exception) {
                // Not found
            }
        }
        return false
    }

    private fun checkVpnActive(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    private fun checkSignature(): Boolean {
        val expected = BuildConfig.EXPECTED_CERT_SHA256
            .replace(":", "")
            .replace(" ", "")
            .lowercase()
        if (expected.isBlank() || expected == "unset") return false
        return try {
            val packageInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }
            val signatures = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners?.toList().orEmpty()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures?.toList().orEmpty()
            }
            signatures.any { signature ->
                val digest = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                digest.joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) } == expected
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun checkRoot(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    val sniffer = checkSnifferOrProxy()
                    val vpn = checkVpnActive()
                    val rooted = checkRoot()
                    val debugger = Debug.isDebuggerConnected()
                    val signatureValid = checkSignature()

                    val shouldBlock = sniffer || debugger || rooted || !signatureValid

                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to sniffer,
                            "vpnActive" to vpn,
                            "proxyActive" to sniffer,
                            "debuggerDetected" to debugger,
                            "compromisedDevice" to rooted,
                            "signatureValid" to signatureValid
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
