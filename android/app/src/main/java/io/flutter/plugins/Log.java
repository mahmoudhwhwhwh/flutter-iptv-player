package io.flutter.plugins;

public class Log {
    public static void e(String tag, String msg, Throwable tr) {
        android.util.Log.e(tag, msg, tr);
    }
}
