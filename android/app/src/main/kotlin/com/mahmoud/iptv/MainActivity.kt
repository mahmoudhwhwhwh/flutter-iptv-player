package com.mahmoud.iptv

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.NetworkInterface
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // إعادة تفعيل حماية الشاشة السوداء لمنع التصوير والسرقة (أقوى حماية)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkSecurity") {
                val securityInfo = mutableMapOf<String, Any>()
                
                val isRooted = checkRootMethod1() || checkRootMethod2() || checkRootMethod3()
                val isVpnActive = isVpnConnectionActive()
                val isProxyActive = isProxyActive()
                val isSnifferDetected = isSnifferAppInstalled() || isDebuggerAttached()

                securityInfo["shouldBlock"] = isRooted || isSnifferDetected
                securityInfo["vpnActive"] = isVpnActive
                securityInfo["proxyActive"] = isProxyActive
                securityInfo["isRooted"] = isRooted
                securityInfo["snifferInstalled"] = isSnifferDetected
                
                result.success(securityInfo)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun checkRootMethod1(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su",
            "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        return false
    }

    private fun checkRootMethod2(): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val `in` = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            `in`.readLine() != null
        } catch (t: Throwable) {
            false
        } finally {
            process?.destroy()
        }
    }

    private fun checkRootMethod3(): Boolean {
        val buildTags = android.os.Build.TAGS
        return buildTags != null && buildTags.contains("test-keys")
    }

    private fun isVpnConnectionActive(): Boolean {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val name = networkInterface.name.lowercase(Locale.getDefault())
                if (name.contains("tun") || name.contains("ppp") || name.contains("pptp") || 
                    name.contains("l2tp") || name.contains("ipsec") || name.contains("vpn")) {
                    return true
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun isProxyActive(): Boolean {
        val proxyAddress = System.getProperty("http.proxyHost")
        val proxyPort = System.getProperty("http.proxyPort")
        return !proxyAddress.isNullOrEmpty() && !proxyPort.isNullOrEmpty()
    }

    private fun isSnifferAppInstalled(): Boolean {
        val snifferPackages = arrayOf(
            "com.guoshi.httpcanary", "com.guoshi.httpcanary.premium",
            "com.charles.proxy", "org.proxydroid", "com.minhui.networkcapture",
            "com.evbadrit.networklog", "com.adguard.android", "com.reqable.android"
        )
        val pm = packageManager
        for (pkg in snifferPackages) {
            try {
                pm.getPackageInfo(pkg, 0)
                return true
            } catch (e: Exception) { }
        }
        return false
    }

    private fun isDebuggerAttached(): Boolean {
        return android.os.Debug.isDebuggerConnected()
    }
}
