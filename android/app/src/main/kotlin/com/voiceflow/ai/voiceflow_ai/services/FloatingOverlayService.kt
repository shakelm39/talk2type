package com.voiceflow.ai.voiceflow_ai.services

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.voiceflow.ai.voiceflow_ai.MainActivity

class FloatingOverlayService : Service() {

    companion object {
        private const val TAG = "FloatingOverlayService"
        private const val NOTIFICATION_ID = 9114
        private const val CHANNEL_ID = "talk2type_overlay_channel"

        var instance: FloatingOverlayService? = null
            private set

        val isRunning: Boolean
            get() = instance != null

        fun updateMode(mode: String) {
            instance?.setToneMode(mode)
        }

        fun updateState(state: String) {
            instance?.setOrbState(state)
        }

        fun updateAppearance(sizeDp: Int, opacity: Float) {
            instance?.setAppearance(sizeDp, opacity)
        }

        fun setLastTranscribed(text: String) {
            instance?.lastTranscribedText = text
        }

        fun updateEngineStatus(engine: String) {
            instance?.setEngineStatus(engine)
        }

        fun showError(message: String) {
            instance?.showErrorToast(message)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayRoot: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private lateinit var audioRecorderHelper: AudioRecorderHelper
    private val mainHandler = Handler(Looper.getMainLooper())
    private var toneGenerator: ToneGenerator? = null

    // UI Components
    private lateinit var contentRow: LinearLayout
    private lateinit var orbContainer: FrameLayout
    private lateinit var micGlowHalo: View
    private lateinit var micPulseRing: View
    private lateinit var orbInnerButton: FrameLayout
    private lateinit var orbBg: GradientDrawable
    private lateinit var orbMicView: SleekMicIconView
    private lateinit var modeBadgeDot: View

    // 4-Mode Horizontal Pill Strip (Shown on long-press)
    private lateinit var modeStripContainer: LinearLayout
    private val pillViews = mutableMapOf<String, TextView>()
    private var isModeStripVisible: Boolean = false
    private var hideStripRunnable: Runnable? = null

    // Animation & State
    private var pulseAnimator: AnimatorSet? = null
    private var snapAnimator: ValueAnimator? = null
    private var currentMode: String = "sundor" // sundor, formal, hubohu, english
    private var currentState: String = "idle" // idle, recording, processing, success, error
    private var lastTranscribedText: String = ""

    // Auto-timeout watchdog for processing state (max 14s)
    private val processingTimeoutRunnable = Runnable {
        if (currentState == "processing") {
            Log.w(TAG, "Processing timed out after 14s. Resetting to idle.")
            Toast.makeText(this, "⚠️ এআই রেসপন্স টাইমআউট হয়েছে। আবার চেষ্টা করুন।", Toast.LENGTH_SHORT).show()
            setOrbState("idle")
        }
    }

    // Default opacity & size matching the AI glowing sphere design
    private var defaultIdleOpacity: Float = 0.95f
    private var customOrbSizeDp: Int = 54

    // Drag & Long-press tracking
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false
    private var hasMovedPastThreshold = false
    private var longPressTriggered = false
    private val longPressRunnable = Runnable {
        if (!isDragging && !hasMovedPastThreshold) {
            longPressTriggered = true
            vibrate(45)
            toggleModeStrip()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        audioRecorderHelper = AudioRecorderHelper(applicationContext)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 75)
        } catch (e: Exception) {
            Log.w(TAG, "ToneGenerator init failed: ${e.message}")
        }

        startForeground(NOTIFICATION_ID, buildForegroundNotification())

        if (Settings.canDrawOverlays(this)) {
            initFloatingViews()
        } else {
            Log.e(TAG, "Cannot draw overlay: SYSTEM_ALERT_WINDOW not granted")
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("mode")?.let { mode ->
            setToneMode(mode)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        stopPulseAnimation()
        hideStripRunnable?.let { mainHandler.removeCallbacks(it) }

        try {
            toneGenerator?.release()
            toneGenerator = null
        } catch (_: Exception) {}

        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}

        if (overlayRoot != null) {
            try {
                windowManager?.removeView(overlayRoot)
            } catch (_: Exception) {}
            overlayRoot = null
        }

        Log.i(TAG, "FloatingOverlayService destroyed")
    }

    private fun buildForegroundNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Talk2Type Floating Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the compact floating voice typing button active."
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Talk2Type • ভয়েস টাইপিং সক্রিয়")
            .setContentText("ভাসমান বোতাম চালু আছে। কথা বলতে বোতামটিতে চাপ দিন।")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun getRealScreenWidth(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val bounds = wm.currentWindowMetrics.bounds
                minOf(bounds.width(), bounds.height())
            } else {
                val display = (getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
                val size = android.graphics.Point()
                display.getRealSize(size)
                minOf(size.x, size.y)
            }
        } catch (_: Exception) {
            val dm = resources.displayMetrics
            minOf(dm.widthPixels, dm.heightPixels)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun initFloatingViews() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val screenWidth = getRealScreenWidth()
        val orbPx = dpToPx(customOrbSizeDp)
        val outerContainerSize = orbPx + dpToPx(24) // 78dp compact orb

        // FLAG_NOT_FOCUSABLE is critical so tapping NEVER closes the soft keyboard
        layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = maxOf(dpToPx(8), screenWidth - outerContainerSize - dpToPx(8))
            y = dpToPx(260)
        }

        overlayRoot = FrameLayout(this)

        // Horizontal Row containing [Mode Pill Strip] and [48dp Mic Orb]
        contentRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // 1. Build the 2-Mode Horizontal Pill Strip (Hidden by default, shown on tap!)
        modeStripContainer = buildModeStrip()
        modeStripContainer.visibility = View.GONE
        isModeStripVisible = false
        contentRow.addView(modeStripContainer)

        // 2. Build the Floating Mic Orb (Only this is visible by default)
        orbContainer = buildFloatingOrb()
        contentRow.addView(orbContainer)

        overlayRoot?.addView(contentRow)

        // Setup touch handling with Drag, Tap
        setupOrbTouchListener()

        try {
            windowManager?.addView(overlayRoot, layoutParams)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add window overlay: ${e.message}", e)
        }
    }

    /**
     * Builds the vibrant AI gradient floating microphone orb matching the modern glowing assistant aesthetic.
     */
    private fun buildFloatingOrb(): FrameLayout {
        val orbPx = dpToPx(customOrbSizeDp)
        val outerContainerSize = orbPx + dpToPx(24) // Extra room for soft ambient glow aura and pulse

        val outer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(outerContainerSize, outerContainerSize)
            alpha = defaultIdleOpacity
        }

        // Soft Glowing Ambient Halo (Bloom aura matching user screenshot)
        micGlowHalo = View(this).apply {
            val haloSize = orbPx + dpToPx(20)
            layoutParams = FrameLayout.LayoutParams(haloSize, haloSize).apply {
                gravity = Gravity.CENTER
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                gradientType = GradientDrawable.RADIAL_GRADIENT
                gradientRadius = (haloSize / 2f)
                colors = intArrayOf(
                    Color.parseColor("#66C81E2E"), // Luminous crimson aura
                    Color.parseColor("#25DC2626"), // Ambient red glow
                    Color.TRANSPARENT              // Smooth fade out
                )
            }
        }
        outer.addView(micGlowHalo)

        // Ripple pulse ring (active only when recording)
        micPulseRing = View(this).apply {
            val ringSize = orbPx + dpToPx(22)
            layoutParams = FrameLayout.LayoutParams(ringSize, ringSize).apply {
                gravity = Gravity.CENTER
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#25DC2626"))
                setStroke(dpToPx(2), Color.parseColor("#99EF4444"))
            }
            alpha = 0f
            visibility = View.GONE
        }
        outer.addView(micPulseRing)

        // Circular Orb Button (54dp x 54dp)
        orbInnerButton = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(orbPx, orbPx).apply {
                gravity = Gravity.CENTER
            }
        }

