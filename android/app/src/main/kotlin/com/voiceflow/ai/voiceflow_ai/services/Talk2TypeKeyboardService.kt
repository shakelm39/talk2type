package com.voiceflow.ai.voiceflow_ai.services

import android.Manifest
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.inputmethodservice.InputMethodService
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.LinearInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.ExtractedTextRequest
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.voiceflow.ai.voiceflow_ai.MainActivity
import com.voiceflow.ai.voiceflow_ai.R

class Talk2TypeKeyboardService : InputMethodService(), VoicePipeline.Callback {

    companion object {
        private const val TAG = "Talk2TypeKeyboard"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        @Volatile
        var instance: Talk2TypeKeyboardService? = null
    }

    private var keyboardContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var voicePipeline: VoicePipeline? = null
    private var toneGenerator: ToneGenerator? = null

    // UI elements
    private var rootView: LinearLayout? = null
    private var statusTextView: TextView? = null
    private var micButton: FrameLayout? = null
    private var micBgDrawable: GradientDrawable? = null
    private var pulseRingView: View? = null
    private var pulseAnimator: ValueAnimator? = null
    private var actionButton: TextView? = null
    private var rewriteContainer: HorizontalScrollView? = null
    private var undoButton: TextView? = null
    private val modePillViews = mutableMapOf<String, TextView>()

    // Layout Containers & Dynamic Views
    private var numberRowLayout: LinearLayout? = null
    private var keysAreaLayout: LinearLayout? = null
    private var shiftKeyView: TextView? = null
    private var layerKeyView: TextView? = null
    private var langKeyView: TextView? = null
    private var periodKeyView: TextView? = null
    private var spaceBarView: TextView? = null

    // Popup preview
    private var keyPopup: PopupWindow? = null
    private var keyPopupTextView: TextView? = null

    // Layer, Shift & Language State
    private var currentLayer: Int = 0 // 0: QWERTY, 1: SYMBOLS_1 (?123), 2: SYMBOLS_2 (=<)
    private var shiftState: Int = 0   // 0: OFF, 1: ON (next char), 2: LOCKED
    private var lastShiftTapTime: Long = 0L
    private var typingLang: String = "bn" // "bn" or "en"
    private var vibrateEnabled: Boolean = true
    private var soundEnabled: Boolean = false
    private var aiPolishEnabled: Boolean = true

    // General State
    private var selectedMode: String = "sundor"
    private var isPasswordInput: Boolean = false
    private var lastOriginalTextForUndo: String? = null
    private var undoTimerRunnable: Runnable? = null

    // Phonetic Bangla Buffer
    private val phoneticBuffer = StringBuilder()

    // Backspace continuous repeat
    private val backspaceHandler = Handler(Looper.getMainLooper())
    private var backspaceRunnable: Runnable? = null

    // Character sets
    private val englishDigits = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
    private val banglaDigits = listOf("১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯", "০")

    private val qwertyRow1 = listOf("q", "w", "e", "r", "t", "y", "u", "i", "o", "p")
    private val qwertyRow2 = listOf("a", "s", "d", "f", "g", "h", "j", "k", "l")
    private val qwertyRow3 = listOf("z", "x", "c", "v", "b", "n", "m")

    private val sym1Row1 = listOf("@", "#", "৳", "_", "&", "-", "+", "(", ")", "/")
    private val sym1Row2 = listOf("*", "\"", "'", ":", ";", "!", "?", "।")
    private val sym1Row3 = listOf("~", "\\", "<", ">", "{", "}", "[", "]", "%")

    private val sym2Row1 = listOf("~", "`", "|", "•", "√", "π", "÷", "×", "§", "Δ")
    private val sym2Row2 = listOf("£", "€", "¥", "¢", "^", "°", "=", "{", "}", "\\")
    private val sym2Row3 = listOf("[", "]", "<", ">", "©", "®", "™")

