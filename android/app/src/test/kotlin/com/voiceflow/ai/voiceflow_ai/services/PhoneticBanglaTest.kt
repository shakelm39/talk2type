package com.voiceflow.ai.voiceflow_ai.services

import org.junit.Assert.assertEquals
import org.junit.Test

class PhoneticBanglaTest {

    @Test
    fun testCommonWords() {
        val cases = listOf(
            "ami" to "আমি",
            "tumi" to "তুমি",
            "bangla" to "বাংলা",
            "kemon" to "কেমন",
            "achhi" to "আছি",
            "bhalo" to "ভালো",
            "ki" to "কি",
            "korchho" to "করছো",
            "dhonyobad" to "ধন্যবাদ",
            "sokal" to "সকাল",
            "rat" to "রাত",
            "Taka" to "টাকা",
            "kSh" to "ক্ষ",
            "bidyaloy" to "বিদ্যালয়",
            "amar" to "আমার",
            "tOmar" to "তোমার",
            "ii" to "ঈ",
            "kii" to "কী",
            "bondhu" to "বন্ধু",
            "prem" to "প্রেম",
            "kotha" to "কথা",
            "korbo" to "করবো",
            "korte" to "করতে",
            "achho" to "আছো",
            "dekha" to "দেখা",
            "onek" to "অনেক",
            "kaj" to "কাজ",
            "ekhon" to "এখন",
            "ebong" to "এবং",
            "bhai" to "ভাই",
            "Ami" to "আমি",
            "dao" to "দাও",
            "khao" to "খাও",
            "bhaiya" to "ভাইয়া",
            "hoy" to "হয়",
            "biye" to "বিয়ে",
            "shokti" to "শক্তি",
            "bangladesh" to "বাংলাদেশ",
            "kemon achho" to "কেমন আছো",
            "sundor" to "সুন্দর",
            "kintu" to "কিন্তু",
            "biggan" to "বিজ্ঞান",
            // Conjuncts (যুক্তাক্ষর) test cases
            "proshno" to "প্রশ্ন",
            "brahmoN" to "ব্রাহ্মণ",
            "chinho" to "চিহ্ন",
            "jihwa" to "জিহ্বা",
            "bashpo" to "বাষ্প",
            "sombhob" to "সম্ভব",
            "stobdho" to "স্তব্ধ",
            "balti" to "বালতি",
            "sUkkhmo" to "সূক্ষ্ম",
            "r+m" to "র্ম",
            "r+t" to "র্ত",
            "k+t" to "ক্ত",
            "k+k" to "ক্ক",
            "b+dh" to "ব্ধ",
            "h+m" to "হ্ম",
            "s+t" to "স্ত",
            "r+k" to "র্ক",
            "du:kh" to "দুঃখ",
            "muktizuddho" to "মুক্তিযুদ্ধ",
        )
        for ((input, expected) in cases) {
            assertEquals("Failed for input '$input'", expected, PhoneticBangla.convert(input))
        }
    }

    @Test
    fun testDigitsNotConverted() {
        assertEquals("12345", PhoneticBangla.convert("12345"))
        assertEquals("১২৩৪৫", PhoneticBangla.convert("১২৩৪৫"))
    }
}
