package io.flutter;

public class Log {
    public static void d(String tag, String message) {
        android.util.Log.d(tag, message);
    }
    public static void i(String tag, String message) {
        android.util.Log.i(tag, message);
    }
    public static void w(String tag, String message) {
        android.util.Log.w(tag, message);
    }
    public static void e(String tag, String message) {
        android.util.Log.e(tag, message);
    }
    public static void e(String tag, String message, Throwable tr) {
        android.util.Log.e(tag, message, tr);
    }
}
