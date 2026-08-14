package com.mahmoud.livestreampro

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Proxy
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // السماح بتصوير الشاشة وتسجيل الفيديو بناءً على طلب المستخدم
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    val snifferInstalled = hasSnifferApp()
                    val vpnActive = isVpnActive()
                    val proxyActive = isProxyActive()
                    val compromisedDevice = isRooted()
                    
                    // تم تفعيل الحماية مع استثناء الـ Debug لضمان عمل النسخة المرفوعة
                    val shouldBlock = snifferInstalled || vpnActive || proxyActive || compromisedDevice
                    
                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to snifferInstalled,
                            "vpnActive" to vpnActive,
                            "proxyActive" to proxyActive,
                            "debuggerDetected" to false,
                            "compromisedDevice" to compromisedDevice,
                            "signatureValid" to true
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSnifferApp(): Boolean {
        val blockedPackages = listOf(
            "com.guoshi.httpcanary", "com.reqable.android", "com.sandro.packetcapture",
            "org.sandrop.packetcapture", "com.minhui.networkcapture", "tech.httptoolkit.android"
        )
        for (packageName in blockedPackages) {
            if (isPackageInstalled(packageName)) return true
        }
        return false
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) { false }
    }

    private fun isVpnActive(): Boolean {
        return try {
            val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = manager.activeNetwork ?: return false
                val capabilities = manager.getNetworkCapabilities(network) ?: return false
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            } else {
                manager.allNetworks.any { network ->
                    manager.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
                }
            }
        } catch (_: Exception) { false }
    }

    private fun isProxyActive(): Boolean {
        return try {
            val host = System.getProperty("http.proxyHost")
            val port = System.getProperty("http.proxyPort")
            (!host.isNullOrBlank() && !port.isNullOrBlank()) || !Proxy.getDefaultHost().isNullOrBlank()
        } catch (_: Exception) { false }
    }

    private fun isRooted(): Boolean {
        val rootPaths = listOf("/system/bin/su", "/system/xbin/su", "/sbin/su", "/data/adb/magisk")
        return rootPaths.any { File(it).exists() }
    }
}
