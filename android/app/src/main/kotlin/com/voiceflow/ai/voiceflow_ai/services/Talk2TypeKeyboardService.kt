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
import android.content.res.ColorStateList
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
import android.widget.RelativeLayout
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

    // State
    private var selectedMode: String = "sundor"
    private var isPasswordInput: Boolean = false
    private var lastOriginalTextForUndo: String? = null
    private var undoTimerRunnable: Runnable? = null

    // Backspace continuous repeat
    private var backspaceHandler: Handler = Handler(Looper.getMainLooper())
    private var backspaceRunnable: Runnable? = null

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
        try {
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
        val sidePadDp = if (isCompact) 6 else 8

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
            override fun onViewDetachedFromWindow(v: View) {}
        })

        // 1. Row A (44dp): 5 mode chips in HorizontalScrollView + fixed 40dp ✨ circle pinned right
        root.addView(createRowAView(ctx))

        // 2. Rewrite Menu (hidden by default)
        rewriteContainer = createRewriteBarView(ctx).apply { visibility = View.GONE }
        root.addView(rewriteContainer)

        // 3. Row B (22dp): Centred status 13sp #94A3B8
        root.addView(createRowBView(ctx))

        // 4. Row C (96dp): Centred 76dp red mic + pulsing ring; left 44dp round paste; right 44dp round settings
        root.addView(createRowCView(ctx))

        // 5. Row D (52dp): 46dp keys, 6dp gaps, radius 10dp
        //    🌐 (44) | , (40) | । (40) | ? (40) | স্পেস (flex) | ⌫ (52) | action (64)
        root.addView(createRowDView(ctx, isCompact))

        rootView = root
        updateModePillsUi()
        return root
    }

    override fun onStartInputView(info: EditorInfo, restarting: Boolean) {
        super.onStartInputView(info, restarting)

        // Password field detection
        val inputClass = info.inputType and EditorInfo.TYPE_MASK_CLASS
        val variation = info.inputType and EditorInfo.TYPE_MASK_VARIATION
        isPasswordInput = (inputClass == EditorInfo.TYPE_CLASS_TEXT &&
                (variation == EditorInfo.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                        variation == EditorInfo.TYPE_TEXT_VARIATION_WEB_PASSWORD)) ||
                (inputClass == EditorInfo.TYPE_CLASS_NUMBER &&
                        variation == EditorInfo.TYPE_NUMBER_VARIATION_PASSWORD)

        // Update Action button text according to imeOptions
        val action = info.imeOptions and EditorInfo.IME_MASK_ACTION
        actionButton?.let { btn ->
            when (action) {
                EditorInfo.IME_ACTION_SEND -> {
                    btn.text = "পাঠান"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                }
                EditorInfo.IME_ACTION_SEARCH -> {
                    btn.text = "খুঁজুন"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                }
                EditorInfo.IME_ACTION_GO -> {
                    btn.text = "যান"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                }
                EditorInfo.IME_ACTION_DONE -> {
                    btn.text = "✓"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                }
                EditorInfo.IME_ACTION_NEXT -> {
                    btn.text = "পরের ঘর"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                }
                else -> {
                    btn.text = "↵"
                    btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
                    btn.typeface = android.graphics.Typeface.DEFAULT_BOLD
                }
            }
        }

        updateStatusUi()
        updateModePillsUi()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        if (voicePipeline?.isListening == true) {
            voicePipeline?.stopVoiceInput()
        }
        stopPulsingAnimation()
    }

    // =========================================================================
    // ROW BUILDERS
    // =========================================================================

    /**
     * Row A (44dp): HorizontalScrollView with 5 chips বাংলা · অফিস · সাপোর্ট · আড্ডা · EN
     * (height 34dp, 14dp horizontal padding, radius 17dp, 15sp; inactive bg #1E293B text #E2E8F0;
     * active bg #DC2626 white; Pro-locked: small 🔒 + 60% text alpha).
     * ✨ is NOT in the scroll: fixed 40dp circle (bg #312E81) pinned right.
     */
    private fun createRowAView(ctx: Context): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(44)
            )
        }

        // HorizontalScrollView for 5 chips
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
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                typeface = Typeface.DEFAULT_BOLD
                contentDescription = "$label মোড"
                setPadding(dpToPx(14), 0, dpToPx(14), 0)

                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    dpToPx(34)
                ).apply {
                    marginEnd = dpToPx(6)
                }

                setOnClickListener {
                    vibrate(20)
                    onModePillClicked(key, isProOnly)
                }
            }
            modePillViews[key] = pill
            pillsLayout.addView(pill)
        }

        scroll.addView(pillsLayout)
        row.addView(scroll)

        // ✨ Fixed 40dp circle pinned right (bg #312E81)
        val sparkleBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(40), dpToPx(40)).apply {
                gravity = Gravity.CENTER_VERTICAL
                marginStart = dpToPx(8)
            }
            background = createKeyBackgroundCircle(
                Color.parseColor("#312E81"),
                Color.parseColor("#4338CA")
            )
            contentDescription = "লেখা সাজানোর মেনু (✨)"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_sparkle)
                layoutParams = FrameLayout.LayoutParams(dpToPx(22), dpToPx(22), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                vibrate(20)
                toggleRewriteMenu()
            }
        }
        row.addView(sparkleBtn)

        return row
    }

    /**
     * Row B (22dp): Centred status 13sp #94A3B8 ("বলতে মাইকে চাপুন" / "শুনছি…" / "গুছিয়ে দিচ্ছি…").
     */
    private fun createRowBView(ctx: Context): View {
        val container = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(22)
            )
        }

        statusTextView = TextView(ctx).apply {
            text = "বলতে মাইকে চাপুন"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            maxLines = 1
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        }
        container.addView(statusTextView)

        // Undo button (superimposed in Row B when active)
        undoButton = TextView(ctx).apply {
            text = "আগের লেখা ফেরত আনুন (৫ সে)"
            setTextColor(Color.parseColor("#38BDF8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(dpToPx(8), 0, dpToPx(8), 0)
            val undoIcon = ContextCompat.getDrawable(ctx, R.drawable.ic_undo)?.mutate()
            undoIcon?.setBounds(0, 0, dpToPx(14), dpToPx(14))
            setCompoundDrawables(undoIcon, null, null, null)
            compoundDrawablePadding = dpToPx(4)

            background = GradientDrawable().apply {
                setColor(Color.parseColor("#0F172A"))
                cornerRadius = dpToPx(10).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#38BDF8"))
            }

            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )

            setOnClickListener {
                vibrate(20)
                performUndo()
            }
        }
        container.addView(undoButton)

        return container
    }

    /**
     * Row C (96dp): Centred 76dp red mic (gradient #EF4444→#B91C1C, white vector mic, pulsing ring while listening);
     * left 44dp round 📋 পেস্ট; right 44dp round ⚙ (opens app). Both bg #1E293B.
     */
    private fun createRowCView(ctx: Context): View {
        val row = RelativeLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(96)
            )
        }

        // Left 44dp round Paste button 📋
        val pasteBtn = FrameLayout(ctx).apply {
            val pSize = dpToPx(44)
            layoutParams = RelativeLayout.LayoutParams(pSize, pSize).apply {
                addRule(RelativeLayout.ALIGN_PARENT_START)
                addRule(RelativeLayout.CENTER_VERTICAL)
                marginStart = dpToPx(16)
            }
            background = createKeyBackgroundCircle(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155")
            )
            contentDescription = "ক্লিপবোর্ড থেকে পেস্ট করুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_content_paste)
                layoutParams = FrameLayout.LayoutParams(dpToPx(22), dpToPx(22), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                vibrate(20)
                pasteFromClipboard()
            }
        }
        row.addView(pasteBtn)

        // Center: 76dp Mic with pulsing ring container
        val micContainer = FrameLayout(ctx).apply {
            val cSize = dpToPx(96)
            layoutParams = RelativeLayout.LayoutParams(cSize, cSize).apply {
                addRule(RelativeLayout.CENTER_IN_PARENT)
            }
        }

        // Pulsing ring view (88dp diameter)
        pulseRingView = View(ctx).apply {
            val rSize = dpToPx(88)
            layoutParams = FrameLayout.LayoutParams(rSize, rSize, Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.TRANSPARENT)
                setStroke(dpToPx(2), Color.parseColor("#EF4444"))
            }
            alpha = 0f
        }
        micContainer.addView(pulseRingView)

        // Centred 76dp red mic
        val micSize = dpToPx(76)
        micBgDrawable = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(Color.parseColor("#EF4444"), Color.parseColor("#B91C1C"))
        ).apply {
            shape = GradientDrawable.OVAL
            setStroke(dpToPx(2), Color.parseColor("#4DFFFFFF"))
        }

        micButton = FrameLayout(ctx).apply {
            layoutParams = FrameLayout.LayoutParams(micSize, micSize, Gravity.CENTER)
            background = micBgDrawable
            contentDescription = "কথা বলতে চাপুন"

            val micIcon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_mic_white)
                layoutParams = FrameLayout.LayoutParams(dpToPx(36), dpToPx(36), Gravity.CENTER)
            }
            addView(micIcon)

            setOnClickListener {
                vibrate(25)
                onMicButtonClicked()
            }
        }
        micContainer.addView(micButton)
        row.addView(micContainer)

        // Right 44dp round Settings button ⚙
        val settingsBtn = FrameLayout(ctx).apply {
            val sSize = dpToPx(44)
            layoutParams = RelativeLayout.LayoutParams(sSize, sSize).apply {
                addRule(RelativeLayout.ALIGN_PARENT_END)
                addRule(RelativeLayout.CENTER_VERTICAL)
                marginEnd = dpToPx(16)
            }
            background = createKeyBackgroundCircle(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155")
            )
            contentDescription = "Talk2Type সেটিংস খুলুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_settings)
                layoutParams = FrameLayout.LayoutParams(dpToPx(22), dpToPx(22), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                vibrate(20)
                openAppHome()
            }
        }
        row.addView(settingsBtn)

        return row
    }

    /**
     * Row D (52dp): keys 46dp tall, 6dp gaps, radius 10dp, bg #1E293B, pressed #334155, glyphs #F1F5F9 20sp:
     * 🌐 (44dp, Material "language" vector) | , (40) | । (40) | ? (40) | স্পেস (flex, label 14sp #94A3B8) |
     * ⌫ (52dp, Material "backspace" vector, hold-to-repeat) | action (64dp, bg #DC2626, label from imeOptions).
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun createRowDView(ctx: Context, isCompact: Boolean): View {
        val gapDp = if (isCompact) 4 else 6
        val globeW = if (isCompact) 40 else 44
        val puncW = if (isCompact) 36 else 40
        val bsW = if (isCompact) 48 else 52
        val actW = if (isCompact) 58 else 64

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(52)
            )
        }

        // 1. 🌐 Language Switch / Picker
        val globeBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(globeW), dpToPx(46)).apply {
                marginEnd = dpToPx(gapDp)
            }
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(10).toFloat()
            )
            contentDescription = "কিবোর্ড পরিবর্তন করুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_language)
                layoutParams = FrameLayout.LayoutParams(dpToPx(22), dpToPx(22), Gravity.CENTER)
            }
            addView(icon)

            setOnClickListener {
                vibrate(20)
                switchKeyboard()
            }
            setOnLongClickListener {
                vibrate(25)
                showImePicker()
                true
            }
        }
        row.addView(globeBtn)

        // 2. Punctuation: ,
        row.addView(createTextKeyButton(ctx, ",", puncW, "কমা", gapDp) {
            currentInputConnection?.commitText(", ", 1)
        })

        // 3. Punctuation: ।
        row.addView(createTextKeyButton(ctx, "।", puncW, "দাঁড়ি", gapDp) {
            currentInputConnection?.commitText("। ", 1)
        })

        // 4. Punctuation: ?
        row.addView(createTextKeyButton(ctx, "?", puncW, "প্রশ্নবোধক চিহ্ন", gapDp) {
            currentInputConnection?.commitText("? ", 1)
        })

        // 5. Space Bar (flex, weight 1)
        val spaceBtn = TextView(ctx).apply {
            text = "স্পেস"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            contentDescription = "স্পেস"
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(10).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(46), 1f).apply {
                marginEnd = dpToPx(gapDp)
            }
            setOnClickListener {
                vibrate(20)
                currentInputConnection?.commitText(" ", 1)
            }
        }
        row.addView(spaceBtn)

        // 6. ⌫ Backspace (with hold-to-repeat)
        val backspaceBtn = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(bsW), dpToPx(46)).apply {
                marginEnd = dpToPx(gapDp)
            }
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(10).toFloat()
            )
            contentDescription = "মুছুন"

            val icon = ImageView(ctx).apply {
                setImageResource(R.drawable.ic_backspace)
                layoutParams = FrameLayout.LayoutParams(dpToPx(24), dpToPx(24), Gravity.CENTER)
            }
            addView(icon)

            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        currentInputConnection?.deleteSurroundingText(1, 0)
                        vibrate(20)
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
        row.addView(backspaceBtn)

        // 7. Action Button (64dp, bg #DC2626)
        actionButton = TextView(ctx).apply {
            text = "↵"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            contentDescription = "সম্পাদন করুন"
            background = createKeyBackground(
                Color.parseColor("#DC2626"),
                Color.parseColor("#B91C1C"),
                dpToPx(10).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(dpToPx(actW), dpToPx(46))
            setOnClickListener {
                vibrate(20)
                performEditorAction()
            }
        }
        row.addView(actionButton)

        return row
    }

    private fun createTextKeyButton(
        ctx: Context,
        glyph: String,
        widthDp: Int,
        desc: String,
        marginEndDp: Int,
        onClickAction: () -> Unit
    ): TextView {
        return TextView(ctx).apply {
            text = glyph
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
            contentDescription = desc
            background = createKeyBackground(
                Color.parseColor("#1E293B"),
                Color.parseColor("#334155"),
                dpToPx(10).toFloat()
            )
            layoutParams = LinearLayout.LayoutParams(dpToPx(widthDp), dpToPx(46)).apply {
                marginEnd = dpToPx(marginEndDp)
            }
            setOnClickListener {
                vibrate(20)
                onClickAction()
            }
        }
    }

    private fun createRewriteBarView(ctx: Context): HorizontalScrollView {
        val scroll = HorizontalScrollView(ctx).apply {
            isHorizontalScrollBarEnabled = false
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(38)
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
                setPadding(dpToPx(10), dpToPx(5), dpToPx(10), dpToPx(5))
                background = createKeyBackground(
                    Color.parseColor("#334155"),
                    Color.parseColor("#475569"),
                    dpToPx(12).toFloat()
                )
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    dpToPx(32)
                ).apply {
                    marginEnd = dpToPx(6)
                }
                layoutParams = params

                setOnClickListener {
                    vibrate(20)
                    applyTextRewrite(optMode)
                }
            }
            bar.addView(btn)
        }

        // Close button
        val closeBtn = TextView(ctx).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dpToPx(10), dpToPx(4), dpToPx(10), dpToPx(4))
            setOnClickListener {
                vibrate(15)
                rewriteContainer?.visibility = View.GONE
            }
        }
        bar.addView(closeBtn)

        scroll.addView(bar)
        return scroll
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
                val scale = 1.0f + 0.35f * progress
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
                    dpToPx(17).toFloat()
                )
                pill.setTextColor(Color.WHITE)
                pill.alpha = 1.0f
                pill.setCompoundDrawables(null, null, null, null)
            } else {
                pill.background = createKeyBackground(
                    Color.parseColor("#1E293B"),
                    Color.parseColor("#334155"),
                    dpToPx(17).toFloat()
                )
                pill.setTextColor(Color.parseColor("#E2E8F0"))

                if (isLocked) {
                    pill.alpha = 0.6f // 60% text alpha for Pro-locked
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
        if (isPasswordInput) {
            Toast.makeText(this, "পাসওয়ার্ডের ঘরে ভয়েস টাইপিং বন্ধ 🔒", Toast.LENGTH_SHORT).show()
            return
        }

        // Check RECORD_AUDIO permission
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
                vibrate(25)
            } else {
                Toast.makeText(this, "ক্লিপবোর্ডে কোনো লেখা নেই", Toast.LENGTH_SHORT).show()
            }
        } catch (_: Exception) {}
    }

    private fun switchKeyboard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (!switchToPreviousInputMethod()) {
                showImePicker()
            }
        } else {
            showImePicker()
        }
    }

    private fun showImePicker() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.showInputMethodPicker()
    }

    private fun startContinuousBackspace() {
        stopContinuousBackspace()
        backspaceRunnable = object : Runnable {
            override fun run() {
                currentInputConnection?.deleteSurroundingText(1, 0)
                vibrate(15)
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

    /**
     * Commit text from floating orb into active editor
     */
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
                    micBgDrawable?.setStroke(dpToPx(2), Color.parseColor("#4DFFFFFF"))
                    updateStatusUi()
                }
                "recording" -> {
                    startPulsingAnimation()
                    micBgDrawable?.setColors(intArrayOf(
                        Color.parseColor("#E11D48"),
                        Color.parseColor("#B91C1C")
                    ))
                    micBgDrawable?.setStroke(dpToPx(2), Color.WHITE)
                    statusTextView?.text = "শুনছি…"
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
            // commitText() REPLACES the current composing (live partial) text.
            // Do NOT call finishComposingText() first: that would freeze the raw
            // partial (e.g. Bangla in EN mode) and append the final text after it.
            currentInputConnection?.commitText(text, 1)
            vibrate(30)
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
