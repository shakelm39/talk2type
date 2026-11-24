# [Antigravity — Talk2Type] Phase 15 (v2.2): "AI সুবিধা" panel in the Talk2Type keyboard

Branch `ai-panel` from `keyboard` (latest commit). Commit only, NEVER push, debug builds only, never touch keystore/key.properties, never print keys/tokens. Keep every existing keyboard feature and the Play-Protect-safe manifest (no new sensitive permissions — re-run the manifest check at the end).

## What to build
Tapping ✨ opens an "AI সুবিধা" panel that REPLACES the mic area (same keyboard height; a ✕/◀ returns to the mic view). Our own design: navy #0F172A background, tiles #1E293B, accent crimson #DC2626, 2–3 tiles per row, each tile 48dp tall with a vector icon + Bangla label, radius 14dp, scrollable grid. A one-line hint on top (dismissible, remembered): "কিছু অংশ সিলেক্ট করলে শুধু সেটুকু বদলাবে, না করলে পুরো লেখা।"

### Actions (text tab)
| Tile | What the AI does (same language as input unless stated) |
|---|---|
| ব্যাকরণ ঠিক করো | fix spelling, grammar, punctuation only; keep words & meaning |
| আবার লেখো | rewrite clearer and more natural, same meaning |
| ছোট করো | shorten, keep key facts (existing) |
| বিস্তারিত করো | expand with 1–2 natural sentences, no invented facts/numbers |
| অফিসিয়াল | polite professional tone (existing) |
| বন্ধুসুলভ | warm casual tone |
| আবেগ যোগ করো | add warmth/feeling, not over the top |
| হাস্যরস যোগ করো | light, respectful humour; never offensive |
| আকর্ষণীয় করো | catchy, engaging wording (for sales/posts) |
| ইমেইল বানাও | turn into an email: greeting, body, closing (subject line first if English) |
| সোশ্যাল পোস্ট | Facebook-style post with 2–4 relevant hashtags |
| ইমোজি যোগ করো | add a few fitting emojis, don't change text |
| কাস্টমার রিপ্লাই | courteous seller reply (existing) |
| উত্তর লিখে দাও | uses the CLIPBOARD text as the received message (user copies the incoming message first) — generate a short reply in the current tone; if clipboard empty show "যে মেসেজের উত্তর চান সেটা আগে কপি করুন" |
| অনুবাদ | opens a small chooser: English · বাংলা · हिन्दी · العربية; translate to the chosen language |

### Result flow (better than replace-blindly)
1. Read selected text (`getSelectedText`) or the whole field (`getExtractedText`, fallback before+after cursor). Empty → toast "লেখার ঘরে কিছু লিখুন বা সিলেক্ট করুন".
2. Show a loading state on the tile, then a **preview card** inside the panel with the result and three buttons: **✓ বসাও** (replace selection/field via existing replace logic), **↻ আবার** (regenerate), **✕ বাতিল**. "উত্তর লিখে দাও" inserts at the cursor instead of replacing.
3. Keep the existing 5-second **ফেরত আনুন** (undo) after inserting.
4. Respect password fields (panel disabled there).

### Engine & gating
- Reuse the existing Gemini text path in VoicePipeline (keys list, `flutter.vf_gemini_models` order, 404 skip, quota → next key, 15 s timeout). One prompt template per action, all ending with "Output ONLY the final text, no quotes, no explanation." Keep input language unless the action is অনুবাদ.
- Pro only. Free users see the panel with 🔒 on every tile; tapping opens the app's upgrade screen. Pro without a Gemini key → "এই ফিচারের জন্য AI Key দিন" with a button to the key setup screen.
- Do NOT add an image ("ছবি") tab in this phase.

## Done
- `flutter analyze` 0, `flutter test` pass (unit tests for prompt selection per action, selected-vs-whole text choice, clipboard reply empty case, Free lock), debug build installed on my phone.
- Screenshots to `docs/antigravity/review/screens/ai-panel/`: panel (Free, locked), panel (Pro), preview card, translate chooser, result inserted in WhatsApp.
- Manifest check (no accessibility/notification-listener/SMS) in the report.
- Report `docs/antigravity/reports/phase-15-ai-panel.md`. STOP.
