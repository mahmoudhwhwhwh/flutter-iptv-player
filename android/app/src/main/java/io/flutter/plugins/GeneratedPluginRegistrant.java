package io.flutter.plugins;

import androidx.annotation.Keep;
import io.flutter.embedding.engine.FlutterEngine;

@Keep
public final class GeneratedPluginRegistrant {
    public static void registerWith(FlutterEngine flutterEngine) {
        try {
            flutterEngine.getPlugins().add(new io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin());
        } catch (Exception ignored) {}
        try {
            flutterEngine.getPlugins().add(new dev.fluttercommunity.plus.deviceinfo.DeviceInfoPlusPlugin());
        } catch (Exception ignored) {}
        try {
            flutterEngine.getPlugins().add(new dev.fluttercommunity.plus.sensors.SensorsPlusPlugin());
        } catch (Exception ignored) {}
        try {
            flutterEngine.getPlugins().add(new io.flutter.plugins.urllauncher.UrlLauncherPlugin());
        } catch (Exception ignored) {}
        try {
            flutterEngine.getPlugins().add(new com.baseflow.pathprovider.PathProviderPlugin());
        } catch (Exception ignored) {}
    }
}