        // Vibrant Crimson Red Orb matching user screenshot
        orbBg = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(
                Color.parseColor("#C81E2E"), // Crimson Red (screenshot theme)
                Color.parseColor("#DC2626"),
                Color.parseColor("#991B1B")
            )
        ).apply {
            shape = GradientDrawable.OVAL
            setStroke(dpToPx(1), Color.parseColor("#4DFFFFFF"))
        }
        orbInnerButton.background = orbBg

        // Sleek Vector Microphone Icon View (Pure white vector icon matching screenshot)
        orbMicView = SleekMicIconView(this).apply {
            val iconSize = dpToPx(30)
            layoutParams = FrameLayout.LayoutParams(iconSize, iconSize).apply {
                gravity = Gravity.CENTER
            }
        }
        orbInnerButton.addView(orbMicView)

        // Small Mode Color Badge Dot at top-right
        modeBadgeDot = View(this).apply {
            val dotSize = dpToPx(11)
            layoutParams = FrameLayout.LayoutParams(dotSize, dotSize).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = dpToPx(3)
                rightMargin = dpToPx(3)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(getModeColor(currentMode))
                setStroke(dpToPx(1), Color.WHITE)
            }
            setOnClickListener {
                val newMode = if (currentMode == "english") "bangla" else "english"
                setToneMode(newMode)
                vibrate(25)
                Toast.makeText(this@FloatingOverlayService, if (newMode == "english") "🌐 মোড: English" else "✍️ মোড: গুছিয়ে বাংলায়", Toast.LENGTH_SHORT).show()
            }
        }
        orbInnerButton.addView(modeBadgeDot)

        outer.addView(orbInnerButton)
        return outer
    }

    /**
     * Builds the clean 2-mode pill strip: "গুছিয়ে বাংলায়" vs "English" (matching user screenshot)
     */
    private fun buildModeStrip(): LinearLayout {
        val strip = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(5), dpToPx(3), dpToPx(5), dpToPx(3))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(38)
            ).apply {
                setMargins(dpToPx(4), 0, dpToPx(4), 0)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(19).toFloat()
                setColor(Color.parseColor("#F218181B")) // 95% opacity Zinc-900 matching screenshot
                setStroke(dpToPx(1), Color.parseColor("#3F3F46"))
            }
        }

        val modes = listOf(
            Pair("bangla", "গুছিয়ে বাংলায়"),
            Pair("english", "English")
        )

        for ((key, title) in modes) {
            val pill = TextView(this).apply {
                text = title
                gravity = Gravity.CENTER
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setPadding(dpToPx(12), dpToPx(5), dpToPx(12), dpToPx(5))
                isClickable = true
                isFocusable = false
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    dpToPx(30)
                ).apply {
                    setMargins(dpToPx(2), 0, dpToPx(2), 0)
                }
                var pDownX = 0f
                var pDownY = 0f
                setOnTouchListener { _, event ->
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            pDownX = event.rawX
                            pDownY = event.rawY
                            true
                        }
                        MotionEvent.ACTION_UP -> {
                            val dist = Math.hypot((event.rawX - pDownX).toDouble(), (event.rawY - pDownY).toDouble())
                            if (dist < dpToPx(14)) {
                                vibrate(25)
                                setToneMode(key)
                                Toast.makeText(
                                    this@FloatingOverlayService,
                                    if (key == "english") "🌐 মোড: English" else "✍️ মোড: গুছিয়ে বাংলায়",
                                    Toast.LENGTH_SHORT
                                ).show()
                            }
                            true
                        }
                        else -> true
                    }
                }
            }
            pillViews[key] = pill
            strip.addView(pill)
        }

        updatePillsUi()
        return strip
    }

    private fun getModeColor(mode: String): Int {
        return Color.parseColor(when (mode.lowercase().trim()) {
            "english" -> "#3B82F6"
            else -> "#C81E2E"
        })
    }

    /**
     * Touch listener handling Dragging and Tapping (Start/Stop Recording).
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun setupOrbTouchListener() {
        val dragSlopPx = dpToPx(12)

        orbContainer.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnimator?.cancel()
                    initialX = layoutParams?.x ?: 0
                    initialY = layoutParams?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    val dist = Math.hypot(dx.toDouble(), dy.toDouble())

                    if (dist > dragSlopPx) {
                        isDragging = true
                        layoutParams?.x = initialX + dx
                        layoutParams?.y = initialY + dy
                        updateLayout()
                    }
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (isDragging) {
                        snapToNearestEdge()
                    } else {
                        // Quick Tap: Toggle Voice Input
                        Log.i(TAG, "Mic Orb clicked! currentState: $currentState")
                        vibrate(35)
                        handleOrbClick()
                    }

                    isDragging = false
                    true
                }

                else -> false
            }
        }
    }

    private fun handleOrbClick() {
        when (currentState) {
            "recording" -> {
                stopVoiceInput()
            }
            "idle" -> {
                // Tapping the floating orb expands the mode strip and starts voice input!
                toggleModeStrip(true)
                startVoiceInput()
            }
            "processing" -> {
                // If user clicks while processing, cancel and reset immediately
                setOrbState("idle")
                toggleModeStrip(false)
            }
            "success", "error" -> {
                toggleModeStrip(true)
                startVoiceInput()
            }
        }
    }

    private fun toggleModeStrip(show: Boolean? = null) {
        val targetShow = show ?: !isModeStripVisible
        isModeStripVisible = targetShow

        hideStripRunnable?.let { mainHandler.removeCallbacks(it) }

        val screenWidth = getRealScreenWidth()
        val curX = layoutParams?.x ?: 0
        val isNearRight = (curX + dpToPx(40) > screenWidth / 2)

        if (targetShow) {
            modeStripContainer.visibility = View.VISIBLE
            updatePillsUi()
            if (isNearRight) {
                layoutParams?.x = maxOf(dpToPx(8), screenWidth - dpToPx(265) - dpToPx(8))
            } else {
                layoutParams?.x = dpToPx(8)
            }
            updateLayout()

            // If not recording, auto-collapse after 5 seconds of inactivity
            hideStripRunnable = Runnable {
                if (currentState != "recording") {
                    toggleModeStrip(false)
                }
            }
            mainHandler.postDelayed(hideStripRunnable!!, 5000)
        } else {
            modeStripContainer.visibility = View.GONE
            if (isNearRight) {
                layoutParams?.x = maxOf(dpToPx(8), screenWidth - dpToPx(78) - dpToPx(8))
            } else {
                layoutParams?.x = dpToPx(8)
            }
            updateLayout()
        }
    }

    private fun snapToNearestEdge() {
        val currentX = layoutParams?.x ?: 0
        val screenWidth = getRealScreenWidth()
        val totalWidth = if (isModeStripVisible) dpToPx(265) else dpToPx(78)
        val edgeMargin = dpToPx(8)

        val targetX = if (currentX + (totalWidth / 2) < (screenWidth / 2)) {
            edgeMargin
        } else {
            maxOf(edgeMargin, screenWidth - totalWidth - edgeMargin)
        }

        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(currentX, targetX).apply {
            duration = 180
            interpolator = DecelerateInterpolator()
            addUpdateListener { animator ->
                layoutParams?.x = animator.animatedValue as Int
                updateLayout()
            }
            start()
        }
    }

    private fun updateLayout() {
        try {
            windowManager?.updateViewLayout(overlayRoot, layoutParams)
        } catch (_: Exception) {}
    }

    fun setEngineStatus(engine: String) {
        mainHandler.post {
            if (engine.contains("Auto-Switched", ignoreCase = true)) {
                Toast.makeText(this, "⚡ $engine", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updatePillsUi() {
        mainHandler.post {
            for ((key, pill) in pillViews) {
                val isSelected = (key == currentMode)
                val bg = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(15).toFloat()
                    if (isSelected) {
                        setColor(Color.parseColor("#C81E2E")) // Active Crimson Red (matching screenshot)
                    } else {
                        setColor(Color.parseColor("#27272A")) // Inactive Dark Charcoal (matching screenshot)
                    }
                }
                pill.background = bg
                pill.setTextColor(if (isSelected) Color.WHITE else Color.parseColor("#A1A1AA"))
                pill.paint.isFakeBoldText = isSelected
            }

            // Update badge dot on the orb
            (modeBadgeDot.background as? GradientDrawable)?.setColor(getModeColor(currentMode))
        }
    }

    fun setToneMode(mode: String) {
        currentMode = when (mode.lowercase().trim()) {
            "english", "en", "bangla_to_english", "english_translate" -> "english"
            else -> "bangla" // default: গুছিয়ে বাংলায়
        }

        updatePillsUi()
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var isUsingSpeechRecognizer = false
    private var isContinuousRecording = false
    private var baseText = ""
    private var committedText = ""
    private var currentPartialText = ""

    private fun createSpeechRecognizerSafe(): SpeechRecognizer? {
        if (SpeechRecognizer.isRecognitionAvailable(this)) {
            try {
                val r = SpeechRecognizer.createSpeechRecognizer(this)
                if (r != null) return r
            } catch (e: Exception) {
                Log.w(TAG, "Default createSpeechRecognizer failed: ${e.message}")
            }
        }

        val candidates = listOf(
            android.content.ComponentName("com.google.android.googlequicksearchbox", "com.google.android.voicesearch.serviceapi.GoogleRecognitionService"),
            android.content.ComponentName("com.google.android.tts", "com.google.android.apps.speech.tts.googletts.service.GoogleTTSService")
        )
        for (comp in candidates) {
            try {
                val r = SpeechRecognizer.createSpeechRecognizer(this, comp)
                if (r != null) {
                    Log.i(TAG, "Created SpeechRecognizer with candidate: $comp")
                    return r
                }
            } catch (_: Exception) {}
        }

        return try {
            SpeechRecognizer.createSpeechRecognizer(this)
        } catch (_: Exception) {
            null
        }
    }

    private fun startVoiceInput() {
        Log.i(TAG, "startVoiceInput called. mode=$currentMode")
        startContinuousVoiceTyping()
    }

    private fun stopVoiceInput() {
        if (isUsingSpeechRecognizer) {
            stopContinuousVoiceTyping()
        } else {
            stopRecordingAndProcess()
        }
    }

    private fun startContinuousVoiceTyping() {
        isContinuousRecording = true
        isUsingSpeechRecognizer = true
        baseText = AutoTypeAccessibilityService.getActiveFieldText().trim()
        AutoTypeAccessibilityService.resetStreamingSession(baseText.length)
        committedText = ""
        currentPartialText = ""

        playAudioCue(true)
        setOrbState("recording")
        if (currentMode == "english") {
            Toast.makeText(this, "বাংলায় বলুন... ইংরেজিতে অনুবাদ হবে 🌐", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "বাংলায় বলুন... গুছিয়ে লেখা হবে ✍️", Toast.LENGTH_SHORT).show()
        }

        startListeningLoop()
    }

    private fun startListeningLoop() {
        if (!isContinuousRecording) return

        try {
            speechRecognizer?.let {
                try {
                    it.cancel()
                    it.destroy()
                } catch (_: Exception) {}
            }
            speechRecognizer = createSpeechRecognizerSafe()
            if (speechRecognizer == null) {
                Log.w(TAG, "SpeechRecognizer is null! Falling back to standard voice recording.")
                isUsingSpeechRecognizer = false
                startVoiceRecording()
                return
            }

            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d(TAG, "SpeechRecognizer onReadyForSpeech")
                }

                override fun onBeginningOfSpeech() {
                    Log.d(TAG, "SpeechRecognizer onBeginningOfSpeech")
                }

                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d(TAG, "SpeechRecognizer onEndOfSpeech")
                }

                override fun onError(error: Int) {
                    Log.w(TAG, "SpeechRecognizer onError: $error")
                    if (isContinuousRecording) {
                        // Silently restart listening on pauses/timeouts so user can keep talking as long as they want!
                        mainHandler.postDelayed({
                            if (isContinuousRecording) {
                                startListeningLoop()
                            }
                        }, 100)
                    } else {
                        setOrbState("idle")
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val partial = matches?.firstOrNull()?.trim() ?: ""
                    if (partial.isNotEmpty() && isContinuousRecording) {
                        currentPartialText = partial
                        val combined = buildLiveText(baseText, committedText, currentPartialText)
                        AutoTypeAccessibilityService.injectStreamingText(this@FloatingOverlayService, combined, true)
                    }
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val segment = matches?.firstOrNull()?.trim() ?: ""
                    Log.i(TAG, "SpeechRecognizer segment onResults: '$segment'")
                    if (segment.isNotEmpty()) {
                        committedText = if (committedText.isEmpty()) segment else "$committedText $segment"
                        currentPartialText = ""
                        val combined = buildLiveText(baseText, committedText, "")
                        AutoTypeAccessibilityService.injectStreamingText(this@FloatingOverlayService, combined, false)
                    }

                    if (isContinuousRecording) {
                        // Keep listening continuously!
                        mainHandler.post { startListeningLoop() }
                    } else {
                        finishContinuousVoiceTyping()
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                // For all modes (including English translation mode), the user speaks in Bengali!
                val lang = "bn-BD"
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
                putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, lang)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra("android.speech.extra.DICTATION_MODE", true)
            }

            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "SpeechRecognizer startListening failed: ${e.message}")
            if (isContinuousRecording) {
                mainHandler.postDelayed({ if (isContinuousRecording) startListeningLoop() }, 200)
            }
        }
    }

    private fun buildLiveText(base: String, committed: String, partial: String): String {
        val parts = mutableListOf<String>()
        if (base.isNotBlank()) parts.add(base)
        if (committed.isNotBlank()) parts.add(committed)
        if (partial.isNotBlank()) parts.add(partial)
        return parts.joinToString(" ")
    }

    private fun stopContinuousVoiceTyping() {
        if (!isContinuousRecording) return
        isContinuousRecording = false
        playAudioCue(false)
        stopPulseAnimation()

        try {
            speechRecognizer?.stopListening()
        } catch (_: Exception) {}

        finishContinuousVoiceTyping()
    }

    private fun finishContinuousVoiceTyping() {
        val finalSpoken = if (committedText.isNotBlank()) {
            if (currentPartialText.isNotBlank()) "$committedText $currentPartialText" else committedText
        } else {
            currentPartialText
        }.trim()

        if (finalSpoken.isEmpty()) {
            setOrbState("idle")
            toggleModeStrip(false)
            committedText = ""
            currentPartialText = ""
            baseText = ""
            AutoTypeAccessibilityService.resetStreamingSession(0)
            return
        }

        // 🌐 1. ENGLISH TRANSLATION MODE: Convert spoken Bengali into natural English!
        if (currentMode == "english") {
            setOrbState("processing")
            Thread {
                val englishText = translateBanglaToEnglish(finalSpoken)
                mainHandler.post {
                    val fullCombined = buildLiveText(baseText, englishText, "")
                    AutoTypeAccessibilityService.replaceWithFinalText(this@FloatingOverlayService, fullCombined)
                    lastTranscribedText = fullCombined
                    MainActivity.notifyTranscriptionCompleted(fullCombined, currentMode)
                    setOrbState("success")
                    playAudioCue(false)
                    showInsertedConfirmation()

                    committedText = ""
                    currentPartialText = ""
                    baseText = ""
                    AutoTypeAccessibilityService.resetStreamingSession(0)

                    // Auto-collapse mode strip 1.5s after confirmation so user can see it
                    mainHandler.postDelayed({
                        if (currentState != "recording") {
                            toggleModeStrip(false)
                        }
                    }, 1500)
                }
            }.start()
            return
        }

        // ✍️ 2. গুছিয়ে বাংলায় MODE: Polish Bengali speech with natural punctuation & grammar
        setOrbState("processing")
        Thread {
            val polishedBangla = polishGuchiyeBangla(finalSpoken)
            mainHandler.post {
                val fullCombined = buildLiveText(baseText, polishedBangla, "")
                AutoTypeAccessibilityService.replaceWithFinalText(this@FloatingOverlayService, fullCombined)
                lastTranscribedText = fullCombined
                MainActivity.notifyTranscriptionCompleted(fullCombined, currentMode)
                setOrbState("success")
                playAudioCue(false)
                showInsertedConfirmation()

                committedText = ""
                currentPartialText = ""
                baseText = ""
                AutoTypeAccessibilityService.resetStreamingSession(0)

                // Auto-collapse mode strip 1.5s after confirmation so user can see it
                mainHandler.postDelayed({
                    if (currentState != "recording") {
                        toggleModeStrip(false)
                    }
                }, 1500)
            }
        }.start()
    }

    private fun showInsertedConfirmation() {
        mainHandler.post {
            Toast.makeText(this, "✓ লেখা বসানো হয়েছে", Toast.LENGTH_SHORT).show()
        }
    }

    private fun polishGuchiyeBangla(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""

        // Try Gemini API if key is present
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val apiKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
                ?: prefs.getString("flutter.vf_gemini_api_key", null)
            if (!apiKey.isNullOrBlank()) {
                val geminiResult = callGeminiTextTransform(trimmed, "bangla", apiKey)
                if (geminiResult.isNotBlank() && !geminiResult.equals(trimmed, ignoreCase = true)) {
                    Log.i(TAG, "Guchiye Bangla Gemini polish success: '$geminiResult'")
                    return geminiResult
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Guchiye Bangla polish failed: ${e.message}")
        }

        // Clean formatting fallback (ensure Bengali punctuation)
        return if (!trimmed.endsWith("।") && !trimmed.endsWith("?") && !trimmed.endsWith("!")) {
            "$trimmed।"
        } else {
            trimmed
        }
    }

    private fun translateBanglaToEnglish(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""

        // 1. Google Translate GTX Public API (Ultra-fast, zero auth, high accuracy)
        try {
            val encoded = java.net.URLEncoder.encode(trimmed, "UTF-8")
            val url = java.net.URL("https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=$encoded")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.requestMethod = "GET"
            conn.setRequestProperty("User-Agent", "Mozilla/5.0")
            conn.connectTimeout = 3500
            conn.readTimeout = 4000

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val jsonArray = org.json.JSONArray(response)
                val sentences = jsonArray.optJSONArray(0)
                if (sentences != null && sentences.length() > 0) {
                    val sb = StringBuilder()
                    for (i in 0 until sentences.length()) {
                        val part = sentences.optJSONArray(i)
                        val trans = part?.optString(0)
                        if (!trans.isNullOrEmpty()) {
                            sb.append(trans)
                        }
                    }
                    val result = sb.toString().trim()
                    if (result.isNotEmpty()) {
                        Log.i(TAG, "Google Translate success: '$trimmed' -> '$result'")
                        return result
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Google Translate request failed: ${e.message}")
        }

        // 2. Fallback to Gemini if API key is stored in SharedPreferences
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val apiKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
                ?: prefs.getString("flutter.vf_gemini_api_key", null)
            if (!apiKey.isNullOrBlank()) {
                val geminiResult = callGeminiTextTransform(trimmed, "english", apiKey)
                if (geminiResult.isNotBlank() && !geminiResult.equals(trimmed, ignoreCase = true)) {
                    Log.i(TAG, "Gemini translation fallback success: '$geminiResult'")
                    return geminiResult
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Gemini translation fallback failed: ${e.message}")
        }

        return trimmed
    }

    private fun callGeminiTextTransform(text: String, mode: String, apiKey: String): String {
        val systemPrompt = when (mode) {
            "bangla", "guchiye", "sundor" -> "You are an executive Bengali communication assistant. Format and polish the given spoken Bengali text into natural, polite, grammatically correct standard Bengali with appropriate punctuation (দাঁড়ি, কমা). Preserve the user's exact meaning and numbers/details. Output ONLY the polished Bengali text."
            "formal" -> "You are an executive Bengali communication assistant. Convert the given spoken Bengali text into polite, polished, and formal standard Bengali suitable for official messages or emails. Output ONLY the final formal Bengali text."
            "english" -> "Translate or transcribe the given spoken Bengali text into natural, fluent, and grammatical English. Output ONLY the English text."
            else -> "Fix punctuation and output polished text. Output ONLY the final text."
        }

        val url = java.net.URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey")
        val conn = url.openConnection() as java.net.HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.connectTimeout = 4000
        conn.readTimeout = 5000
        conn.doOutput = true

        val jsonBody = org.json.JSONObject().apply {
            put("systemInstruction", org.json.JSONObject().apply {
                put("parts", org.json.JSONArray().put(org.json.JSONObject().put("text", systemPrompt)))
            })
            put("contents", org.json.JSONArray().put(org.json.JSONObject().apply {
                put("parts", org.json.JSONArray().put(org.json.JSONObject().put("text", text)))
            }))
            put("generationConfig", org.json.JSONObject().apply {
                put("temperature", 0.2)
                put("maxOutputTokens", 1024)
            })
        }

        conn.outputStream.use { os ->
            os.write(jsonBody.toString().toByteArray(Charsets.UTF_8))
        }

        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val root = org.json.JSONObject(response)
            val candidates = root.optJSONArray("candidates")
            val firstCandidate = candidates?.optJSONObject(0)
            val content = firstCandidate?.optJSONObject("content")
            val parts = content?.optJSONArray("parts")
            val resultPart = parts?.optJSONObject(0)
            return resultPart?.optString("text")?.trim() ?: text
        } else {
            Log.w(TAG, "Gemini HTTP response code: ${conn.responseCode}")
            return text
        }
    }

    private fun startVoiceRecording() {
        playAudioCue(true)
        val audioPath = audioRecorderHelper.startRecording()
        if (audioPath != null) {
            setOrbState("recording")
            Toast.makeText(this, "শুনছি... (থামাতে বাটনে চাপুন)", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "মাইক্রোফোন রেকর্ডিং শুরু করা যায়নি", Toast.LENGTH_SHORT).show()
            setOrbState("idle")
        }
    }

    private fun stopRecordingAndProcess() {
        playAudioCue(false)
        stopPulseAnimation()
        setOrbState("processing")

        mainHandler.postDelayed({
            val audioPath = audioRecorderHelper.stopRecording()
            if (audioPath != null) {
                MainActivity.notifyAudioRecorded(audioPath, currentMode)
            } else {
                Toast.makeText(this, "কোনো শব্দ রেকর্ড হয়নি। জোরে কথা বলুন।", Toast.LENGTH_SHORT).show()
                setOrbState("idle")
            }
        }, 150)
    }

    fun showErrorToast(message: String) {
        mainHandler.post {
            mainHandler.removeCallbacks(processingTimeoutRunnable)
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            setOrbState("error")
        }
    }

    fun setOrbState(state: String) {
        currentState = state
        mainHandler.post {
            mainHandler.removeCallbacks(processingTimeoutRunnable)
            when (state) {
                "idle" -> {
                    stopPulseAnimation()
                    orbContainer.alpha = defaultIdleOpacity
                    orbBg.colors = intArrayOf(
                        Color.parseColor("#C81E2E"), // Crimson Red (matching screenshot)
                        Color.parseColor("#DC2626"),
                        Color.parseColor("#991B1B")
                    )
                    orbBg.setStroke(dpToPx(1), Color.parseColor("#4DFFFFFF"))
                    orbMicView.state = "idle"
                    micGlowHalo.visibility = View.VISIBLE
                }
                "recording" -> {
                    orbContainer.alpha = 1.0f
                    // Vibrant glowing pulse while listening
                    orbBg.colors = intArrayOf(
                        Color.parseColor("#E11D48"),
                        Color.parseColor("#DC2626"),
                        Color.parseColor("#B91C1C")
                    )
                    orbBg.setStroke(dpToPx(2), Color.WHITE)
                    orbMicView.state = "recording"
                    startPulseAnimation()
                }
                "processing" -> {
                    stopPulseAnimation()
                    orbContainer.alpha = 1.0f
                    orbBg.colors = intArrayOf(
                        Color.parseColor("#F59E0B"),
                        Color.parseColor("#D97706"),
                        Color.parseColor("#8B5CF6")
                    )
                    orbBg.setStroke(dpToPx(2), Color.parseColor("#FDE68A"))
                    orbMicView.state = "processing"
                    mainHandler.postDelayed(processingTimeoutRunnable, 14000)
                }
                "success" -> {
                    stopPulseAnimation()
                    orbContainer.alpha = 1.0f
                    orbBg.colors = intArrayOf(
                        Color.parseColor("#10B981"),
                        Color.parseColor("#059669"),
                        Color.parseColor("#06B6D4")
                    )
                    orbBg.setStroke(dpToPx(2), Color.parseColor("#A7F3D0"))
                    orbMicView.state = "success"
                    mainHandler.postDelayed({ setOrbState("idle") }, 1200)
                }
                "error" -> {
                    stopPulseAnimation()
                    orbContainer.alpha = 1.0f
                    orbBg.colors = intArrayOf(
                        Color.parseColor("#EF4444"),
                        Color.parseColor("#DC2626"),
                        Color.parseColor("#B91C1C")
                    )
                    orbBg.setStroke(dpToPx(2), Color.parseColor("#FCA5A5"))
                    orbMicView.state = "error"
                    mainHandler.postDelayed({ setOrbState("idle") }, 1500)
                }
            }
            orbInnerButton.invalidate()
        }
    }

    private fun startPulseAnimation() {
        stopPulseAnimation()
        micPulseRing.visibility = View.VISIBLE
        micPulseRing.alpha = 0.85f

        val scaleX = ObjectAnimator.ofFloat(micPulseRing, "scaleX", 1.0f, 1.45f)
        val scaleY = ObjectAnimator.ofFloat(micPulseRing, "scaleY", 1.0f, 1.45f)
        val alpha = ObjectAnimator.ofFloat(micPulseRing, "alpha", 0.85f, 0.0f)

        pulseAnimator = AnimatorSet().apply {
            playTogether(scaleX, scaleY, alpha)
            duration = 900
            interpolator = AccelerateDecelerateInterpolator()
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (currentState == "recording") {
                        start()
                    }
                }
            })
            start()
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        micPulseRing.alpha = 0f
        micPulseRing.scaleX = 1.0f
        micPulseRing.scaleY = 1.0f
        micPulseRing.visibility = View.GONE
    }

    private fun playAudioCue(isStart: Boolean) {
        try {
            if (toneGenerator == null) {
                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 75)
            }
            val tone = if (isStart) ToneGenerator.TONE_PROP_BEEP else ToneGenerator.TONE_PROP_ACK
            toneGenerator?.startTone(tone, 100)
        } catch (_: Exception) {}
    }

    fun setAppearance(sizeDp: Int, opacity: Float) {
        mainHandler.post {
            if (opacity in 0.3f..1.0f) {
                defaultIdleOpacity = opacity
                if (currentState == "idle") {
                    orbContainer.alpha = opacity
                }
            }
            updateLayout()
        }
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun vibrate(durationMs: Long) {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(durationMs)
            }
        } catch (_: Exception) {}
    }
}

/**
 * Custom View that draws the crisp white vector microphone matching the modern AI assistant aesthetic.
 */
