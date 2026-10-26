package com.synctask.synctask

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.synctask/widget"
    private val FLOATING_CHANNEL = "com.synctask/floating_panel"

    private var isOverlayVisible = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val pendingCount = call.argument<Int>("pendingCount") ?: 0
                    val topTasks = call.argument<List<String>>("topTasks") ?: emptyList()
                    SyncTaskWidgetProvider.updateAllWidgets(context, pendingCount, topTasks)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        // Floating Panel / Overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(this))
                        } else {
                            result.success(true)
                        }
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.canDrawOverlays(this)) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    }
                    "show" -> {
                        isOverlayVisible = true
                        result.success(true)
                    }
                    "hide" -> {
                        isOverlayVisible = false
                        result.success(true)
                    }
                    "isVisible" -> {
                        result.success(isOverlayVisible)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
