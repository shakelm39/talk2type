package com.voiceflow.ai.voiceflow_ai.services

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast

class AutoTypeAccessibilityService : AccessibilityService() {

    private var lastFocusedNode: AccessibilityNodeInfo? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "AutoTypeAccessibility"
        var instance: AutoTypeAccessibilityService? = null
            private set

        val isServiceRunning: Boolean
            get() = instance != null

        /**
         * Injects text directly into the currently active input field.
         * Appends to existing text or falls back to Clipboard paste.
         */
        fun injectTextToFocusedField(context: Context, text: String): Boolean {
            val service = instance
            return if (service != null) {
                service.injectTextInternal(context, text)
            } else {
                fallbackToClipboard(context, text, "AutoType সার্ভিস বন্ধ আছে। ক্লিপবোর্ডে কপি করা হয়েছে।")
                false
            }
        }

        /**
         * Real-time live streaming text injection (keyboard-like typing while user speaks)
         */
        fun injectStreamingText(context: Context, fullText: String, isPartial: Boolean = false): Boolean {
            val service = instance ?: return false
            return service.injectStreamingTextInternal(context, fullText, isPartial)
        }

        /**
         * Replaces the currently streamed partial text with the final transformed / translated text
         */
        fun replaceWithFinalText(context: Context, fullText: String): Boolean {
            val service = instance ?: return false
            return service.replaceWithFinalTextInternal(context, fullText)
        }

        fun resetStreamingSession(baseLength: Int = 0) {
            instance?.resetStreamingSessionInternal(baseLength)
        }

        /**
         * Get the current text already present in the active input field
         */
        fun getActiveFieldText(): String {
            val service = instance ?: return ""
            return service.getActiveFieldTextInternal()
        }

        // Backward-compatible alias
        fun injectText(text: String, fallbackContext: Context? = null): Boolean {
            val ctx = fallbackContext ?: instance?.applicationContext
            return if (ctx != null) {
                injectTextToFocusedField(ctx, text)
            } else {
                false
            }
        }

        fun fallbackToClipboard(context: Context, text: String, message: String = "ক্লিপবোর্ডে কপি করা হয়েছে! পেস্ট করুন।") {
            try {
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("Talk2Type", text)
                clipboard.setPrimaryClip(clip)

                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error copying to clipboard: ${e.message}", e)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "AutoTypeAccessibilityService connected and ready.")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        try {
            lastFocusedNode?.recycle()
        } catch (_: Exception) {}
        lastFocusedNode = null
        Log.i(TAG, "AutoTypeAccessibilityService destroyed.")
    }

    override fun onInterrupt() {
        Log.w(TAG, "AutoTypeAccessibilityService interrupted.")
    }

