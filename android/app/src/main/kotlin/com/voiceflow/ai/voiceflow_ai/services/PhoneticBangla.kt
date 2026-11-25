package com.voiceflow.ai.voiceflow_ai.services

/**
 * PhoneticBangla - Avro-style phonetic Latin -> Bangla transliteration (pure Kotlin).
 *
 * Written from scratch for Talk2Type (no third-party code copied). Conventions follow the
 * widely known Avro Phonetic typing habits so Bangladeshi users feel at home:
 *  - vowel after a consonant -> kar (a=া i=ি I/ii/ee=ী u=ু U/uu/oo=ূ/ু e=ে oi=ৈ O=ো ou=ৌ rri=ৃ)
 *  - 'o' after a consonant = inherent vowel (nothing), except at word end -> ো
 *  - 'o' at word start -> অ, after another vowel -> ও
 *  - consonant + y -> য-ফলা (্য), consonant + r -> র-ফলা (্র), consonant + w -> ব-ফলা (্ব)
 *  - explicit conjunct table (longest match first): nd ন্দ, kt ক্ত, st স্ত, ShT ষ্ট ...
 *  - case-sensitive letters: T D R N Sh O I U E Ng NG; other capitals act as lowercase
 * Digits and symbols pass through unchanged.
 * License: MIT (Ayyzan / Talk2Type)
 */
object PhoneticBangla {

    private val VOWELS_DEP = listOf(
        "rri" to "ৃ",
        "ii" to "ী",
        "ee" to "ী",
        "aa" to "া",
        "uu" to "ূ",
        "oo" to "ু",
        "oi" to "ৈ",
        "ou" to "ৌ",
        "a" to "া",
        "i" to "ি",
        "I" to "ী",
        "u" to "ু",
        "U" to "ূ",
        "e" to "ে",
        "E" to "ে",
        "O" to "ো"
    )

    private val VOWELS_INDEP = listOf(
        "rri" to "ঋ",
        "ii" to "ঈ",
        "ee" to "ঈ",
        "aa" to "আ",
        "uu" to "ঊ",
        "oo" to "উ",
        "oi" to "ঐ",
        "ou" to "ঔ",
        "a" to "আ",
        "i" to "ই",
        "I" to "ঈ",
        "u" to "উ",
        "U" to "ঊ",
        "e" to "এ",
        "E" to "এ",
        "o" to "অ",
        "O" to "ও"
    )

    /** Sorted longest-first so e.g. "shch" wins over "sh". */
    private val CONSONANTS = listOf(
        "shch" to "শ্চ",
        "ShTh" to "ষ্ঠ",
        "chch" to "চ্চ",
        "kSh" to "ক্ষ",
        "kkh" to "ক্ষ",
        "chh" to "ছ",
        "ggy" to "জ্ঞ",
        "t``" to "ৎ",
        "ndh" to "ন্ধ",
        "nth" to "ন্থ",
        "nch" to "ঞ্চ",
        "ngk" to "ঙ্ক",
        "ngg" to "ঙ্গ",
        "sth" to "স্থ",
        "ShT" to "ষ্ট",
        "ShN" to "ষ্ণ",
        "shT" to "শ্ট",
        "gdh" to "গ্ধ",
        "tth" to "ত্থ",
        "ddh" to "দ্ধ",
        "bh" to "ভ",
        "kh" to "খ",
        "gh" to "ঘ",
        "ch" to "চ",
        "jh" to "ঝ",
        "Th" to "ঠ",
        "th" to "থ",
        "Dh" to "ঢ",
        "dh" to "ধ",
        "ph" to "ফ",
        "sh" to "শ",
        "Sh" to "ষ",
        "rh" to "ঢ়",
        "ng" to "ং",
        "Ng" to "ঙ",
        "NG" to "ঞ",
        "gg" to "জ্ঞ",
        "nd" to "ন্দ",
        "nt" to "ন্ত",
        "nT" to "ন্ট",
        "nD" to "ন্ড",
        "nn" to "ন্ন",
        "nm" to "ন্ম",
        "mp" to "ম্প",
        "mb" to "ম্ব",
        "mm" to "ম্ম",
        "ml" to "ম্ল",
        "nj" to "ঞ্জ",
        "st" to "স্ত",
        "sT" to "স্ট",
        "sp" to "স্প",
        "sk" to "স্ক",
        "sm" to "স্ম",
        "sn" to "স্ন",
        "kk" to "ক্ক",
        "kt" to "ক্ত",
        "km" to "ক্ম",
        "kl" to "ক্ল",
        "ks" to "ক্স",
        "gn" to "গ্ন",
        "gm" to "গ্ম",
        "gl" to "গ্ল",
        "jj" to "জ্জ",
        "TT" to "ট্ট",
        "DD" to "ড্ড",
        "tt" to "ত্ত",
        "tm" to "ত্ম",
        "tn" to "ত্ন",
        "dd" to "দ্দ",
        "db" to "দ্ব",
        "dm" to "দ্ম",
        "pt" to "প্ত",
        "pp" to "প্প",
        "pl" to "প্ল",
        "bb" to "ব্ব",
        "bd" to "ব্দ",
        "bl" to "ব্ল",
        "ll" to "ল্ল",
        "lk" to "ল্ক",
        "lp" to "ল্প",
        "k" to "ক",
        "g" to "গ",
        "c" to "চ",
        "j" to "জ",
        "T" to "ট",
        "t" to "ত",
        "D" to "ড",
        "d" to "দ",
        "p" to "প",
        "f" to "ফ",
        "b" to "ব",
        "m" to "ম",
        "z" to "য",
        "r" to "র",
        "l" to "ল",
        "s" to "স",
        "h" to "হ",
        "R" to "ড়",
        "N" to "ণ",
        "n" to "ন",
        "v" to "ভ",
        "q" to "ক",
        "x" to "ক্স"
    )

