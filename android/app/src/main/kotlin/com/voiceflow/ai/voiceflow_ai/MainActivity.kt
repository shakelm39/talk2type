package com.voiceflow.ai.voiceflow_ai

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.voiceflow.ai.voiceflow_ai.services.AudioRecorderHelper
import com.voiceflow.ai.voiceflow_ai.services.AutoTypeAccessibilityService
import com.voiceflow.ai.voiceflow_ai.services.FloatingOverlayService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_NAME = "com.voiceflow.ai/native_bridge"
        private const val REQUEST_RECORD_AUDIO = 101
        private const val TAG = "Talk2TypeMainActivity"
        private var methodChannel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        fun notifyAudioRecorded(audioPath: String, mode: String) {
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "onAudioRecorded",
                    mapOf("path" to audioPath, "mode" to mode)
                )
            }
        }

        fun notifyTranscriptionCompleted(text: String, mode: String) {
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "onTranscriptionCompleted",
                    mapOf("text" to text, "mode" to mode)
                )
            }
        }
    }

    private var inlineRecorder: AudioRecorderHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startInlineRecording" -> {
                    if (inlineRecorder == null) {
                        inlineRecorder = AudioRecorderHelper(applicationContext)
                    }
                    val path = inlineRecorder?.startRecording()
                    result.success(path)
                }
                "stopInlineRecording" -> {
                    val path = inlineRecorder?.stopRecording()
                    inlineRecorder = null
                    result.success(path)
                }
                "checkMicrophonePermission" -> {
                    result.success(checkMicrophonePermission())
                }
                "requestMicrophonePermission" -> {
                    val ok = requestMicrophonePermission()
                    result.success(ok)
                }
                "checkOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    val ok = requestOverlayPermission()
                    result.success(ok)
                }
                "checkAccessibilityPermission" -> {
                    result.success(checkAccessibilityPermission())
                }
                "requestAccessibilityPermission" -> {
                    val ok = requestAccessibilityPermission()
                    result.success(ok)
                }
                "startOverlayService", "startFloatingService" -> {
                    val started = startFloatingOverlayService()
                    result.success(started)
                }
                "stopOverlayService", "stopFloatingService" -> {
                    stopFloatingOverlayService()
                    result.success(true)
                }
                "isFloatingServiceRunning" -> {
                    result.success(FloatingOverlayService.isRunning)
                }
                "testTextInjection", "injectText" -> {
                    val text = call.argument<String>("text") ?: "Talk2Type AutoType Test"
                    FloatingOverlayService.setLastTranscribed(text)
                    val success = AutoTypeAccessibilityService.injectTextToFocusedField(applicationContext, text)
                    result.success(success)
                }
                "setActiveMode", "updateToneMode" -> {
                    val mode = call.argument<String>("mode") ?: "sundor"
                    FloatingOverlayService.updateMode(mode)
                    result.success(true)
                }
                "setOverlayState" -> {
                    val state = call.argument<String>("state") ?: "idle"
                    FloatingOverlayService.updateState(state)
                    result.success(true)
                }
                "setOverlayEngineStatus" -> {
                    val engine = call.argument<String>("engine") ?: "Active"
                    FloatingOverlayService.updateEngineStatus(engine)
                    result.success(true)
                }
                "setOverlayError" -> {
                    val msg = call.argument<String>("message") ?: "এআই প্রসেসিং ব্যর্থ হয়েছে।"
                    FloatingOverlayService.showError(msg)
                    result.success(true)
                }
                "checkBatteryOptimization" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnored = pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                    result.success(isIgnored)
                }
                "requestBatteryOptimization" -> {
                    val ok = requestBatteryOptimization()
                    result.success(ok)
                }
                "openAppDetailsSettings" -> {
                    openAppDetailsSettings()
                    result.success(true)
                }
                "updateOrbAppearance" -> {
                    val sizeDp = call.argument<Int>("sizeDp") ?: 48
                    val opacity = (call.argument<Double>("opacity") ?: 0.65).toFloat()
                    FloatingOverlayService.updateAppearance(sizeDp, opacity)
                    result.success(true)
                }
                "getDeviceId" -> {
                    result.success(getAppDeviceId())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    private fun checkMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestMicrophonePermission(): Boolean {
        try {
            if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    REQUEST_RECORD_AUDIO
                )
                return true
            } else {
                openAppDetailsSettings()
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "requestMicrophonePermission failed: ${e.message}")
            openAppDetailsSettings()
            return false
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return Settings.canDrawOverlays(this)
    }

    private fun requestOverlayPermission(): Boolean {
        // Attempt 1: Direct package overlay settings
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Direct package overlay failed: ${e.message}")
        }

        // Attempt 2: Generic Overlay settings list (Oppo/Realme/Xiaomi safe)
        try {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Generic overlay settings failed: ${e.message}")
        }

        // Attempt 3: Application Details Settings fallback
        return openAppDetailsSettings()
    }

    private fun checkAccessibilityPermission(): Boolean {
        if (AutoTypeAccessibilityService.isServiceRunning) {
            return true
        }

        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return false
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        val expectedServiceId = "$packageName/${AutoTypeAccessibilityService::class.java.canonicalName}"
        val expectedShortId = "$packageName/.services.AutoTypeAccessibilityService"

        for (service in enabledServices) {
            val id = service.id
            if (id.equals(expectedServiceId, ignoreCase = true) || id.equals(expectedShortId, ignoreCase = true)) {
                return true
            }
        }

        // Secondary check via Settings.Secure
        try {
            val settingValue = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            if (settingValue.contains(packageName)) {
                return true
            }
        } catch (_: Exception) {}

        return false
    }

    private fun requestAccessibilityPermission(): Boolean {
        // Attempt 1: Standard Accessibility Settings
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Accessibility intent failed: ${e.message}")
        }

        // Attempt 2: General settings fallback
        try {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "General settings intent failed: ${e.message}")
            return false
        }
    }

    private fun requestBatteryOptimization(): Boolean {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Battery ignore intent failed: ${e.message}")
            try {
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
                return true
            } catch (_: Exception) {
                return false
            }
        }
    }

    private fun openAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "openAppDetailsSettings failed: ${e.message}")
            false
        }
    }

    private fun startFloatingOverlayService(): Boolean {
        if (!Settings.canDrawOverlays(this)) {
            return false
        }
        val intent = Intent(this, FloatingOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        return true
    }

    private fun stopFloatingOverlayService() {
        val intent = Intent(this, FloatingOverlayService::class.java)
        stopService(intent)
    }

    @SuppressLint("HardwareIds")
    private fun getAppDeviceId(): String {
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        return if (!androidId.isNullOrEmpty()) {
            androidId
        } else {
            "VF_${Build.MODEL}_${Build.SERIAL.hashCode()}"
        }
    }
}
