# [Antigravity — Talk2Type repo: E:\XAMPP\htdocs\Talk2Type]
# TASK 17: Colourful modern key layout (no number row, long-press hints)

Do this AFTER the floating-button fix, on the same branch `test/keyboard-layout`. Commit only, never push.
Never read/print any password or token. Do not uninstall the app on the phone (adb install -r only).
Keep every feature from Task 16 working (phonetic Bangla, ?123 layers, mic + listening animation,
5 mode chips, ✨, paste, settings, password/email Latin-only, "Ayyzan" space label, voice timings).

Reference: owner's screenshot (pink letter keys, dark function keys, small hint characters in the
top-right corner of each key).

## 1. Remove the separate number row
Numbers and symbols move INTO the letter keys as small hints (top-right corner, 10sp, 70% white):
- Row 1: q¹ w² e³ r⁴ t⁵ y⁶ u⁷ i⁸ o⁹ p⁰   (in বাং typing language the hints are ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯ ০)
- Row 2: a@ s# d& f* g- h! j? k( l)
- Row 3: z" x' c: v; b/ n, m.   (pick hints that do not clash; ৳ goes on the ?123 layer)
- **Long-press (~300 ms) types the hint character** (digit/symbol). Short tap types the letter.
  Show the hint big in the key-press popup while long-pressing. Haptic tick when the long-press fires.
- Phonetic: a hint character commits the current phonetic word first (same as other symbols).
- `?123` layer still exists with all digits and symbols (for typing many numbers).
- Keyboard total height drops by ~42dp (good: less of the chat is covered).

## 2. Colours - modern, Ayyzan brand (pink #FF0A7A, navy #0B1120, purple #7C3AED, green #10B981)
- Keyboard background: #0B1120.
- Letter keys: pink, subtle vertical gradient #FF2D8E → #E6006A, corner radius 10dp, 1dp bottom
  shadow (#99000000), white letters 22sp medium; hint chars white 70%.
  Pressed: #C2005A + key-press popup (pink bubble above the key with the big character).
- Function keys (⇧, ⌫, ?123, বাং/EN, `,`, `।/.`): dark #1E1E2A, icons/text in pink #FF4D9D.
  ⇧ active = filled pink; caps lock = pink with underline bar.
- Space bar: pink like letters, label "Ayyzan" centered white 70% with small ◂ ▸ arrows on both sides
  (swipe on space bar left/right = switch বাং/EN, optional).
- Action key (✓ / পাঠান / ↵ …): dark #1E1E2A with pink icon, like the reference.
- Mic key: stands out - gradient purple #7C3AED → pink #FF0A7A, white mic icon; listening animation
  from 353bff4 stays (breathing scale + colour), colours adapted to purple/pink.
- Mode chips row: inactive chip #1E1E2A text #E2E8F0; selected chip pink #FF0A7A white text;
  ✨ circle purple #7C3AED. Status strip text #94A3B8, live text white.
- Same theme in all layers (?123 keys use the function-key dark style for symbols? NO - symbols are
  "letter" keys → pink, controls dark).

## 3. Layout rows (top → bottom)
mode chips (40dp) · status strip (26dp) · q-p (46dp) · a-l (46dp) · ⇧ z-m ⌫ (46dp) ·
?123 | বাং/EN | , | 🎤 | space "Ayyzan" | ।/. | action (48dp).  Compact (≤375dp): keys 42dp.

## 4. Verify & report
Screenshots for the owner (do NOT commit): EN letters, বাং letters (Bangla digit hints), long-press on
"q" (1 / ১), long-press "a" (@), ?123 layer, listening state. Check long-press does not trigger on
normal fast typing. Regression: Task 16 section 6 list. Commit:
"feat(keyboard): colourful Ayyzan theme, hint long-press, no number row".