    private const val CASE_SENSITIVE = "TDRNSOIUEG"

    private fun normalize(s: String): String {
        val sb = StringBuilder(s.length)
        for (ch in s) sb.append(if (ch.isUpperCase() && ch !in CASE_SENSITIVE) ch.lowercaseChar() else ch)
        return sb.toString()
    }

    fun convert(raw: String): String {
        if (raw.isEmpty()) return ""
        val s = normalize(raw)
        val out = StringBuilder()
        var i = 0
        var lastWasConsonant = false

        while (i < s.length) {
            val c = s[i]
            if (lastWasConsonant) {
                val kar = VOWELS_DEP.firstOrNull { s.startsWith(it.first, i) }
                if (kar != null) {
                    out.append(kar.second); i += kar.first.length; lastWasConsonant = false; continue
                }
                if (c == 'o') {
                    val next = if (i + 1 < s.length) s[i + 1] else ' '
                    if (!next.isLetter()) out.append("ো") // word-final o
                    i++; lastWasConsonant = false; continue
                }
                if (c == 'y') { out.append("্য"); i++; lastWasConsonant = true; continue }
                if (c == 'r' && !s.startsWith("rri", i) && !s.startsWith("rh", i)) {
                    out.append("্র"); i++; lastWasConsonant = true; continue
                }
                if (c == 'w') { out.append("্ব"); i++; lastWasConsonant = true; continue }
            }

            if (c == '^') { out.append("ঁ"); i++; continue }

            val cons = CONSONANTS.firstOrNull { s.startsWith(it.first, i) }
            if (cons != null) {
                out.append(cons.second); i += cons.first.length
                lastWasConsonant = cons.second != "ং" && cons.second != "ৎ"
                continue
            }

            if (c == 'o' && i > 0 && s[i - 1].isLetter() &&
                !s.startsWith("oo", i) && !s.startsWith("oi", i) && !s.startsWith("ou", i)) {
                out.append("ও"); i++; lastWasConsonant = false; continue
            }

            val vowel = VOWELS_INDEP.firstOrNull { s.startsWith(it.first, i) }
            if (vowel != null) {
                out.append(vowel.second); i += vowel.first.length; lastWasConsonant = false; continue
            }

            if (c == 'y') { out.append("য়"); i++; lastWasConsonant = true; continue }
            if (c == 'w') { out.append("ও"); i++; lastWasConsonant = false; continue }

            out.append(c); i++; lastWasConsonant = false
        }
        return out.toString()
    }
}
