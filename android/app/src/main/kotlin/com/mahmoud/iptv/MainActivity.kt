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
        // Prevent screenshots and screen recording of subscription credentials
        // and playback. This has no meaningful APK-size impact.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    private fun checkSnifferOrProxy(): Boolean {
        // فحص وجود برامج اقتناص الروابط الشهيرة والهندسة العكسية
        val knownPackages = arrayOf(
            // Reqable & Reqable MAGIC proxy
            "com.reqable.android",
            "com.reqable.android.international",
            "com.reqable.magic",
            "com.reqable.android.magic",
            // Http Canary (Blue, Yellow, Black, Pro, Premium)
            "com.guoshi.httpcanary",
            "com.guoshi.httpcanary.premium",
            "com.guoshi.httpcanary.pro",
            "com.guoshi.httpcanary.blue",
            "com.guoshi.httpcanary.yellow",
            "com.guoshi.httpcanary.black",
            "com.canary.blue",
            "com.canary.yellow",
            "com.canary.black",
            // PCAPdroid & PCAPdroid MITM addon
            "com.emanuelef.remote_capture",
            "com.emanuelef.remote_capture.mitm",
            "com.emanuelef.remote_capture.debug",
            // Other Sniffers & Proxies
            "app.greyshirts.sslcapture",
            "com.charles.proxy",
            "com.charlesproxy.android",
            "com.packetcapture",
            "com.sandro.packetcapture",
            "org.sandrop.packetcapture",
            "com.minhui.networkcapture",
            "com.evozi.networksniffer",
            "tech.httptoolkit.android",
            "tech.httptoolkit.android.v1",
            // Reverse Engineering & Modding Tools
            "bin.mt.plus",
            "com.gmail.heagoo.apkeditor",
            "com.gmail.heagoo.apkeditor.pro",
            "com.dimonvideo.luckypatcher",
            "com.chelpus.lackypatch"
        )
        for (pkg in knownPackages) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                return true
            } catch (e: Exception) {
                // Not found
            }
        }
        // فحص إعدادات البروكسي للنظام (System Proxy Check)
        val httpProxy = System.getProperty("http.proxyHost")
        if (!httpProxy.isNullOrBlank()) return true
        val httpsProxy = System.getProperty("https.proxyHost")
        if (!httpsProxy.isNullOrBlank()) return true
        try {
            val globalProxy = android.provider.Settings.Global.getString(contentResolver, android.provider.Settings.Global.HTTP_PROXY)
            if (!globalProxy.isNullOrBlank()) return true
        } catch (_: Exception) {}
        return false
    }

    private fun checkVpnActive(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
        } catch (_: Exception) {}
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                val name = iface.name.lowercase()
                if (iface.isUp && (name.contains("tun") || name.contains("ppp") || name.contains("pcap") || name.contains("canary") || name.contains("reqable") || name.contains("tap") || name.contains("wg"))) {
                    return true
                }
            }
        } catch (_: Exception) {}
        return false
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

                    // CI/Play signing can legitimately differ from the local
                    // development certificate. Report the result for telemetry,
                    // but do not block an otherwise clean production install.
                    val shouldBlock = sniffer || debugger || rooted

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
