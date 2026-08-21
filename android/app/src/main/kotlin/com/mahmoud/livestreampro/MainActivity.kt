package com.mahmoud.livestreampro

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mahmoud.livestreampro/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // تم السماح بتصوير الشاشة وتسجيل الفيديو بناءً على طلب المستخدم في النسخة 2.2.36
        // window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    val snifferInstalled = hasSnifferApp()
                    val vpnActive = isVpnActive()
                    val proxyActive = isProxyActive()
                    val shouldBlock = snifferInstalled || vpnActive || proxyActive
                    
                    result.success(mapOf(
                        "shouldBlock" to shouldBlock,
                        "snifferInstalled" to snifferInstalled,
                        "vpnActive" to vpnActive,
                        "proxyActive" to proxyActive
                    ))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasSnifferApp(): Boolean {
        val pm = packageManager
        val sniffers = listOf(
            "com.guoshi.httpcanary",
            "com.guoshi.httpcanary.premium",
            "com.guoshi.httpcanary.pro",
            "com.reqable.android",
            "com.reqable.android.international",
            "com.sandro.packetcapture",
            "org.sandrop.packetcapture",
            "com.minhui.networkcapture",
            "com.evozi.networksniffer",
            "tech.httptoolkit.android",
            "tech.httptoolkit.android.v1",
            "com.charlesproxy.android"
        )
        
        // 1. الفحص المباشر عبر أسماء الحزم المحددة
        for (pkg in sniffers) {
            try {
                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
                return true
            } catch (e: PackageManager.NameNotFoundException) {
                // Not found
            }
        }
        
        // 2. فحص متقدم لكافة التطبيقات المثبتة بحثاً عن كلمات دلالية لبرامج الالتقاط
        try {
            val keywords = listOf("reqable", "httpcanary", "packetcapture", "httptoolkit", "charlesproxy", "fiddler", "sniffer")
            val packages = pm.getInstalledPackages(0)
            for (info in packages) {
                val pkgName = info.packageName.lowercase()
                for (kw in keywords) {
                    if (pkgName.contains(kw)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        
        return false
    }

    private fun isVpnActive(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeNetwork = cm.activeNetwork ?: return false
                val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return false
                return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            } else {
                val networks = cm.allNetworks
                for (network in networks) {
                    val capabilities = cm.getNetworkCapabilities(network) ?: continue
                    if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun isProxyActive(): Boolean {
        try {
            val proxyAddress = System.getProperty("http.proxyHost")
            val proxyPort = System.getProperty("http.proxyPort")
            if (!proxyAddress.isNullOrEmpty() && !proxyPort.isNullOrEmpty()) {
                return true
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }
}
