package com.mahmoud.iptv

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Proxy
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // تم السماح بتسجيل الشاشة واللقطات بناءً على طلب المستخدم.
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    val snifferInstalled = hasSnifferOrTamperApp()
                    val vpnActive = isVpnActive()
                    val proxyActive = isProxyActive()
                    val debuggerDetected = isDebuggerOrDebugBuild()
                    val compromisedDevice = isRootedOrHooked()
                    val signatureValid = isReleaseSignatureValid()
                    val shouldBlock = snifferInstalled || vpnActive || proxyActive || debuggerDetected || compromisedDevice || !signatureValid

                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to snifferInstalled,
                            "vpnActive" to vpnActive,
                            "proxyActive" to proxyActive,
                            "debuggerDetected" to debuggerDetected,
                            "compromisedDevice" to compromisedDevice,
                            "signatureValid" to signatureValid
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSnifferOrTamperApp(): Boolean {
        val blockedPackages = listOf(
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
            "com.charlesproxy.android",
            "com.gmail.heagoo.apkeditor",
            "com.gmail.heagoo.apkeditor.pro",
            "bin.mt.plus",
            "com.dimonvideo.luckypatcher",
            "com.chelpus.lackypatch",
            "com.topjohnwu.magisk",
            "eu.chainfire.supersu",
            "de.robv.android.xposed.installer",
            "org.meowcat.edxposed.manager"
        )

        for (packageName in blockedPackages) {
            if (isPackageInstalled(packageName)) return true
        }

        return try {
            val keywords = listOf(
                "reqable", "httpcanary", "packetcapture", "httptoolkit", "charlesproxy", "fiddler",
                "sniffer", "apkeditor", "mt.manager", "luckypatcher", "xposed", "edxposed", "magisk",
                "frida", "substrate", "zygisk"
            )
            packageManager.getInstalledPackages(0).any { info ->
                val packageName = info.packageName.lowercase(Locale.US)
                keywords.any { packageName.contains(it) }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
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
        } catch (_: Exception) {
            false
        }
    }

    private fun isProxyActive(): Boolean {
        return try {
            val host = System.getProperty("http.proxyHost")
            val port = System.getProperty("http.proxyPort")
            (!host.isNullOrBlank() && !port.isNullOrBlank()) || !Proxy.getDefaultHost().isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun isDebuggerOrDebugBuild(): Boolean {
        val debugBuild = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return debugBuild || Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    private fun isRootedOrHooked(): Boolean {
        // كثير من أجهزة TV Box تستخدم test-keys في روم المصنع رغم عدم وجود
        // روت أو أدوات اعتراض؛ لذلك لا نمنعها بهذه العلامة وحدها.
        val rootPaths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su", "/system/app/Superuser.apk",
            "/data/adb/magisk", "/sbin/.magisk", "/system/framework/XposedBridge.jar"
        )
        if (rootPaths.any { File(it).exists() }) return true

        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (_: Throwable) {
            // لا توجد مكتبة Xposed ضمن محمل الأصناف الحالي.
        }

        return try {
            val maps = File("/proc/self/maps")
            if (!maps.canRead()) return false
            val text = maps.readText().lowercase(Locale.US)
            listOf("frida", "xposed", "substrate", "zygisk", "riru", "edxp").any { text.contains(it) }
        } catch (_: Exception) {
            false
        }
    }

    private fun isReleaseSignatureValid(): Boolean {
        val expected = BuildConfig.EXPECTED_CERT_SHA256.trim().uppercase(Locale.US)
        if (expected.isEmpty() || expected == "UNSET") return false

        return try {
            val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = info.signingInfo
                if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners else signingInfo.signingCertificateHistory
            } else {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }
            signatures.any { signature ->
                val digest = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                    .joinToString("") { byte -> "%02X".format(byte.toInt() and 0xFF) }
                digest == expected
            }
        } catch (_: Exception) {
            false
        }
    }
}