class SleekMicIconView(context: Context) : View(context) {
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }

    var state: String = "idle"
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        val cx = w / 2f
        val cy = h / 2f

        when (state) {
            "recording" -> {
                // Sleek rounded square for active recording state
                val sqSize = w * 0.38f
                val r = sqSize * 0.22f
                val rect = RectF(cx - sqSize / 2f, cy - sqSize / 2f, cx + sqSize / 2f, cy + sqSize / 2f)
                canvas.drawRoundRect(rect, r, r, fillPaint)
            }
            "processing" -> {
                // Hourglass during translation/processing
                textPaint.textSize = h * 0.52f
                val yPos = cy - (textPaint.descent() + textPaint.ascent()) / 2f
                canvas.drawText("⏳", cx, yPos, textPaint)
            }
            "success" -> {
                // Crisp Checkmark
                strokePaint.strokeWidth = w * 0.12f
                val p = Path().apply {
                    moveTo(cx - w * 0.22f, cy)
                    lineTo(cx - w * 0.05f, cy + h * 0.18f)
                    lineTo(cx + w * 0.24f, cy - h * 0.16f)
                }
                canvas.drawPath(p, strokePaint)
            }
            "error" -> {
                // X mark
                strokePaint.strokeWidth = w * 0.12f
                val d = w * 0.18f
                canvas.drawLine(cx - d, cy - d, cx + d, cy + d, strokePaint)
                canvas.drawLine(cx + d, cy - d, cx - d, cy + d, strokePaint)
            }
            else -> {
                // Sleek Pure White Vector Microphone matching user screenshot
                strokePaint.strokeWidth = w * 0.088f

                // 1. Center Capsule (Fill)
                val capW = w * 0.30f
                val capH = h * 0.46f
                val capTop = cy - capH * 0.62f
                val capRect = RectF(cx - capW / 2f, capTop, cx + capW / 2f, capTop + capH)
                val capRadius = capW / 2f
                canvas.drawRoundRect(capRect, capRadius, capRadius, fillPaint)

                // 2. Cradle (U-shape arc around capsule)
                val cradleW = capW + w * 0.18f
                val cradleH = capH * 0.80f
                val cradleTop = capTop + capH * 0.20f
                val cradleRect = RectF(cx - cradleW / 2f, cradleTop, cx + cradleW / 2f, cradleTop + cradleH)
                canvas.drawArc(cradleRect, 0f, 180f, false, strokePaint)

                // 3. Vertical stem
                val stemTop = cradleTop + cradleH
                val stemBottom = stemTop + h * 0.12f
                canvas.drawLine(cx, stemTop, cx, stemBottom, strokePaint)

                // 4. Horizontal base
                val baseW = w * 0.28f
                canvas.drawLine(cx - baseW / 2f, stemBottom, cx + baseW / 2f, stemBottom, strokePaint)
            }
        }
    }
}
