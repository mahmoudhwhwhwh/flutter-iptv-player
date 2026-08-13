package com.mahmoud.iptv

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.mahmoud.iptv/security"

    private val blockedPackages = setOf(
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
        "com.pcapdroid",
        "com.farproc.wifi.analyzer",
        "com.gmail.heagoo.apkeditor",
        "com.gmail.heagoo.apkeditor.pro",
        "bin.mt.plus",
        "com.dimonvideo.luckypatcher",
        "com.topjohnwu.magisk",
        "org.lsposed.manager",
        "de.robv.android.xposed.installer"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // منع لقطات الشاشة والتسجيل من واجهات النظام.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    val snifferInstalled = hasBlockedPackage()
                    val vpnActive = isVpnActive()
                    val proxyActive = isProxyActive()
                    val rootDetected = isRooted()
                    val debugDetected = isDebugOrTraced()
                    val emulatorDetected = isEmulator()
                    val tamperDetected = hasUnexpectedSigningCertificate()
                    val shouldBlock = snifferInstalled || vpnActive || proxyActive || rootDetected || debugDetected || emulatorDetected || tamperDetected

                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to snifferInstalled,
                            "vpnActive" to vpnActive,
                            "proxyActive" to proxyActive,
                            "rootDetected" to rootDetected,
                            "debugDetected" to debugDetected,
                            "emulatorDetected" to emulatorDetected,
                            "tamperDetected" to tamperDetected
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasBlockedPackage(): Boolean {
        for (packageName in blockedPackages) {
            try {
                packageManager.getApplicationInfo(packageName, 0)
                return true
            } catch (_: PackageManager.NameNotFoundException) {
                // التطبيق غير مثبت.
            } catch (_: Exception) {
                // لا تحول خطأ مدير الحزم إلى سماح أو حظر وحده.
            }
        }
        return false
    }

    private fun isVpnActive(): Boolean {
        return try {
            val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            val activeNetwork = manager.activeNetwork ?: return false
            val capabilities = manager.getNetworkCapabilities(activeNetwork) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } catch (_: Exception) {
            false
        }
    }

    private fun isProxyActive(): Boolean {
        return try {
            val host = System.getProperty("http.proxyHost")
            val port = System.getProperty("http.proxyPort")
            !host.isNullOrBlank() && !port.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun isRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) return true
        val rootPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/debug_ramdisk/.magisk"
        )
        return rootPaths.any { File(it).exists() }
    }

    private fun isDebugOrTraced(): Boolean {
        if (BuildConfig.DEBUG || Debug.isDebuggerConnected() || Debug.waitingForDebugger()) return true
        return try {
            File("/proc/self/status").useLines { lines ->
                lines.any { line ->
                    line.startsWith("TracerPid:") && line.substringAfter(':').trim().toIntOrNull()?.let { it > 0 } == true
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val product = Build.PRODUCT.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        return fingerprint.startsWith("generic") ||
            fingerprint.contains("emulator") ||
            model.contains("google_sdk") ||
            model.contains("emulator") ||
            product.contains("sdk") ||
            product.contains("emulator") ||
            manufacturer.contains("genymotion")
    }

    private fun hasUnexpectedSigningCertificate(): Boolean {
        // فحص التوقيع لا يُفرض على بناء debug المحلي؛ يُفرض دائماً على إصدار release.
        if (BuildConfig.DEBUG) return false
        val expected = BuildConfig.EXPECTED_CERT_SHA256.replace(":", "").lowercase()
        if (expected.isBlank() || expected == "unset") return true
        return try {
            !currentSigningCertificates().any { it.equals(expected, ignoreCase = true) }
        } catch (_: Exception) {
            true
        }
    }

    @Suppress("DEPRECATION")
    private fun currentSigningCertificates(): List<String> {
        val packageInfo: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners ?: emptyArray()
        } else {
            packageInfo.signatures ?: emptyArray()
        }
        return signatures.map { signature -> sha256(signature.toByteArray()) }
    }

    private fun sha256(input: ByteArray): String {
        return MessageDigest.getInstance("SHA-256").digest(input).joinToString("") { byte -> "%02x".format(byte) }
    }
}
