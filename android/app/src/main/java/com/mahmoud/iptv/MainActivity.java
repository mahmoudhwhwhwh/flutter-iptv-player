package com.mahmoud.iptv;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Bundle;
import android.os.Debug;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.mahmoud.iptv/security";

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Prevent screenshots and screen recording
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("checkSecurity")) {
                        boolean snifferInstalled = hasSnifferOrTamperApp();
                        boolean vpnActive = isVpnActive();
                        boolean proxyActive = isProxyActive();
                        boolean debuggerDetected = isDebuggerOrDebugBuild();
                        boolean compromisedDevice = isRootedOrHooked();
                        boolean signatureValid = isReleaseSignatureValid();

                        // Allow running if signature is UNSET (for debug builds on GitHub)
                        String expected = BuildConfig.EXPECTED_CERT_SHA256;
                        boolean isSignatureIgnored = expected == null || expected.isEmpty() || expected.equals("UNSET");
                        
                        boolean shouldBlock = (snifferInstalled || vpnActive || proxyActive || debuggerDetected || compromisedDevice) 
                                              && !isSignatureIgnored && !signatureValid;

                        Map<String, Object> response = new HashMap<>();
                        response.put("shouldBlock", shouldBlock);
                        response.put("snifferInstalled", snifferInstalled);
                        response.put("vpnActive", vpnActive);
                        response.put("proxyActive", proxyActive);
                        response.put("debuggerDetected", debuggerDetected);
                        response.put("compromisedDevice", compromisedDevice);
                        response.put("signatureValid", signatureValid);

                        result.success(response);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private boolean hasSnifferOrTamperApp() {
        String[] blockedPackages = {
                "com.guoshi.httpcanary", "com.guoshi.httpcanary.premium", "com.guoshi.httpcanary.pro",
                "com.reqable.android", "com.reqable.android.international",
                "com.sandro.packetcapture", "org.sandrop.packetcapture",
                "com.minhui.networkcapture", "com.evozi.networksniffer",
                "tech.httptoolkit.android", "tech.httptoolkit.android.v1",
                "com.charlesproxy.android", "com.gmail.heagoo.apkeditor",
                "com.gmail.heagoo.apkeditor.pro", "bin.mt.plus",
                "com.dimonvideo.luckypatcher", "com.chelpus.lackypatch",
                "com.topjohnwu.magisk", "eu.chainfire.supersu",
                "de.robv.android.xposed.installer", "org.meowcat.edxposed.manager"
        };

        PackageManager pm = getPackageManager();
        for (String pkg : blockedPackages) {
            try {
                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES);
                return true;
            } catch (PackageManager.NameNotFoundException ignored) {}
        }

        try {
            String[] keywords = {
                    "reqable", "httpcanary", "packetcapture", "httptoolkit", "charlesproxy", "fiddler",
                    "sniffer", "apkeditor", "mt.manager", "luckypatcher", "xposed", "edxposed", "magisk",
                    "frida", "substrate", "zygisk"
            };
            List<PackageInfo> packages = pm.getInstalledPackages(0);
            for (PackageInfo info : packages) {
                String pkgName = info.packageName.toLowerCase(Locale.US);
                for (String kw : keywords) {
                    if (pkgName.contains(kw)) return true;
                }
            }
        } catch (Exception ignored) {}

        return false;
    }

    private boolean isVpnActive() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return false;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Network activeNetwork = cm.getActiveNetwork();
                if (activeNetwork == null) return false;
                NetworkCapabilities caps = cm.getNetworkCapabilities(activeNetwork);
                return caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN);
            } else {
                for (Network network : cm.getAllNetworks()) {
                    NetworkCapabilities caps = cm.getNetworkCapabilities(network);
                    if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true;
                }
            }
        } catch (Exception ignored) {}
        return false;
    }

    private boolean isProxyActive() {
        try {
            String host = System.getProperty("http.proxyHost");
            String port = System.getProperty("http.proxyPort");
            return (host != null && !host.isEmpty() && port != null && !port.isEmpty());
        } catch (Exception ignored) {}
        return false;
    }

    private boolean isDebuggerOrDebugBuild() {
        boolean debugBuild = (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        return debugBuild || Debug.isDebuggerConnected() || Debug.waitingForDebugger();
    }

    private boolean isRootedOrHooked() {
        String[] rootPaths = {
                "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su", "/system/app/Superuser.apk",
                "/data/adb/magisk", "/sbin/.magisk", "/system/framework/XposedBridge.jar"
        };
        for (String path : rootPaths) {
            if (new File(path).exists()) return true;
        }

        try {
            Class.forName("de.robv.android.xposed.XposedBridge");
            return true;
        } catch (ClassNotFoundException ignored) {}

        try (BufferedReader br = new BufferedReader(new FileReader("/proc/self/maps"))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.toLowerCase(Locale.US);
                if (line.contains("frida") || line.contains("xposed") || line.contains("substrate") ||
                    line.contains("zygisk") || line.contains("riru") || line.contains("edxp")) return true;
            }
        } catch (Exception ignored) {}

        return false;
    }

    private boolean isReleaseSignatureValid() {
        String expected = BuildConfig.EXPECTED_CERT_SHA256;
        if (expected == null || expected.isEmpty() || expected.equals("UNSET")) return true;
        expected = expected.trim().toUpperCase(Locale.US);

        try {
            PackageManager pm = getPackageManager();
            String pkgName = getPackageName();
            Signature[] signatures;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageInfo info = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNING_CERTIFICATES);
                if (info.signingInfo.hasMultipleSigners()) {
                    signatures = info.signingInfo.getApkContentsSigners();
                } else {
                    signatures = info.signingInfo.getSigningCertificateHistory();
                }
            } else {
                signatures = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES).signatures;
            }

            for (Signature sig : signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                byte[] digest = md.digest(sig.toByteArray());
                StringBuilder sb = new StringBuilder();
                for (byte b : digest) sb.append(String.format("%02X", b & 0xFF));
                if (sb.toString().equals(expected)) return true;
            }
        } catch (Exception ignored) {}
        return false;
    }
}
