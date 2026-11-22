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
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
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
    private var comparisonRecorder: AudioRecorderHelper? = null
    private var comparisonRecognizer: SpeechRecognizer? = null
    private var comparisonNativeText: String = ""
    private var initialSharedAudioPath: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleRouteIntent(intent)
        handleIncomingShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        handleRouteIntent(intent)
        try {
            if (Settings.canDrawOverlays(this) && !FloatingOverlayService.isRunning) {
                startFloatingOverlayService()
            }
        } catch (_: Exception) {}
    }

    private fun handleIncomingShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null) {
            val audioUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }

            if (audioUri != null) {
                val copiedPath = copyAudioStreamToCache(audioUri)
                if (copiedPath != null) {
                    initialSharedAudioPath = copiedPath
                    mainHandler.postDelayed({
                        methodChannel?.invokeMethod("onAudioShared", mapOf("path" to copiedPath))
                    }, 500)
                }
            }
        }
    }

    private fun copyAudioStreamToCache(uri: Uri): String? {
        return try {
            val cacheFolder = java.io.File(cacheDir, "shared_audio").apply { if (!exists()) mkdirs() }
            val mime = contentResolver.getType(uri) ?: ""
            val ext = when {
                mime.contains("opus") -> "opus"
                mime.contains("ogg") -> "ogg"
                mime.contains("aac") -> "aac"
                mime.contains("mp3") || mime.contains("mpeg") -> "mp3"
                mime.contains("wav") -> "wav"
                uri.path?.endsWith(".opus") == true -> "opus"
                uri.path?.endsWith(".ogg") == true -> "ogg"
                uri.path?.endsWith(".m4a") == true -> "m4a"
                uri.path?.endsWith(".mp3") == true -> "mp3"
                uri.path?.endsWith(".aac") == true -> "aac"
                else -> "m4a"
            }
            val destFile = java.io.File(cacheFolder, "voice_note_${System.currentTimeMillis()}.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            destFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to copy shared audio to cache: ${e.message}", e)
            null
        }
    }

    private fun handleRouteIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        if (!route.isNullOrBlank()) {
            intent.removeExtra("route")
            mainHandler.postDelayed({
                methodChannel?.invokeMethod("onNavigateRoute", mapOf("route" to route))
            }, 300)
        }
    }

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
                "startComparisonRecording" -> {
                    try {
                        if (comparisonRecorder == null) {
                            comparisonRecorder = AudioRecorderHelper(applicationContext)
                        }
                        val audioPath = comparisonRecorder?.startRecording()
                        comparisonNativeText = ""

                        mainHandler.post {
                            try {
                                comparisonRecognizer?.destroy()
                                comparisonRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "bn-BD")
                                    putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf("bn-BD", "en-US"))
                                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                                }
                                comparisonRecognizer?.setRecognitionListener(object : RecognitionListener {
                                    override fun onReadyForSpeech(params: Bundle?) {}
                                    override fun onBeginningOfSpeech() {}
                                    override fun onRmsChanged(rmsdB: Float) {}
                                    override fun onBufferReceived(buffer: ByteArray?) {}
                                    override fun onEndOfSpeech() {}
                                    override fun onError(error: Int) {
                                        Log.w(TAG, "comparisonRecognizer error: $error")
                                    }
                                    override fun onResults(results: Bundle?) {
                                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            comparisonNativeText = matches[0]
                                        }
                                    }
                                    override fun onPartialResults(partialResults: Bundle?) {
                                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            comparisonNativeText = matches[0]
                                        }
                                    }
                                    override fun onEvent(eventType: Int, params: Bundle?) {}
                                })
                                comparisonRecognizer?.startListening(intent)
                            } catch (e: Exception) {
                                Log.w(TAG, "comparisonRecognizer setup failed: ${e.message}")
                            }
                        }

                        result.success(audioPath)
                    } catch (e: Exception) {
                        result.error("START_COMPARISON_FAILED", e.message, null)
                    }
                }
                "stopComparisonRecording" -> {
                    try {
                        val audioPath = comparisonRecorder?.stopRecording()
                        comparisonRecorder = null

                        mainHandler.post {
                            try {
                                comparisonRecognizer?.stopListening()
                            } catch (_: Exception) {}
                        }

                        mainHandler.postDelayed({
                            val text = comparisonNativeText
                            try {
                                comparisonRecognizer?.destroy()
                                comparisonRecognizer = null
                            } catch (_: Exception) {}

                            result.success(mapOf(
                                "audioPath" to (audioPath ?: ""),
                                "nativeText" to text
                            ))
                        }, 350)
                    } catch (e: Exception) {
                        result.error("STOP_COMPARISON_FAILED", e.message, null)
                    }
                }
                "startNativeSpeechTest" -> {
                    try {
                        comparisonNativeText = ""
                        mainHandler.post {
                            try {
                                comparisonRecognizer?.destroy()
                                comparisonRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "bn-BD")
                                    putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf("bn-BD", "en-US"))
                                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                                }
                                comparisonRecognizer?.setRecognitionListener(object : RecognitionListener {
                                    override fun onReadyForSpeech(params: Bundle?) {}
                                    override fun onBeginningOfSpeech() {}
                                    override fun onRmsChanged(rmsdB: Float) {}
                                    override fun onBufferReceived(buffer: ByteArray?) {}
                                    override fun onEndOfSpeech() {}
                                    override fun onError(error: Int) {
                                        Log.w(TAG, "nativeSpeechTest error: $error")
                                    }
                                    override fun onResults(results: Bundle?) {
                                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            comparisonNativeText = matches[0]
                                        }
                                    }
                                    override fun onPartialResults(partialResults: Bundle?) {
                                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            comparisonNativeText = matches[0]
                                        }
                                    }
                                    override fun onEvent(eventType: Int, params: Bundle?) {}
                                })
                                comparisonRecognizer?.startListening(intent)
                            } catch (e: Exception) {
                                Log.w(TAG, "nativeSpeechTest setup failed: ${e.message}")
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_NATIVE_TEST_FAILED", e.message, null)
                    }
                }
                "stopNativeSpeechTest" -> {
                    try {
                        mainHandler.post {
                            try {
                                comparisonRecognizer?.stopListening()
                            } catch (_: Exception) {}
                        }
                        mainHandler.postDelayed({
                            val text = comparisonNativeText
                            try {
                                comparisonRecognizer?.destroy()
                                comparisonRecognizer = null
                            } catch (_: Exception) {}
                            result.success(text)
                        }, 350)
                    } catch (e: Exception) {
                        result.error("STOP_NATIVE_TEST_FAILED", e.message, null)
                    }
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
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val versionName = pInfo.versionName ?: "1.0.1"
                        result.success(versionName)
                    } catch (e: Exception) {
                        result.success("1.0.1")
                    }
                }
                "verifyApkSignature" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    result.success(checkApkSignatureMatches(filePath))
                }
                "canInstallUnknownApps" -> {
                    result.success(canRequestPackageInstalls())
                }
                "openUnknownAppSourcesSettings" -> {
                    requestInstallUnknownAppsPermission()
                    result.success(true)
                }
                "openBrowserUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BROWSER_ERROR", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (!filePath.isNullOrBlank()) {
                        val file = java.io.File(filePath)
                        if (file.exists() && file.length() > 0) {
                            try {
                                val apkUri = androidx.core.content.FileProvider.getUriForFile(
                                    applicationContext,
                                    "${applicationContext.packageName}.fileprovider",
                                    file
                                )
                                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                                }
                                startActivity(installIntent)
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "installApk failed: ${e.message}", e)
                                result.error("INSTALL_ERROR", e.message, null)
                            }
                        } else {
                            result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is required", null)
                    }
                }
                "getInitialSharedAudio" -> {
                    val path = initialSharedAudioPath
                    initialSharedAudioPath = null
                    result.success(path)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    try {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, text)
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "শেয়ার করুন")
                        shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(shareIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("path") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "text/plain"
                    try {
                        val file = java.io.File(filePath)
                        if (file.exists()) {
                            val fileUri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val sendIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_STREAM, fileUri)
                                type = mimeType
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val shareIntent = Intent.createChooser(sendIntent, "ফাইল শেয়ার করুন")
                            shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(shareIntent)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "File does not exist", null)
                        }
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
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
            val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.POST_NOTIFICATIONS)
            } else {
                arrayOf(Manifest.permission.RECORD_AUDIO)
            }
            ActivityCompat.requestPermissions(
                this,
                permissions,
                REQUEST_RECORD_AUDIO
            )
            return true
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

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun requestInstallUnknownAppsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open unknown app sources settings: ${e.message}")
            }
        }
    }

    private fun checkApkSignatureMatches(apkPath: String): Boolean {
        return try {
            val file = java.io.File(apkPath)
            if (!file.exists() || file.length() == 0L) return false

            val pm = packageManager
            val installedSignatures: List<ByteArray> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = pInfo.signingInfo
                if (signingInfo != null) {
                    if (signingInfo.hasMultipleSigners()) {
                        signingInfo.apkContentsSigners.map { it.toByteArray() }
                    } else {
                        signingInfo.signingCertificateHistory.map { it.toByteArray() }
                    }
                } else emptyList()
            } else {
                @Suppress("DEPRECATION")
                val pInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                pInfo.signatures?.map { it.toByteArray() } ?: emptyList()
            }

            val archiveSignatures: List<ByteArray> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val aInfo = pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNING_CERTIFICATES) ?: return false
                val signingInfo = aInfo.signingInfo
                if (signingInfo != null) {
                    if (signingInfo.hasMultipleSigners()) {
                        signingInfo.apkContentsSigners.map { it.toByteArray() }
                    } else {
                        signingInfo.signingCertificateHistory.map { it.toByteArray() }
                    }
                } else emptyList()
            } else {
                @Suppress("DEPRECATION")
                val aInfo = pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNATURES) ?: return false
                @Suppress("DEPRECATION")
                aInfo.signatures?.map { it.toByteArray() } ?: emptyList()
            }

            if (installedSignatures.isEmpty() || archiveSignatures.isEmpty()) return false

            installedSignatures.any { inst ->
                archiveSignatures.any { arch -> java.util.Arrays.equals(inst, arch) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Signature verification error: ${e.message}", e)
            true
        }
    }
}
