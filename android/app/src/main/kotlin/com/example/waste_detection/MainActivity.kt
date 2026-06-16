package com.example.waste_detection

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Debug

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.waste_detection/memory"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryUsage") {
                val memoryInfo = Debug.MemoryInfo()
                Debug.getMemoryInfo(memoryInfo)
                val totalPssKb = memoryInfo.totalPss // In KB
                val totalPssMb = totalPssKb / 1024
                result.success(totalPssMb)
            } else {
                result.notImplemented()
            }
        }
    }
}
