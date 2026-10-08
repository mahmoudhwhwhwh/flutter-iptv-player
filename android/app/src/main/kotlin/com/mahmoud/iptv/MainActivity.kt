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
        // Prevent screenshots, screen recording, and external capture
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
            "it.emanuelef.remote_capture",
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
            "com.vproxy.app",
            "org.proxydroid",
            // Reverse Engineering & Modding Tools
            "bin.mt.plus",
            "com.gmail.heagoo.apkeditor",
            "com.gmail.heagoo.apkeditor.pro",
            "com.dimonvideo.luckypatcher",
            "com.chelpus.lackypatch",
            "de.robv.android.xposed.installer",
            "org.meowcat.edxposed.manager"
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
        if (!httpProxy.isNullOrBlank() && httpProxy != "0.0.0.0" && httpProxy != "localhost") return true
        val httpsProxy = System.getProperty("https.proxyHost")
        if (!httpsProxy.isNullOrBlank() && httpsProxy != "0.0.0.0" && httpsProxy != "localhost") return true
        try {
            val globalProxy = android.provider.Settings.Global.getString(contentResolver, android.provider.Settings.Global.HTTP_PROXY)
            if (!globalProxy.isNullOrBlank() && globalProxy != ":0" && globalProxy.contains(":")) return true
        } catch (_: Exception) {}

        return false
    }

    private fun checkVpnActive(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return true
            }
        } catch (_: Exception) {}
        return false
    }

    private fun checkFrida(): Boolean {
        try {
            val fridaPaths = arrayOf(
                "/data/local/tmp/frida-server",
                "/data/local/tmp/re.frida.server",
                "/data/local/tmp/frida64",
                "/data/local/tmp/frida32",
                "/data/local/tmp/frida-gadget.so"
            )
            for (p in fridaPaths) {
                if (File(p).exists()) return true
            }
        } catch (_: Exception) {}

        try {
            val mapsFile = File("/proc/self/maps")
            if (mapsFile.exists()) {
                val content = mapsFile.readText()
                if (content.contains("frida-server", ignoreCase = true) ||
                    content.contains("frida-agent", ignoreCase = true) ||
                    content.contains("frida-gadget", ignoreCase = true) ||
                    content.contains("libfrida", ignoreCase = true) ||
                    content.contains("xposed.installer", ignoreCase = true) ||
                    content.contains("edxposed", ignoreCase = true)) {
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
            val f = File(path)
            if (f.exists() && f.canExecute()) return true
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
                    val frida = checkFrida()

                    // Strict black screen trigger: ONLY when malicious sniffer/proxy, debugger, or frida injection is detected
                    val shouldBlock = sniffer || debugger || frida

                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to sniffer,
                            "vpnActive" to vpn,
                            "proxyActive" to sniffer,
                            "debuggerDetected" to debugger,
                            "compromisedDevice" to frida,
                            "signatureValid" to signatureValid
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
