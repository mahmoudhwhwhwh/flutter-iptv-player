package com.mahmoud.iptv;

import android.os.Bundle;
import android.view.WindowManager;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Explicitly clear FLAG_SECURE to allow screen recording and screenshots
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
    }
}
