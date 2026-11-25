package com.voiceflow.ai.voiceflow_ai.services

/**
 * PhoneticBangla - Pure Kotlin Avro-compatible phonetic transliteration engine.
 *
 * Implements rule-based Latin-to-Bangla phonetic mapping (longest-match first)
 * with Avro-compatible conventions:
 * - Digits are passed through unconverted (managed by the number row).
 * - Independent vowels at word start or after another vowel.
 * - Dependent vowel signs (kar) after consonants.
 * - Inherent vowel 'o' suppressed internally, explicit 'ো' at word end or via 'O'.
 *
 * Author: Talk2Type / Ayyzan
 * License: MIT
 */
object PhoneticBangla {

    private val VOWELS_INDEP = listOf(
        "ii" to "ঈ",
        "ee" to "ঈ",
        "aa" to "আ",
        "uu" to "ঊ",
        "oo" to "উ",
        "oi" to "ঐ",
        "ou" to "ঔ",
        "a" to "আ",
        "A" to "অ",
        "i" to "ই",
        "I" to "ঈ",
        "u" to "উ",
        "U" to "ঊ",
        "e" to "এ",
        "E" to "এ",
        "o" to "অ",
        "O" to "ও"
    )

    private val VOWELS_DEP = listOf(
        "ii" to "ী",
        "ee" to "ী",
        "aa" to "া",
        "uu" to "ূ",
        "oo" to "ু",
        "oi" to "ৈ",
        "ou" to "ৌ",
        "a" to "া",
        "A" to "া",
        "i" to "ি",
        "I" to "ী",
        "u" to "ু",
        "U" to "ূ",
        "e" to "ে",
        "E" to "ে",
        "O" to "ো"
    )

    // Longest match first: conjuncts and compound consonants
    private val CONSONANTS = listOf(
        "kSh" to "ক্ষ",
        "kkh" to "ক্ষ",
        "chho" to "ছো",
        "chh" to "ছ",
        "bhy" to "ভ্য",
        "bh" to "ভ",
        "khy" to "খ্য",
        "kh" to "খ",
        "ghy" to "ঘ্য",
        "gh" to "ঘ",
        "chy" to "চ্য",
        "ch" to "চ",
        "jhy" to "ঝ্য",
        "jh" to "ঝ",
        "Thy" to "ঠ্য",
        "Th" to "ঠ",
        "thy" to "থ্য",
        "th" to "থ",
        "Dhy" to "ঢ্য",
        "Dh" to "ঢ",
        "dhy" to "ধ্য",
        "dh" to "ধ",
        "phy" to "ফ্য",
        "ph" to "ফ",
        "shy" to "শ্য",
        "sh" to "শ",
        "Shy" to "ষ্য",
        "Sh" to "ষ",
        "rhy" to "ঢ়্য",
        "rh" to "ঢ়",
        "ng" to "ং",
        "ggy" to "জ্ঞ",
        "gdh" to "গ্ধ",
        "ndh" to "ন্ধ",
        "nd" to "ন্দ",
        "nt" to "ন্ত",
        "mp" to "ম্প",
        "mb" to "ম্ব",
        "nch" to "ঞ্চ",
        "nj" to "ঞ্জ",
        "st" to "স্ত",
        "sp" to "স্প",
        "sk" to "স্ক",
        "shch" to "শ্চ",
        "ShTh" to "ষ্ঠ",
        "shT" to "স্ট",
        "ny" to "ন্য",
        "dy" to "দ্য",
        "my" to "ম্য",
        "by" to "ব্য",
        "ty" to "ত্য",
        "py" to "প্য",
        "sy" to "স্য",
        "hy" to "হ্য",
        "gy" to "গ্য",
        "ky" to "ক্য",
        "tr" to "ত্র",
        "pr" to "প্র",
        "gr" to "গ্র",
        "kr" to "ক্র",
        "br" to "ব্র",
        "dr" to "দ্র",
        "shr" to "শ্র",
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
        "y" to "য়",
        "N" to "ণ",
        "n" to "ন"
    )

    /**
     * Converts an English phonetic representation into Bangla script.
     * Digits and unknown symbols pass through unmodified.
     */
    fun convert(input: String): String {
        if (input.isEmpty()) return ""

        val sb = StringBuilder()
        var i = 0
        val n = input.length
        var lastWasConsonant = false

        while (i < n) {
            // 1. If preceding token was a consonant, look for dependent vowel signs (kar) or 'o'
            if (lastWasConsonant) {
                var matchedVowel = false
                for ((vStr, vKar) in VOWELS_DEP) {
                    if (input.startsWith(vStr, i)) {
                        sb.append(vKar)
                        i += vStr.length
                        matchedVowel = true
                        lastWasConsonant = false
                        break
                    }
                }
                if (matchedVowel) continue

                // Check lowercase 'o'
                if (input.startsWith("o", i)) {
                    val rem = input.substring(i + 1)
                    if (rem.isEmpty() || !rem[0].isLetter()) {
                        // Word-final 'o' gives o-kar 'ো'
                        sb.append("ো")
                    }
                    // Otherwise it's inherent vowel (no kar added)
                    i++
                    lastWasConsonant = false
                    continue
                }
            }

            // 2. Check consonants / conjuncts (longest match first)
            var matchedC = false
            for ((cStr, cChar) in CONSONANTS) {
                if (input.startsWith(cStr, i)) {
                    sb.append(cChar)
                    i += cStr.length
                    matchedC = true
                    lastWasConsonant = true
                    break
                }
            }
            if (matchedC) continue

            // 3. Check independent vowels
            var matchedIv = false
            for ((vStr, vIndep) in VOWELS_INDEP) {
                if (input.startsWith(vStr, i)) {
                    sb.append(vIndep)
                    i += vStr.length
                    matchedIv = true
                    lastWasConsonant = false
                    break
                }
            }
            if (matchedIv) continue

            // 4. Pass-through (digits, spaces, punctuations, etc.)
            sb.append(input[i])
            i++
            lastWasConsonant = false
        }

        return sb.toString()
    }
}
