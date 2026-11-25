package com.voiceflow.ai.voiceflow_ai.services

import org.junit.Assert.assertEquals
import org.junit.Test

class PhoneticBanglaTest {

    @Test
    fun testRequiredCases() {
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
            "kii" to "কী"
        )

        for ((input, expected) in cases) {
            val actual = PhoneticBangla.convert(input)
            assertEquals("Failed for input '$input'", expected, actual)
        }
    }

    @Test
    fun testDigitsNotConverted() {
        assertEquals("12345", PhoneticBangla.convert("12345"))
        assertEquals("১২৩৪৫", PhoneticBangla.convert("১২৩৪৫"))
    }
}
