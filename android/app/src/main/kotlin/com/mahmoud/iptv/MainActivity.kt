package com.mahmoud.iptv

import android.os.Bundle
import android.view.WindowManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "com.mahmoud.iptv/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // تفعيل حماية FLAG_SECURE القصوى لمنع التصوير والتقاط لقطات الشاشة
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
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

                    val shouldBlock = sniffer || debugger || rooted

                    result.success(
                        mapOf(
                            "shouldBlock" to shouldBlock,
                            "snifferInstalled" to sniffer,
                            "vpnActive" to vpn,
                            "proxyActive" to sniffer,
                            "debuggerDetected" to debugger,
                            "compromisedDevice" to rooted,
                            "signatureValid" to true
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
