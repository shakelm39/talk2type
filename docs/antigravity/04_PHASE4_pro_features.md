# [Antigravity — Talk2Type] Phase 4: New Pro features

Read `00_MASTER_PLAN.md` first. Requires Phase 3B approved. All features below are **Pro-only** (use the Phase 3B gate) and use the customer's own key (BYOK). Do them in this order; one commit per feature.

## 4.1 Rewrite existing text ("লেখা ঠিক করো")
- Long-press on the orb (keep existing long-press behaviour if any — document it; if long-press is already used, use a new "✨" pill at the end of the mode strip instead) opens a small action menu: **সুন্দর করো** (fix grammar/punctuation, same language) · **ইংরেজি করো** · **ছোট করো** · **অফিসিয়াল করো** · **কাস্টমার রিপ্লাই**.
- Reads the focused field text via `AutoTypeAccessibilityService.getActiveFieldText()`; if the user has a selection, use only the selection. Sends to Gemini with an action prompt, then replaces the field text (or selection) using the existing replace logic (F7 path incl. PASTE fallback).
- Before replacing, keep the original in memory and show a toast with "ফেরত আনুন" (undo) for 5 s.
- Empty field → toast "ফিল্ডে কোনো লেখা নেই".

## 4.2 Voice commands (native speech path)
While dictating, these spoken words act as commands instead of being typed (Bangla + English variants, only when spoken as a standalone phrase/at the end of an utterance):
- "নতুন লাইন" / "new line" → `\n`
- "দাঁড়ি" → `।`, "কমা" → `,`, "প্রশ্নবোধক" → `?`
- "শেষ বাক্য মুছো" → delete the last sentence typed in this session
- "সব মুছো" → ask confirmation via orb (tap ✓ within 3 s) then clear text typed in this session only (never text that was there before).
Make the command list a single table in code. Add a Bangla help card in the app listing them.

## 4.3 Voice snippets (shortcuts)
- New screen "শর্টকাট": list of trigger → expansion (e.g. "আমার ঠিকানা" → full address, "ডেলিভারি চার্জ" → text). Add/edit/delete, stored locally (SQLite table in the existing history DB with a proper migration, or SharedPreferences JSON — justify choice).
- If the whole recognized utterance (trimmed, punctuation removed) equals a trigger → type the expansion instead of the spoken text. Works in every mode, no AI call.

## 4.4 Voice note → text (Share target)
- Register an Android share intent filter for `audio/*` (incl. WhatsApp `.opus`, `.ogg`, `.m4a`, `.mp3`, `.aac`) in AndroidManifest.
- Received file → copy to cache → transcribe with Gemini (audio inline / Files API if > 15 MB; respect size limits, show error if too big) in the selected mode (bangla or english translation).
- Result screen: text, buttons কপি / শেয়ার / হিস্টোরিতে রাখা হয়েছে (save to history with mode `voice_note`).
- Show progress; works when the app was closed (cold start from share).

## 4.5 History export
- History screen: export all / filtered items as `.txt` or `.csv` via Android share sheet. Bangla text must be UTF-8 (CSV with BOM so Excel opens Bangla correctly).

## Done =
Each feature: manual test steps for the owner + what you verified on emulator. Free user tries each feature → sees upgrade prompt. Regression checklist re-verified. Report `reports/phase-4.md`. Commit(s). STOP.
