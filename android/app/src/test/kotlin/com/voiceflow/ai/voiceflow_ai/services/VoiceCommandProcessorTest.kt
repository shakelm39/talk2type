package com.voiceflow.ai.voiceflow_ai.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCommandProcessorTest {

    private fun t(session: String, segment: String) = VoiceCommandProcessor.apply(session, segment).text

    @Test fun inlinePunctuation() {
        assertEquals("আমি ভালো আছি। তুমি কেমন আছো?", t("", "আমি ভালো আছি দাঁড়ি তুমি কেমন আছো প্রশ্নবোধক"))
        assertEquals("hello world, how are you?", t("hello", "world comma how are you question mark"))
    }

    @Test fun newLine() {
        assertEquals("প্রথম লাইন\nদ্বিতীয় লাইন", t("", "প্রথম লাইন নতুন লাইন দ্বিতীয় লাইন"))
    }

    @Test fun deleteLastSentence() {
        assertEquals("আমি ভালো আছি।", t("আমি ভালো আছি। তুমি কেমন আছো?", "শেষ বাক্য মুছো"))
        assertEquals("এক। চার", t("এক। দুই", "তিন শেষ বাক্য মুছো চার"))
    }

    @Test fun clearAndFieldFallback() {
        assertEquals("", t("কিছু লেখা", "সব মুছো"))
        val r1 = VoiceCommandProcessor.apply("", "সব মুছো")
        assertTrue(r1.fieldClearLastDictation)
        val r2 = VoiceCommandProcessor.apply("", "শেষ বাক্য মুছো")
        assertEquals(1, r2.fieldSentenceDeletes)
    }

    @Test fun decomposedNuktaMatches() {
        // দাড়ি written with ড + nukta (as some recognisers output)
        assertEquals("ভাই।", t("ভাই", "দাড়ি"))
    }
}