    // Debug test receiver for automated validation of partial/final injection
    private val debugReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val mode = intent?.getStringExtra("mode")
            if (mode != null) {
                selectedMode = mode
                updateModePillsUi()
            }
            val partial = intent?.getStringExtra("partial")
            if (partial != null) {
                onPartial(partial)
            }
            val final = intent?.getStringExtra("final")
            if (final != null) {
                val delayMs = intent.getLongExtra("delay", 0L)
                if (delayMs > 0) {
                    mainHandler.postDelayed({
                        onFinal(final, selectedMode)
                    }, delayMs)
                } else {
                    onFinal(final, selectedMode)
                }
            }
        }
    }

    override fun attachBaseContext(newBase: Context?) {
        if (newBase != null) {
            val config = newBase.resources.configuration
            if (config.fontScale > 1.15f) {
                val newConfig = android.content.res.Configuration(config).apply {
                    fontScale = 1.15f
                }
                val wrapped = newBase.createConfigurationContext(newConfig)
                super.attachBaseContext(wrapped)
                keyboardContext = wrapped
                return
            }
        }
        super.attachBaseContext(newBase)
        keyboardContext = newBase
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        voicePipeline = VoicePipeline(applicationContext, this)
        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 75)
        } catch (_: Exception) {}
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) try {
            val filter = IntentFilter("com.voiceflow.ai.DEBUG_TEST_KEYBOARD")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(debugReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(debugReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        instance = null
        stopPulsingAnimation()
        dismissKeyPopup()
        voicePipeline?.destroy()
        voicePipeline = null
        try {
            toneGenerator?.release()
            toneGenerator = null
        } catch (_: Exception) {}
        try {
            unregisterReceiver(debugReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onCreateInputView(): View {
        val ctx = keyboardContext ?: this
        val isCompact = ctx.resources.configuration.screenWidthDp <= 375
        val sidePadDp = if (isCompact) 4 else 6

        initKeyPopup(ctx)

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0F172A")) // #0F172A Dark Slate
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setPadding(dpToPx(sidePadDp), dpToPx(4), dpToPx(sidePadDp), dpToPx(4))
        }

        // Apply navigation-bar insets to bottom padding (protects against nav bar overlap)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, windowInsets ->
            val navBars = windowInsets.getInsets(WindowInsetsCompat.Type.navigationBars())
            val baseBottom = dpToPx(4)
            view.setPadding(
                dpToPx(sidePadDp),
                dpToPx(4),
                dpToPx(sidePadDp),
                baseBottom + navBars.bottom
            )
            windowInsets
        }

        root.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                ViewCompat.requestApplyInsets(v)
                window?.window?.let { win ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        win.navigationBarColor = Color.parseColor("#0F172A")
                    }
                }
            }
            override fun onViewDetachedFromWindow(v: View) {
                dismissKeyPopup()
            }
        })

        // 1. Mode row (40dp) - 5 chips বাংলা · অফিস · সাপোর্ট · আড্ডা · EN + fixed ✨
        root.addView(createRowAView(ctx))

        // 2. Rewrite Menu (hidden by default)
        rewriteContainer = createRewriteBarView(ctx).apply { visibility = View.GONE }
        root.addView(rewriteContainer)

        // 3. Status strip (26dp): 📋 paste (32dp), status text, ⚙ settings (32dp)
        root.addView(createStatusStripView(ctx))

        // 4. Number row (40dp): 1-0 or ১-০
        val numRow = createNumberRowView(ctx, isCompact)
        numberRowLayout = numRow
        root.addView(numRow)

        // 5. Letter / Symbol Area (3 rows x 44dp = 132dp)
        val keysArea = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        keysAreaLayout = keysArea
        rebuildKeysArea(ctx, isCompact)
        root.addView(keysArea)

        // 6. Bottom row (48dp): ?123 | বাং/EN | , | 🎤 mic key | space (Ayyzan) | . / । | action
        val bRow = createBottomRowView(ctx, isCompact)
        root.addView(bRow)

        rootView = root
        updateModePillsUi()
        return root
    }

    override fun onStartInputView(info: EditorInfo, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        commitPhoneticBuffer()

        // Read preferences
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        typingLang = prefs.getString("flutter.vf_kb_typing_lang", "bn") ?: "bn"
        vibrateEnabled = prefs.getBoolean("flutter.vf_kb_vibrate", true)
        soundEnabled = prefs.getBoolean("flutter.vf_kb_sound", false)
        aiPolishEnabled = prefs.getBoolean("flutter.vf_kb_ai_polish", true)

        // Password field detection
        val inputClass = info.inputType and EditorInfo.TYPE_MASK_CLASS
        val variation = info.inputType and EditorInfo.TYPE_MASK_VARIATION
        isPasswordInput = (inputClass == EditorInfo.TYPE_CLASS_TEXT &&
                (variation == EditorInfo.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                        variation == EditorInfo.TYPE_TEXT_VARIATION_WEB_PASSWORD)) ||
                (inputClass == EditorInfo.TYPE_CLASS_NUMBER &&
                        variation == EditorInfo.TYPE_NUMBER_VARIATION_PASSWORD)

        if (isPasswordInput) {
            typingLang = "en"
        }

        // Auto-capitalization for English
        if (typingLang == "en" && !isPasswordInput) {
            checkAutoCapitalization()
        } else {
            shiftState = 0
        }

        currentLayer = 0

        // Update Action button text according to imeOptions
        val action = info.imeOptions and EditorInfo.IME_MASK_ACTION
        actionButton?.let { btn ->
            when (action) {
                EditorInfo.IME_ACTION_SEND -> {
                    btn.text = "পাঠান"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                }
                EditorInfo.IME_ACTION_SEARCH -> {
                    btn.text = "খুঁজুন"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                }
                EditorInfo.IME_ACTION_GO -> {
                    btn.text = "যান"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                }
                EditorInfo.IME_ACTION_DONE -> {
                    btn.text = "✓"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                }
                EditorInfo.IME_ACTION_NEXT -> {
                    btn.text = "পরের ঘর"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                }
                else -> {
                    btn.text = "↵"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
                    btn.typeface = Typeface.DEFAULT_BOLD
                }
            }
        }

        val ctx = keyboardContext ?: this
        val isCompact = ctx.resources.configuration.screenWidthDp <= 375
        updateNumberRow(ctx, isCompact)
        rebuildKeysArea(ctx, isCompact)
        updateBottomRowUi()
        updateStatusUi()
        updateModePillsUi()

        if (!isPasswordInput) voicePipeline?.prewarm()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        commitPhoneticBuffer()
        dismissKeyPopup()
        if (voicePipeline?.isListening == true) {
            voicePipeline?.stopVoiceInput()
        }
        stopPulsingAnimation()
    }

    // =========================================================================
    // POPUP PREVIEW
    // =========================================================================

    private fun initKeyPopup(ctx: Context) {
        keyPopupTextView = TextView(ctx).apply {
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#334155"))
                cornerRadius = dpToPx(8).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#475569"))
            }
            val pad = dpToPx(8)
            setPadding(pad, pad, pad, pad)
        }
        keyPopup = PopupWindow(
            keyPopupTextView,
            dpToPx(48),
            dpToPx(48)
        ).apply {
            isClippingEnabled = false
            elevation = dpToPx(6).toFloat()
        }
    }

    private fun showKeyPopup(anchor: View, text: String) {
        if (isPasswordInput) return
        try {
            keyPopupTextView?.text = text
            val loc = IntArray(2)
            anchor.getLocationOnScreen(loc)
            val popupX = loc[0] + (anchor.width - dpToPx(48)) / 2
            val popupY = loc[1] - dpToPx(52)
            if (keyPopup?.isShowing == true) {
                keyPopup?.update(popupX, popupY, dpToPx(48), dpToPx(48))
            } else {
                keyPopup?.showAtLocation(anchor, Gravity.NO_GRAVITY, popupX, popupY)
            }
        } catch (_: Exception) {}
    }

    private fun dismissKeyPopup() {
        try {
            if (keyPopup?.isShowing == true) {
                keyPopup?.dismiss()
            }
        } catch (_: Exception) {}
    }

    // =========================================================================
    // ROW BUILDERS
    // =========================================================================

    /**
     * Row 1: Mode row (40dp) - 5 chips বাংলা · অফিস · সাপোর্ট · আড্ডা · EN + fixed ✨
     */
    private fun createRowAView(ctx: Context): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(40)
            )
        }

        val scroll = HorizontalScrollView(ctx).apply {
            isHorizontalScrollBarEnabled = false
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f)
        }

        val pillsLayout = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val modes = listOf(
            Triple("sundor", "বাংলা", false),
            Triple("formal", "অফিস", true),
            Triple("support", "সাপোর্ট", true),
            Triple("casual", "আড্ডা", true),
            Triple("english", "EN", true)
        )

        for ((key, label, isProOnly) in modes) {
            val pill = TextView(ctx).apply {
                text = label
                gravity = Gravity.CENTER
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                typeface = Typeface.DEFAULT_BOLD
                contentDescription = "$label মোড"
                setPadding(dpToPx(12), 0, dpToPx(12), 0)

                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    dpToPx(32)
                ).apply {
                    marginEnd = dpToPx(6)
                }

                setOnClickListener {
                    playKeyFeedback()
                    onModePillClicked(key, isProOnly)
                }
            }
            modePillViews[key] = pill
            pillsLayout.addView(pill)
        }

        scroll.addView(pillsLayout)
        row.addView(scroll)

        // ✨ Fixed 36dp circle pinned right (bg #312E81)
        val sparkleBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(36), dpToPx(36)).apply {
                gravity = Gravity.CENTER_VERTICAL
                marginStart = dpToPx(6)
            }
            background = createKeyBackgroundCircle(
                Color.parseColor("#312E81"),
                Color.parseColor("#4338CA")
            )
            contentDescription = "লেখা সাজানোর মেনু (✨)"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_sparkle)
                layoutParams = FrameLayout.LayoutParams(dpToPx(20), dpToPx(20), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                playKeyFeedback()
                toggleRewriteMenu()
            }
        }
        row.addView(sparkleBtn)

        return row
    }

    /**
     * Row 2: Status strip (26dp) - left 📋 paste (32dp), centre status text, right ⚙ settings (32dp).
     */
    private fun createStatusStripView(ctx: Context): View {
        val strip = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(26)
            ).apply {
                topMargin = dpToPx(2)
                bottomMargin = dpToPx(2)
            }
        }

        // Left 32dp paste button 📋
        val pasteBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(32), dpToPx(24)).apply {
                gravity = Gravity.CENTER_VERTICAL
                marginStart = dpToPx(2)
            }
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(6).toFloat()
            )
            contentDescription = "ক্লিপবোর্ড থেকে পেস্ট করুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_content_paste)
                layoutParams = FrameLayout.LayoutParams(dpToPx(16), dpToPx(16), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                playKeyFeedback()
                pasteFromClipboard()
            }
        }
        strip.addView(pasteBtn)

        // Center status container
        val centerContainer = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f).apply {
                marginStart = dpToPx(6)
                marginEnd = dpToPx(6)
            }
        }

        statusTextView = TextView(ctx).apply {
            text = "বলতে মাইকে চাপুন"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            maxLines = 1
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        }
        centerContainer.addView(statusTextView)

        undoButton = TextView(ctx).apply {
            text = "ফেরত আনুন (৫ সে)"
            setTextColor(Color.parseColor("#38BDF8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(dpToPx(6), 0, dpToPx(6), 0)
            val undoIcon = ContextCompat.getDrawable(ctx, R.drawable.ic_undo)?.mutate()
            undoIcon?.setBounds(0, 0, dpToPx(12), dpToPx(12))
            setCompoundDrawables(undoIcon, null, null, null)
            compoundDrawablePadding = dpToPx(3)

            background = GradientDrawable().apply {
                setColor(Color.parseColor("#0F172A"))
                cornerRadius = dpToPx(8).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#38BDF8"))
            }

            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )

            setOnClickListener {
                playKeyFeedback()
                performUndo()
            }
        }
        centerContainer.addView(undoButton)
        strip.addView(centerContainer)

        // Right 32dp settings button ⚙
        val settingsBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(32), dpToPx(24)).apply {
                gravity = Gravity.CENTER_VERTICAL
                marginEnd = dpToPx(2)
            }
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(6).toFloat()
            )
            contentDescription = "Talk2Type সেটিংস খুলুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_settings)
                layoutParams = FrameLayout.LayoutParams(dpToPx(16), dpToPx(16), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                playKeyFeedback()
                openAppHome()
            }
        }
        strip.addView(settingsBtn)

        return strip
    }

    /**
     * Row 3: Number row (40dp) - 1 2 3 4 5 6 7 8 9 0 or ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯ ০
     */
    private fun createNumberRowView(ctx: Context, isCompact: Boolean): LinearLayout {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val rowHeight = if (isCompact) 38 else 40
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(rowHeight)
            ).apply {
                bottomMargin = dpToPx(3)
            }
        }
        populateNumberRow(row, ctx, isCompact)
        return row
    }

    private fun updateNumberRow(ctx: Context, isCompact: Boolean) {
        numberRowLayout?.let { row ->
            row.removeAllViews()
            populateNumberRow(row, ctx, isCompact)
        }
    }

    private fun populateNumberRow(row: LinearLayout, ctx: Context, isCompact: Boolean) {
        val isBangla = (typingLang == "bn")
        val displayDigits = if (isBangla) banglaDigits else englishDigits
        val altDigits = if (isBangla) englishDigits else banglaDigits
        val gapDp = if (isCompact) 3 else 4
        val keyHeight = if (isCompact) 36 else 38

        for (i in displayDigits.indices) {
            val mainChar = displayDigits[i]
            val altChar = altDigits[i]

            val key = TextView(ctx).apply {
                text = mainChar
                setTextColor(Color.parseColor("#F1F5F9"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                background = createKeyBackground(
                    Color.parseColor("#1E293B"),
                    Color.parseColor("#334155"),
                    dpToPx(8).toFloat()
                )
                val params = LinearLayout.LayoutParams(0, dpToPx(keyHeight), 1f).apply {
                    if (i < displayDigits.size - 1) marginEnd = dpToPx(gapDp)
                }
                layoutParams = params

                setOnClickListener {
                    playKeyFeedback()
                    handleCharacterInput(mainChar)
                }

                setOnLongClickListener {
                    playKeyFeedback()
                    handleCharacterInput(altChar)
                    true
                }
            }
            row.addView(key)
        }
    }

    /**
     * Row 4: Keys Area (3 rows x 44dp = 132dp)
     */
    private fun rebuildKeysArea(ctx: Context, isCompact: Boolean) {
        val area = keysAreaLayout ?: return
        area.removeAllViews()

        val keyH = if (isCompact) 42 else 44
        val gapDp = if (isCompact) 3 else 4

        when (currentLayer) {
            0 -> buildQwertyLayer(area, ctx, isCompact, keyH, gapDp)
            1 -> buildSymbolsLayer1(area, ctx, isCompact, keyH, gapDp)
            2 -> buildSymbolsLayer2(area, ctx, isCompact, keyH, gapDp)
        }
    }

    private fun buildQwertyLayer(
        area: LinearLayout,
        ctx: Context,
        isCompact: Boolean,
        keyH: Int,
        gapDp: Int
    ) {
        val isUpper = (shiftState > 0)

        // Row 1: q w e r t y u i o p (10 keys)
        val r1 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        for (i in qwertyRow1.indices) {
            val raw = qwertyRow1[i]
            val charStr = if (isUpper) raw.uppercase() else raw
            r1.addView(createStandardKey(ctx, charStr, 1f, keyH, i < qwertyRow1.size - 1, gapDp))
        }
        area.addView(r1)

        // Row 2: a s d f g h j k l (9 keys, half-key indent)
        val r2 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        // Left half-key spacer
        r2.addView(View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 0.5f)
        })
        for (i in qwertyRow2.indices) {
            val raw = qwertyRow2[i]
            val charStr = if (isUpper) raw.uppercase() else raw
            r2.addView(createStandardKey(ctx, charStr, 1f, keyH, i < qwertyRow2.size - 1, gapDp))
        }
        // Right half-key spacer
        r2.addView(View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 0.5f).apply {
                marginStart = dpToPx(gapDp)
            }
        })
        area.addView(r2)

        // Row 3: ⇧ (1.5) | z x c v b n m (7 keys) | ⌫ (1.5)
        val r3 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }

        // Shift key ⇧
        val shiftBgColor = when (shiftState) {
            2 -> Color.parseColor("#DC2626") // Caps Lock Red
            1 -> Color.parseColor("#475569") // Shift Active
            else -> Color.parseColor("#1E293B")
        }
        val shiftKey = TextView(ctx).apply {
            text = "⇧"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "শিফট"
            background = createKeyBackground(shiftBgColor, Color.parseColor("#334155"), dpToPx(8).toFloat())
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 1.5f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                handleShiftClick()
            }
        }
        shiftKeyView = shiftKey
        r3.addView(shiftKey)

        for (i in qwertyRow3.indices) {
            val raw = qwertyRow3[i]
            val charStr = if (isUpper) raw.uppercase() else raw
            r3.addView(createStandardKey(ctx, charStr, 1f, keyH, true, gapDp))
        }

        // Backspace key ⌫
        r3.addView(createBackspaceKey(ctx, keyH, 1.5f))
        area.addView(r3)
    }

    private fun buildSymbolsLayer1(
        area: LinearLayout,
        ctx: Context,
        isCompact: Boolean,
        keyH: Int,
        gapDp: Int
    ) {
        // Row 1: @ # ৳ _ & - + ( ) / (10 keys)
        val r1 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        for (i in sym1Row1.indices) {
            r1.addView(createStandardKey(ctx, sym1Row1[i], 1f, keyH, i < sym1Row1.size - 1, gapDp))
        }
        area.addView(r1)

        // Row 2: * " ' : ; ! ? । (8 keys, centered)
        val r2 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        r2.addView(View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 1.0f)
        })
        for (i in sym1Row2.indices) {
            r2.addView(createStandardKey(ctx, sym1Row2[i], 1f, keyH, i < sym1Row2.size - 1, gapDp))
        }
        r2.addView(View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 1.0f).apply {
                marginStart = dpToPx(gapDp)
            }
        })
        area.addView(r2)

        // Row 3: =< (1.5) | ~ \ < > { } [ ] % (9 keys) | ⌫ (1.5) -> scaled
        val r3 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }

        // =< Layer toggle key
        val toLayer2Key = TextView(ctx).apply {
            text = "=\\<"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "আরও চিহ্ন"
            background = createKeyBackground(
                Color.parseColor("#334155"),
                Color.parseColor("#475569"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 1.5f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                switchLayer(2)
            }
        }
        r3.addView(toLayer2Key)

        val symList = listOf("~", "\\", "<", ">", "{", "}", "%")
        for (i in symList.indices) {
            r3.addView(createStandardKey(ctx, symList[i], 1f, keyH, true, gapDp))
        }

        r3.addView(createBackspaceKey(ctx, keyH, 1.5f))
        area.addView(r3)
    }

    private fun buildSymbolsLayer2(
        area: LinearLayout,
        ctx: Context,
        isCompact: Boolean,
        keyH: Int,
        gapDp: Int
    ) {
        // Row 1: ~ ` | • √ π ÷ × § Δ (10 keys)
        val r1 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        for (i in sym2Row1.indices) {
            r1.addView(createStandardKey(ctx, sym2Row1[i], 1f, keyH, i < sym2Row1.size - 1, gapDp))
        }
        area.addView(r1)

        // Row 2: £ € ¥ ¢ ^ ° = { } \ (10 keys)
        val r2 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }
        for (i in sym2Row2.indices) {
            r2.addView(createStandardKey(ctx, sym2Row2[i], 1f, keyH, i < sym2Row2.size - 1, gapDp))
        }
        area.addView(r2)

        // Row 3: ?123 (1.5) | [ ] < > © ® ™ | ⌫ (1.5)
        val r3 = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(keyH)
            ).apply { bottomMargin = dpToPx(gapDp) }
        }

        val toLayer1Key = TextView(ctx).apply {
            text = "?123"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "আগের চিহ্ন"
            background = createKeyBackground(
                Color.parseColor("#334155"),
                Color.parseColor("#475569"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(keyH), 1.5f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                switchLayer(1)
            }
        }
        r3.addView(toLayer1Key)

        for (i in sym2Row3.indices) {
            r3.addView(createStandardKey(ctx, sym2Row3[i], 1f, keyH, true, gapDp))
        }

        r3.addView(createBackspaceKey(ctx, keyH, 1.5f))
        area.addView(r3)
    }

    private fun createStandardKey(
        ctx: Context,
        charStr: String,
        weight: Float,
        heightDp: Int,
        hasMarginEnd: Boolean,
        gapDp: Int
    ): View {
        return TextView(ctx).apply {
            text = charStr
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(heightDp), weight).apply {
                if (hasMarginEnd) marginEnd = dpToPx(gapDp)
            }

            setOnTouchListener { v, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        showKeyPopup(v, charStr)
                    }
                    MotionEvent.ACTION_UP -> {
                        dismissKeyPopup()
                        playKeyFeedback()
                        handleCharacterInput(charStr)
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        dismissKeyPopup()
                    }
                }
                true
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createBackspaceKey(ctx: Context, heightDp: Int, weight: Float): View {
        val gapDp = 4
        return FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(heightDp), weight)
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            contentDescription = "মুছুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_backspace)
                layoutParams = FrameLayout.LayoutParams(dpToPx(22), dpToPx(22), Gravity.CENTER)
            }
            addView(icon)

            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        playKeyFeedback()
                        handleBackspace()
                        startContinuousBackspace()
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        stopContinuousBackspace()
                        true
                    }
                    else -> false
                }
            }
        }
    }

    /**
     * Row 5: Bottom row (48dp): ?123 | বাং/EN | , | 🎤 mic key | space (Ayyzan) | . / । | action
     */
    private fun createBottomRowView(ctx: Context, isCompact: Boolean): View {
        val rowH = if (isCompact) 44 else 48
        val gapDp = if (isCompact) 3 else 4

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(rowH)
            ).apply {
                topMargin = dpToPx(2)
            }
        }

        // 1. ?123 / ABC Layer Key
        val layerKey = TextView(ctx).apply {
            text = if (currentLayer == 0) "?123" else "ABC"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.2f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                if (currentLayer == 0) switchLayer(1) else switchLayer(0)
            }
        }
        layerKeyView = layerKey
        row.addView(layerKey)

        // 2. বাং/EN Language Key (long press = IME picker)
        val langKey = TextView(ctx).apply {
            text = if (typingLang == "bn") "বাং" else "EN"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "টাইপিং ভাষা পরিবর্তন করুন"
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.2f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                toggleTypingLanguage()
            }
            setOnLongClickListener {
                playKeyFeedback()
                showImePicker()
                true
            }
        }
        langKeyView = langKey
        row.addView(langKey)

        // 3. Comma Key (,)
        val commaKey = TextView(ctx).apply {
            text = ","
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
            contentDescription = "কমা"
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.0f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                handleCharacterInput(", ")
            }
        }
        row.addView(commaKey)

        // 4. 🎤 Mic Key (Red gradient, 1.6 width, pulsing ring while listening)
        val micContainer = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.6f).apply {
                marginEnd = dpToPx(gapDp)
            }
        }

        pulseRingView = View(ctx).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
            background = GradientDrawable().apply {
                cornerRadius = dpToPx(10).toFloat()
                setColor(Color.TRANSPARENT)
                setStroke(dpToPx(2), Color.parseColor("#EF4444"))
            }
            alpha = 0f
        }
        micContainer.addView(pulseRingView)

        micBgDrawable = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(Color.parseColor("#EF4444"), Color.parseColor("#B91C1C"))
        ).apply {
            cornerRadius = dpToPx(10).toFloat()
            setStroke(dpToPx(1), Color.parseColor("#4DFFFFFF"))
        }

        micButton = FrameLayout(ctx).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
            background = micBgDrawable
            contentDescription = "কথা বলতে চাপুন"

            val micIcon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_mic_white)
                layoutParams = FrameLayout.LayoutParams(dpToPx(24), dpToPx(24), Gravity.CENTER)
            }
            addView(micIcon)

            setOnClickListener {
                playKeyFeedback()
                onMicButtonClicked()
            }
        }
        micContainer.addView(micButton)
        row.addView(micContainer)

        // 5. Space Bar (flex; label "Ayyzan" in centre, 13sp, #94A3B8)
        val spaceBtn = TextView(ctx).apply {
            text = "Ayyzan"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            contentDescription = "স্পেস"
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 3.5f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                handleSpace()
            }
        }
        spaceBarView = spaceBtn
        row.addView(spaceBtn)

        // 6. Period / Dari Key (. in EN, । in বাং)
        val periodKey = TextView(ctx).apply {
            text = if (typingLang == "bn") "।" else "."
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
            contentDescription = "পূর্ণচ্ছেদ"
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.0f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                playKeyFeedback()
                val punc = if (typingLang == "bn") "। " else ". "
                handleCharacterInput(punc)
            }
        }
        periodKeyView = periodKey
        row.addView(periodKey)

        // 7. Action Key (পাঠান / খুঁজুন / যান / ✓ / পরের ঘর / ↵)
        actionButton = TextView(ctx).apply {
            text = "↵"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "সম্পাদন করুন"
            background = createKeyBackground(
                Color.parseColor("#DC2626"),
                Color.parseColor("#B91C1C"),
                dpToPx(8).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(rowH - 4), 1.5f)
            setOnClickListener {
                playKeyFeedback()
                performEditorAction()
            }
        }
        row.addView(actionButton)

        return row
    }

    private fun createRewriteBarView(ctx: Context): HorizontalScrollView {
        val scroll = HorizontalScrollView(ctx).apply {
            isHorizontalScrollBarEnabled = false
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(36)
            ).apply {
                topMargin = dpToPx(2)
                bottomMargin = dpToPx(2)
            }
        }

        val bar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val options = listOf(
            Pair("সুন্দর করো", "sundor"),
            Pair("ইংরেজি করো", "english"),
            Pair("ছোট করো", "shorten"),
            Pair("অফিসিয়াল করো", "formal"),
            Pair("কাস্টমার রিপ্লাই", "support")
        )

        for ((name, optMode) in options) {
            val btn = TextView(ctx).apply {
                text = name
                setTextColor(Color.parseColor("#F1F5F9"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setPadding(dpToPx(10), dpToPx(4), dpToPx(10), dpToPx(4))
                background = createKeyBackground(
                    Color.parseColor("#334155"),
                    Color.parseColor("#475569"),
                    dpToPx(10).toFloat()
                )
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    dpToPx(28)
                ).apply {
                    marginEnd = dpToPx(6)
                }

                setOnClickListener {
                    playKeyFeedback()
                    applyTextRewrite(optMode)
                }
            }
            bar.addView(btn)
        }

        val closeBtn = TextView(ctx).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dpToPx(8), dpToPx(4), dpToPx(8), dpToPx(4))
            setOnClickListener {
                playKeyFeedback()
                rewriteContainer?.visibility = View.GONE
            }
        }
        bar.addView(closeBtn)

        scroll.addView(bar)
        return scroll
    }

    // =========================================================================
    // LAYER, SHIFT & LANGUAGE MANAGEMENT
    // =========================================================================

    private fun switchLayer(layer: Int) {
        commitPhoneticBuffer()
        currentLayer = layer
        layerKeyView?.text = if (layer == 0) "?123" else "ABC"
        val ctx = keyboardContext ?: this
        val isCompact = ctx.resources.configuration.screenWidthDp <= 375
        rebuildKeysArea(ctx, isCompact)
    }

    private fun handleShiftClick() {
        val now = System.currentTimeMillis()
        if (shiftState == 1 && (now - lastShiftTapTime) < 400L) {
            shiftState = 2 // Double-tap -> Caps lock
        } else if (shiftState == 2) {
            shiftState = 0
        } else {
            shiftState = if (shiftState == 0) 1 else 0
        }
        lastShiftTapTime = now

        val ctx = keyboardContext ?: this
        val isCompact = ctx.resources.configuration.screenWidthDp <= 375
        rebuildKeysArea(ctx, isCompact)
    }

    private fun toggleTypingLanguage() {
        if (isPasswordInput) return
        commitPhoneticBuffer()
        typingLang = if (typingLang == "bn") "en" else "bn"

        // Persist preference
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString("flutter.vf_kb_typing_lang", typingLang).apply()

        updateBottomRowUi()
        val ctx = keyboardContext ?: this
        val isCompact = ctx.resources.configuration.screenWidthDp <= 375
        updateNumberRow(ctx, isCompact)
        rebuildKeysArea(ctx, isCompact)
    }

    private fun updateBottomRowUi() {
        langKeyView?.text = if (typingLang == "bn") "বাং" else "EN"
        periodKeyView?.text = if (typingLang == "bn") "।" else "."
        spaceBarView?.text = "Ayyzan"
        layerKeyView?.text = if (currentLayer == 0) "?123" else "ABC"
    }

    private fun checkAutoCapitalization() {
        if (shiftState == 2) return // Locked
        val ic = currentInputConnection
        if (ic != null) {
            val textBefore = ic.getTextBeforeCursor(2, 0)?.toString() ?: ""
            if (textBefore.isEmpty() || textBefore.endsWith("\n") || textBefore.endsWith(". ") ||
                textBefore.endsWith("? ") || textBefore.endsWith("! ")) {
                shiftState = 1
                return
            }
        }
        shiftState = 0
    }

    // =========================================================================
    // INPUT HANDLING
    // =========================================================================

    private fun commitPhoneticBuffer() {
        if (phoneticBuffer.isNotEmpty()) {
            currentInputConnection?.finishComposingText()
            phoneticBuffer.clear()
            updateStatusUi()
        }
    }

    private fun handleCharacterInput(charStr: String) {
        if (typingLang == "bn" && !isPasswordInput) {
            if (charStr.length == 1 && (charStr[0] in 'a'..'z' || charStr[0] in 'A'..'Z')) {
                phoneticBuffer.append(charStr)
                val converted = PhoneticBangla.convert(phoneticBuffer.toString())
                currentInputConnection?.setComposingText(converted, 1)
                statusTextView?.text = "${phoneticBuffer.toString()} → $converted"
            } else {
                commitPhoneticBuffer()
                currentInputConnection?.commitText(charStr, 1)
            }
        } else {
            commitPhoneticBuffer()
            currentInputConnection?.commitText(charStr, 1)
        }

        // Handle auto-unshift
        if (shiftState == 1) {
            shiftState = 0
            val ctx = keyboardContext ?: this
            val isCompact = ctx.resources.configuration.screenWidthDp <= 375
            rebuildKeysArea(ctx, isCompact)
        }
    }

    private fun handleSpace() {
        commitPhoneticBuffer()
        currentInputConnection?.commitText(" ", 1)
        if (typingLang == "en" && !isPasswordInput) {
            checkAutoCapitalization()
            val ctx = keyboardContext ?: this
            val isCompact = ctx.resources.configuration.screenWidthDp <= 375
            rebuildKeysArea(ctx, isCompact)
        }
    }

    private fun handleBackspace() {
        if (typingLang == "bn" && !isPasswordInput && phoneticBuffer.isNotEmpty()) {
            phoneticBuffer.deleteCharAt(phoneticBuffer.length - 1)
            if (phoneticBuffer.isNotEmpty()) {
                val converted = PhoneticBangla.convert(phoneticBuffer.toString())
                currentInputConnection?.setComposingText(converted, 1)
                statusTextView?.text = "${phoneticBuffer.toString()} → $converted"
            } else {
                currentInputConnection?.commitText("", 1)
                updateStatusUi()
            }
        } else {
            currentInputConnection?.deleteSurroundingText(1, 0)
        }
    }

    private fun playKeyFeedback() {
        if (vibrateEnabled) vibrate(10)
        if (soundEnabled) {
            try {
                val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                am?.playSoundEffect(AudioManager.FX_KEY_CLICK)
            } catch (_: Exception) {}
        }
    }

    // =========================================================================
    // DRAWABLE FACTORIES
    // =========================================================================

    private fun createKeyBackground(normalColor: Int, pressedColor: Int, radiusPx: Float): StateListDrawable {
        val pressed = GradientDrawable().apply {
            setColor(pressedColor)
            cornerRadius = radiusPx
        }
        val normal = GradientDrawable().apply {
            setColor(normalColor)
            cornerRadius = radiusPx
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_pressed), pressed)
            addState(intArrayOf(), normal)
        }
    }

    private fun createKeyBackgroundCircle(normalColor: Int, pressedColor: Int): StateListDrawable {
        val pressed = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(pressedColor)
        }
        val normal = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(normalColor)
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_pressed), pressed)
            addState(intArrayOf(), normal)
        }
    }

    // =========================================================================
    // PULSING ANIMATION FOR MIC
    // =========================================================================

    private fun startPulsingAnimation() {
        stopPulsingAnimation()
        pulseRingView?.alpha = 0.8f
        pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 900
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                val progress = anim.animatedFraction
                val scale = 1.0f + 0.15f * progress
                val alpha = 0.8f * (1.0f - progress)
                pulseRingView?.scaleX = scale
                pulseRingView?.scaleY = scale
                pulseRingView?.alpha = alpha
            }
            start()
        }
    }

    private fun stopPulsingAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        pulseRingView?.alpha = 0f
        pulseRingView?.scaleX = 1f
        pulseRingView?.scaleY = 1f
    }

    // =========================================================================
    // ACTIONS & BUSINESS LOGIC
    // =========================================================================

    private fun onModePillClicked(key: String, isProOnly: Boolean) {
        val isPro = voicePipeline?.isProUser() == true
        if (isProOnly && !isPro) {
            openUpgradeScreen()
            return
        }
        selectedMode = key
        updateModePillsUi()
    }

    private fun openUpgradeScreen() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("route", "/upgrade")
        }
        startActivity(intent)
    }

    private fun openAppHome() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun updateModePillsUi() {
        val ctx = keyboardContext ?: this
        val isPro = voicePipeline?.isProUser() == true
        val lockIcon = ContextCompat.getDrawable(ctx, R.drawable.ic_lock)?.mutate()?.apply {
            setBounds(0, 0, dpToPx(12), dpToPx(12))
        }

        for ((key, pill) in modePillViews) {
            val isSelected = (key == selectedMode)
            val isProOnly = (key != "sundor")
            val isLocked = isProOnly && !isPro

            if (isSelected) {
                pill.background = createKeyBackground(
                    Color.parseColor("#DC2626"),
                    Color.parseColor("#B91C1C"),
                    dpToPx(16).toFloat()
                )
                pill.setTextColor(Color.WHITE)
                pill.alpha = 1.0f
                pill.setCompoundDrawables(null, null, null, null)
            } else {
                pill.background = createKeyBackground(
                    Color.parseColor("#1E293B"),
                    Color.parseColor("#334155"),
                    dpToPx(16).toFloat()
                )
                pill.setTextColor(Color.parseColor("#E2E8F0"))

                if (isLocked) {
                    pill.alpha = 0.6f
                    pill.setCompoundDrawables(null, null, lockIcon, null)
                    pill.compoundDrawablePadding = dpToPx(4)
                } else {
                    pill.alpha = 1.0f
                    pill.setCompoundDrawables(null, null, null, null)
                }
            }
        }
    }

    private fun onMicButtonClicked() {
        commitPhoneticBuffer()
        if (isPasswordInput) {
            Toast.makeText(this, "পাসওয়ার্ডের ঘরে ভয়েস টাইপিং বন্ধ 🔒", Toast.LENGTH_SHORT).show()
            return
        }

        val hasMic = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasMic) {
            Toast.makeText(this, "মাইক্রোফোন অনুমতি দিতে অ্যাপ খুলুন", Toast.LENGTH_LONG).show()
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("route", "/permission-dashboard")
            }
            startActivity(intent)
            return
        }

        val pipeline = voicePipeline ?: return
        if (pipeline.isListening) {
            pipeline.stopVoiceInput()
        } else {
            pipeline.startVoiceInput(selectedMode)
        }
    }

    private fun toggleRewriteMenu() {
        val isPro = voicePipeline?.isProUser() == true
        if (!isPro) {
            openUpgradeScreen()
            return
        }
        rewriteContainer?.let {
            it.visibility = if (it.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
    }

    private fun applyTextRewrite(mode: String) {
        val ic = currentInputConnection ?: return
        var targetText = ic.getSelectedText(0)?.toString() ?: ""
        var isSelection = true

        if (targetText.isBlank()) {
            val extracted = ic.getExtractedText(ExtractedTextRequest(), 0)?.text?.toString() ?: ""
            if (extracted.isNotBlank()) {
                targetText = extracted
                isSelection = false
            } else {
                val before = ic.getTextBeforeCursor(2000, 0)?.toString() ?: ""
                val after = ic.getTextAfterCursor(2000, 0)?.toString() ?: ""
                targetText = before + after
                isSelection = false
            }
        }

        if (targetText.isBlank()) {
            Toast.makeText(this, "সাজানোর মতো কোনো লেখা পাওয়া যায়নি", Toast.LENGTH_SHORT).show()
            return
        }

        rewriteContainer?.visibility = View.GONE
        statusTextView?.text = "লেখা গুছিয়ে দিচ্ছি… (✨)"
        onStateChanged("processing")

        lastOriginalTextForUndo = targetText

        Thread {
            val rewritten = voicePipeline?.rewriteText(targetText, mode) ?: targetText
            mainHandler.post {
                if (isSelection) {
                    ic.commitText(rewritten, 1)
                } else {
                    ic.performContextMenuAction(android.R.id.selectAll)
                    ic.commitText(rewritten, 1)
                }
                onStateChanged("success")
                showUndoButton()
            }
        }.start()
    }

    private fun showUndoButton() {
        statusTextView?.visibility = View.GONE
        undoButton?.visibility = View.VISIBLE
        undoTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        undoTimerRunnable = Runnable {
            undoButton?.visibility = View.GONE
            statusTextView?.visibility = View.VISIBLE
            lastOriginalTextForUndo = null
        }
        mainHandler.postDelayed(undoTimerRunnable!!, 5000)
    }

    private fun performUndo() {
        val original = lastOriginalTextForUndo
        if (!original.isNullOrBlank()) {
            currentInputConnection?.performContextMenuAction(android.R.id.selectAll)
            currentInputConnection?.commitText(original, 1)
            Toast.makeText(this, "আগের লেখা ফিরিয়ে আনা হয়েছে ↩", Toast.LENGTH_SHORT).show()
        }
        undoButton?.visibility = View.GONE
        statusTextView?.visibility = View.VISIBLE
        undoTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        lastOriginalTextForUndo = null
    }

    private fun performEditorAction() {
        commitPhoneticBuffer()
        val info = currentInputEditorInfo ?: return
        val action = info.imeOptions and EditorInfo.IME_MASK_ACTION
        if (action != EditorInfo.IME_ACTION_NONE && action != EditorInfo.IME_ACTION_UNSPECIFIED) {
            currentInputConnection?.performEditorAction(action)
        } else {
            currentInputConnection?.commitText("\n", 1)
        }
    }

    private fun pasteFromClipboard() {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            val clip = cm?.primaryClip?.getItemAt(0)?.text?.toString()
            if (!clip.isNullOrEmpty()) {
                currentInputConnection?.commitText(clip, 1)
                playKeyFeedback()
            } else {
                Toast.makeText(this, "ক্লিপবোর্ডে কোনো লেখা নেই", Toast.LENGTH_SHORT).show()
            }
        } catch (_: Exception) {}
    }

    private fun showImePicker() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.showInputMethodPicker()
    }

    private fun startContinuousBackspace() {
        stopContinuousBackspace()
        backspaceRunnable = object : Runnable {
            override fun run() {
                handleBackspace()
                playKeyFeedback()
                backspaceHandler.postDelayed(this, 50)
            }
        }
        backspaceHandler.postDelayed(backspaceRunnable!!, 350)
    }

    private fun stopContinuousBackspace() {
        backspaceRunnable?.let { backspaceHandler.removeCallbacks(it) }
        backspaceRunnable = null
    }

    private fun updateStatusUi() {
        if (isPasswordInput) {
            statusTextView?.text = "পাসওয়ার্ডের ঘরে ভয়েস বন্ধ 🔒"
            micButton?.alpha = 0.5f
        } else {
            micButton?.alpha = 1.0f
            statusTextView?.text = "বলতে মাইকে চাপুন"
        }
    }

    fun commitTranscribedText(text: String) {
        mainHandler.post {
            currentInputConnection?.commitText(text, 1)
            onStateChanged("success")
        }
    }

    // =========================================================================
    // VOICE PIPELINE CALLBACK IMPLEMENTATION
    // =========================================================================

    override fun onStateChanged(state: String) {
        mainHandler.post {
            when (state) {
                "idle" -> {
                    stopPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#EF4444"),
                        Color.parseColor("#B91C1C")
                    ))
                    micBgDrawable?.setStroke(dpToPx(1), Color.parseColor("#4DFFFFFF"))
                    updateStatusUi()
                }
                "preparing" -> {
                    stopPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#E11D48"),
                        Color.parseColor("#B91C1C")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.parseColor("#FDE68A"))
                    statusTextView?.text = "এক মুহূর্ত…"
                }
                "recording" -> {
                    startPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#E11D48"),
                        Color.parseColor("#B91C1C")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.WHITE)
                    statusTextView?.text = "বলুন… শুনছি"
                }
                "processing" -> {
                    stopPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#F59E0B"),
                        Color.parseColor("#D97706")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.parseColor("#FDE68A"))
                    statusTextView?.text = "গুছিয়ে দিচ্ছি…"
                }
                "success" -> {
                    stopPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#10B981"),
                        Color.parseColor("#059669")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.parseColor("#A7F3D0"))
                    statusTextView?.text = "✓ সম্পন্ন"
                    mainHandler.postDelayed({ onStateChanged("idle") }, 1200)
                }
                "error" -> {
                    stopPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#DC2626"),
                        Color.parseColor("#991B1B")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.parseColor("#FCA5A5"))
                    mainHandler.postDelayed({ onStateChanged("idle") }, 1500)
                }
            }
            micButton?.invalidate()
        }
    }

    override fun onPartial(text: String) {
        mainHandler.post {
            statusTextView?.text = text
            currentInputConnection?.setComposingText(text, 1)
        }
    }

    override fun onFinal(text: String, mode: String) {
        mainHandler.post {
            currentInputConnection?.commitText(text, 1)
            vibrate(30)
        }
    }

    override fun onReplaceLastCommit(oldText: String, newText: String) {
        mainHandler.post {
            val ic = currentInputConnection ?: return@post
            val before = ic.getTextBeforeCursor(oldText.length + 2, 0)?.toString() ?: ""
            if (before.endsWith(oldText)) {
                ic.deleteSurroundingText(oldText.length, 0)
                ic.commitText(newText, 1)
            }
        }
    }

    override fun onError(message: String) {
        mainHandler.post {
            statusTextView?.text = message
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            onStateChanged("error")
        }
    }

    override fun onVoiceCommand(action: VoicePipeline.VoiceCommandAction) {
        mainHandler.post {
            val ic = currentInputConnection ?: return@post
            when (action) {
                is VoicePipeline.VoiceCommandAction.DeleteLastSentence -> {
                    val before = ic.getTextBeforeCursor(500, 0)?.toString() ?: ""
                    val delimiters = listOf('।', '?', '!', '\n')
                    var lastIdx = -1
                    for (i in before.length - 2 downTo 0) {
                        if (before[i] in delimiters) {
                            lastIdx = i
                            break
                        }
                    }
                    val deleteChars = if (lastIdx >= 0) before.length - (lastIdx + 1) else before.length
                    if (deleteChars > 0) {
                        ic.deleteSurroundingText(deleteChars, 0)
                        Toast.makeText(this, "শেষ বাক্য মুছে ফেলা হয়েছে", Toast.LENGTH_SHORT).show()
                    }
                }
                is VoicePipeline.VoiceCommandAction.RequestClearConfirmation -> {
                    Toast.makeText(this, "সব লেখা মুছতে আবার বলুন বা মুছুন", Toast.LENGTH_SHORT).show()
                }
                is VoicePipeline.VoiceCommandAction.AppendText -> {
                    ic.commitText(action.text, 1)
                }
            }
        }
    }

    override fun onAudioCue(isStart: Boolean) {
        try {
            if (toneGenerator == null) {
                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 75)
            }
            val tone = if (isStart) ToneGenerator.TONE_PROP_BEEP else ToneGenerator.TONE_PROP_ACK
            toneGenerator?.startTone(tone, 100)
        } catch (_: Exception) {}
    }

    override fun onVibrate(durationMs: Long) {
        vibrate(durationMs)
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

    private fun dpToPx(dp: Int): Int {
        val ctx = keyboardContext ?: this
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            ctx.resources.displayMetrics
        ).toInt()
    }
}
