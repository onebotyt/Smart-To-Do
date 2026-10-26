package com.synctask.synctask

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.synctask/widget"
    private val FLOATING_CHANNEL = "com.synctask/floating_panel"
    private val INSTALLER_CHANNEL = "com.synctask/installer"

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
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                            val intent = Intent(this, FloatingBubbleService::class.java)
                            startService(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "hide" -> {
                        val intent = Intent(this, FloatingBubbleService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "isVisible" -> {
                        result.success(FloatingBubbleService.isRunning)
                    }
                    "openAppSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // App Installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri = FileProvider.getUriForFile(
                                context,
                                "$packageName.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing filePath", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
