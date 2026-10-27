package com.synctask.synctask

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import java.util.Locale

import java.io.File

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.synctask/widget"
    private val FLOATING_CHANNEL = "com.synctask/floating_panel"
    private val INSTALLER_CHANNEL = "com.synctask/installer"
    private val SETTINGS_CHANNEL = "com.synctask/native_settings"
    private val MEDIA_CHANNEL = "com.synctask/media_share"
    private val VOICE_CHANNEL = "com.synctask/voice"
    private val SPEECH_REQUEST_CODE = 4389
    private var tts: TextToSpeech? = null
    private var isTtsInitialized = false
    private var pendingVoiceResult: MethodChannel.Result? = null


    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra("open_create_task", false) == true) {
            pendingAction = "create_task"
        }
        try {
            tts = TextToSpeech(applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    isTtsInitialized = true
                    try {
                        tts?.language = Locale.US
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("open_create_task", false)) {
            pendingAction = "create_task"
        }
        try {
            tts = TextToSpeech(applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    isTtsInitialized = true
                    try {
                        tts?.language = Locale.US
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Acquire Wi-Fi MulticastLock so Android receives UDP discovery packets
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("SyncTaskMulticastLock")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (_: Exception) {}

        // Native Network Settings Channel (Bluetooth, Wi-Fi, Hotspot)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBluetoothEnabled" -> {
                        try {
                            val btAdapter = BluetoothAdapter.getDefaultAdapter()
                            result.success(btAdapter?.isEnabled == true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openBluetoothSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "openWifiSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "openHotspotSettings" -> {
                        try {
                            val intent = Intent().apply {
                                action = "android.settings.TETHER_SETTINGS"
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("FAILED", e2.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

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
                    "notifyTasksChanged" -> {
                        FloatingBubbleService.notifyTasksChanged()
                        result.success(true)
                    }
                    "checkPendingAction" -> {
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
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

        // Native Media Sharing & Clipboard Image Channel
        
        // Native Voice Synthesis and Speech Recognition Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        if (text.isNotEmpty() && isTtsInitialized) {
                            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "sky_voice_${System.currentTimeMillis()}")
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    "startListening" -> {
                        try {
                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                                putExtra(RecognizerIntent.EXTRA_PROMPT, "Ask Sky AI anything...")
                            }
                            pendingVoiceResult = result
                            startActivityForResult(intent, SPEECH_REQUEST_CODE)
                        } catch (e: Exception) {
                            result.success("")
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        if (filePath != null) {
                            try {
                                val file = File(filePath)
                                if (!file.exists()) {
                                    result.error("NOT_FOUND", "File does not exist: $filePath", null)
                                    return@setMethodCallHandler
                                }
                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "$packageName.fileprovider",
                                    file
                                )
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = mimeType
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                val chooser = Intent.createChooser(shareIntent, "Share with").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(chooser)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SHARE_FAILED", e.message, null)
                            }
                        } else {
                            result.error("BAD_ARGS", "Missing filePath", null)
                        }
                    }
                    "getClipboardImage" -> {
                        try {
                            val clipManager = getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
                            val clip = clipManager?.primaryClip
                            if (clip != null && clip.itemCount > 0) {
                                val item = clip.getItemAt(0)
                                val uri = item.uri
                                if (uri != null) {
                                    val resolver = contentResolver
                                    val type = resolver.getType(uri) ?: "image/png"
                                    if (type.startsWith("image/")) {
                                        val ext = if (type.contains("jpeg") || type.contains("jpg")) ".jpg" else ".png"
                                        val tempFile = File(cacheDir, "clipboard_screenshot_${System.currentTimeMillis()}$ext")
                                        resolver.openInputStream(uri)?.use { input ->
                                            tempFile.outputStream().use { output ->
                                                input.copyTo(output)
                                            }
                                        }
                                        result.success(tempFile.absolutePath)
                                        return@setMethodCallHandler
                                    }
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SPEECH_REQUEST_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = matches?.firstOrNull() ?: ""
                pendingVoiceResult?.success(spokenText)
            } else {
                pendingVoiceResult?.success("")
            }
            pendingVoiceResult = null
        }
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
