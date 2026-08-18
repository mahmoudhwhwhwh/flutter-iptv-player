package io.flutter.plugins.urllauncher;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class UrlLauncherPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        result.notImplemented();
    }
}