    private var checkFocusRunnable: Runnable? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_VIEW_CLICKED,
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> {
                val source = event.source
                if (source != null && (source.isEditable || isEditableNode(source))) {
                    try {
                        lastFocusedNode?.recycle()
                    } catch (_: Exception) {}
                    lastFocusedNode = AccessibilityNodeInfo.obtain(source)

                    // Cursor placed in editable field (Messenger, WhatsApp, Gmail, Notepad, etc.) -> Show floating button!
                    FloatingOverlayService.setOverlayVisible(true)
                } else {
                    scheduleFocusCheck()
                }
            }

            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // User closed or switched app (e.g. closed WhatsApp/Messenger/Gmail) -> Check and hide!
                scheduleFocusCheck()
            }
        }
    }

    fun checkActiveFocus() {
        scheduleFocusCheck()
    }

    private fun scheduleFocusCheck() {
        checkFocusRunnable?.let { mainHandler.removeCallbacks(it) }
        checkFocusRunnable = Runnable {
            val hasActiveInput = checkIfActiveInputFocused()
            FloatingOverlayService.setOverlayVisible(hasActiveInput)
        }
        mainHandler.postDelayed(checkFocusRunnable!!, 350)
    }

    private fun checkIfActiveInputFocused(): Boolean {
        return try {
            val root = rootInActiveWindow ?: return false
            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focused != null && (focused.isEditable || isEditableNode(focused))) {
                try {
                    lastFocusedNode?.recycle()
                } catch (_: Exception) {}
                lastFocusedNode = AccessibilityNodeInfo.obtain(focused)
                true
            } else {
                val editable = findEditableNode(root)
                if (editable != null && (editable.isFocused || editable.isEditable)) {
                    try {
                        lastFocusedNode?.recycle()
                    } catch (_: Exception) {}
                    lastFocusedNode = AccessibilityNodeInfo.obtain(editable)
                    true
                } else {
                    false
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isEditableNode(node: AccessibilityNodeInfo): Boolean {
        if (node.isEditable) return true
        val className = node.className?.toString() ?: ""
        return className.contains("EditText", ignoreCase = true) ||
                className.contains("TextInput", ignoreCase = true) ||
                className.contains("AutoCompleteTextView", ignoreCase = true)
    }

    private var lastStreamingLength = 0
    private var streamingBaseLength = 0

    fun resetStreamingSessionInternal(baseLength: Int) {
        streamingBaseLength = baseLength
        lastStreamingLength = 0
    }

    private fun isPlaceholderOrHint(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return true
        val text = node.text?.toString()?.trim() ?: return true
        if (text.isEmpty()) return true
        val hint = node.hintText?.toString()?.trim()
        if (hint != null && (text.equals(hint, ignoreCase = true) || text.startsWith(hint, ignoreCase = true))) return true

        val normalized = text.lowercase().replace(Regex("[.\\s…]+$"), "").trim()
        val commonPlaceholders = listOf(
            "message", "messages", "type a message", "write a message", "type message",
            "send a message", "text message", "type something",
            "বার্তা", "বার্তা লিখুন", "একটি বার্তা লিখুন", "মেসেজ লিখুন", "লিখুন",
            "aa", "search", "খুঁজুন", "অনুসন্ধান", "type here", "enter text"
        )
        return commonPlaceholders.any { it.equals(normalized, ignoreCase = true) }
    }

    fun injectTextInternal(context: Context, text: String): Boolean {
        var targetNode: AccessibilityNodeInfo? = null

        // 1. Try to find active input focus directly from active window root
        try {
            val root = rootInActiveWindow
            if (root != null) {
                targetNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                if (targetNode == null) {
                    targetNode = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                }
                if (targetNode == null) {
                    targetNode = findEditableNode(root)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not fetch rootInActiveWindow focus: ${e.message}")
        }

        // 2. Fallback to cached focused node
        if (targetNode == null || (!targetNode.isEditable && !isEditableNode(targetNode))) {
            targetNode = lastFocusedNode
        }

        // 3. Verify node validity with refresh()
        var isNodeValid = false
        if (targetNode != null) {
            try {
                isNodeValid = targetNode.refresh() && (targetNode.isEditable || isEditableNode(targetNode))
            } catch (e: Exception) {
                Log.w(TAG, "Node refresh failed: ${e.message}")
                isNodeValid = false
            }
        }

        // Always put latest text in ClipboardManager first
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Talk2Type", text)
        clipboard.setPrimaryClip(clip)

        if (targetNode != null && isNodeValid) {
            var injectionSuccess = false

            // Check if existing text is actual user text or merely placeholder/hint text
            val rawExisting = targetNode.text?.toString()?.trim() ?: ""
            val existingText = if (isPlaceholderOrHint(targetNode)) "" else rawExisting

            // METHOD A: Try ACTION_SET_TEXT (appending to existing text if any)
            try {
                val textToInject = if (existingText.isNotBlank()) {
                    "$existingText $text"
                } else {
                    text
                }

                // Update clipboard with combined text if appending
                if (existingText.isNotBlank()) {
                    clipboard.setPrimaryClip(ClipData.newPlainText("Talk2Type", textToInject))
                }

                val arguments = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, textToInject)
                }

                injectionSuccess = targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

                if (injectionSuccess) {
                    // Set cursor selection to end of text
                    try {
                        val selectionBundle = Bundle().apply {
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, textToInject.length)
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, textToInject.length)
                        }
                        targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selectionBundle)
                    } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                Log.w(TAG, "ACTION_SET_TEXT threw exception: ${e.message}")
                injectionSuccess = false
            }

            // METHOD B: CRUCIAL FALLBACK - ACTION_PASTE (WhatsApp, Telegram, Messenger, WebViews)
            if (!injectionSuccess) {
                Log.d(TAG, "ACTION_SET_TEXT failed or unsupported. Executing ACTION_PASTE fallback...")
                try {
                    targetNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    injectionSuccess = targetNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                } catch (e: Exception) {
                    Log.e(TAG, "ACTION_PASTE threw exception: ${e.message}")
                    injectionSuccess = false
                }
            }

            if (injectionSuccess) {
                mainHandler.post {
                    Toast.makeText(context, "সরাসরি টাইপ করা হয়েছে! ✨", Toast.LENGTH_SHORT).show()
                }
                return true
            }
        }

        // Ultimate Fallback: Text is safely in clipboard, notify user to paste
        fallbackToClipboard(context, text, "টেক্সট কপি করা হয়েছে! ইনপুট ফিল্ডে পেস্ট করুন।")
        return false
    }

    fun injectStreamingTextInternal(context: Context, fullText: String, isPartial: Boolean): Boolean {
        var targetNode: AccessibilityNodeInfo? = null
        try {
            val root = rootInActiveWindow
            if (root != null) {
                targetNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    ?: root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                    ?: findEditableNode(root)
            }
        } catch (_: Exception) {}

        if (targetNode == null || (!targetNode.isEditable && !isEditableNode(targetNode))) {
            targetNode = lastFocusedNode
        }

        if (targetNode != null) {
            // Check if active box still has placeholder
            if (isPlaceholderOrHint(targetNode)) {
                streamingBaseLength = 0
            }

            // Method 1: Try ACTION_SET_TEXT (Works instantly on SMS, Telegram, Notes, Chrome, etc.)
            try {
                val arguments = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, fullText)
                }
                val success = targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                if (success) {
                    try {
                        val selArgs = Bundle().apply {
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, fullText.length)
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, fullText.length)
                        }
                        targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selArgs)
                    } catch (_: Exception) {}
                    lastStreamingLength = fullText.length - streamingBaseLength
                    return true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Streaming SET_TEXT failed: ${e.message}")
            }

            // Method 2: Fallback for WhatsApp/Messenger that block ACTION_SET_TEXT:
            // Use Selection Replacement + Paste
            try {
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("Talk2Type", fullText)
                clipboard.setPrimaryClip(clip)

                // If previous partial was injected, select it so ACTION_PASTE cleanly overwrites it
                if (lastStreamingLength > 0) {
                    val selArgs = Bundle().apply {
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, streamingBaseLength)
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, streamingBaseLength + lastStreamingLength)
                    }
                    targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selArgs)
                }

                targetNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                val pasteSuccess = targetNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                if (pasteSuccess) {
                    lastStreamingLength = fullText.length - streamingBaseLength
                    return true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Streaming Selection+Paste failed: ${e.message}")
            }
        }
        return false
    }

    fun replaceWithFinalTextInternal(context: Context, fullText: String): Boolean {
        var targetNode: AccessibilityNodeInfo? = null
        try {
            val root = rootInActiveWindow
            if (root != null) {
                targetNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    ?: root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                    ?: findEditableNode(root)
            }
        } catch (_: Exception) {}

        if (targetNode == null || (!targetNode.isEditable && !isEditableNode(targetNode))) {
            targetNode = lastFocusedNode
        }

        if (targetNode != null) {
            if (isPlaceholderOrHint(targetNode)) {
                streamingBaseLength = 0
            }

            // Method 1: Try ACTION_SET_TEXT
            try {
                val arguments = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, fullText)
                }
                val success = targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                if (success) {
                    try {
                        val selArgs = Bundle().apply {
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, fullText.length)
                            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, fullText.length)
                        }
                        targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selArgs)
                    } catch (_: Exception) {}
                    lastStreamingLength = 0
                    streamingBaseLength = fullText.length
                    return true
                }
            } catch (e: Exception) {
                Log.w(TAG, "replaceWithFinalText SET_TEXT failed: ${e.message}")
            }

            // Method 2: Fallback for WhatsApp/Messenger using Selection + Paste
            try {
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("Talk2Type", fullText)
                clipboard.setPrimaryClip(clip)

                if (lastStreamingLength > 0) {
                    val selArgs = Bundle().apply {
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, streamingBaseLength)
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, streamingBaseLength + lastStreamingLength)
                    }
                    targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selArgs)
                }

                targetNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                val pasteSuccess = targetNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                lastStreamingLength = 0
                streamingBaseLength = fullText.length
                return pasteSuccess
            } catch (e: Exception) {
                Log.e(TAG, "replaceWithFinalText Selection+Paste failed: ${e.message}")
            }
        }
        return false
    }

    fun getActiveFieldTextInternal(): String {
        var targetNode: AccessibilityNodeInfo? = null
        try {
            val root = rootInActiveWindow
            if (root != null) {
                targetNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    ?: root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                    ?: findEditableNode(root)
            }
        } catch (_: Exception) {}

        if (targetNode == null || (!targetNode.isEditable && !isEditableNode(targetNode))) {
            targetNode = lastFocusedNode
        }

        if (targetNode == null) return ""
        if (isPlaceholderOrHint(targetNode)) return ""

        return targetNode.text?.toString()?.trim() ?: ""
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && (node.isEditable || isEditableNode(node))) {
            return node
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findEditableNode(child)
            if (found != null) return found
        }
        if (node.isEditable || isEditableNode(node)) {
            return node
        }
        return null
    }
}
