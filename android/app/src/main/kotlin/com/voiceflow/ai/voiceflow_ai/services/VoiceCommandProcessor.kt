package com.voiceflow.ai.voiceflow_ai.services

/**
 * Pure text processor for spoken voice commands (no Android types -> JVM unit-testable).
 *
 * Commands are recognised anywhere inside a recognised segment (not only at the end):
 *   নতুন লাইন -> "\n", দাঁড়ি -> "।", কমা -> ",", প্রশ্নবোধক -> "?", আশ্চর্যবোধক -> "!",
 *   শেষ বাক্য মুছো -> removes the last sentence of the current dictation,
 *   সব মুছো -> clears the current dictation.
 * When the current dictation is already empty, delete/clear are reported back so the
 * keyboard can act on the text field (last sentence / last dictation only).
 */
object VoiceCommandProcessor {

    data class Result(
        val text: String,
        val commandCount: Int,
        val fieldSentenceDeletes: Int,
        val fieldClearLastDictation: Boolean
    )

    private enum class Cmd { NEW_LINE, DARI, COMMA, QUESTION, EXCLAMATION, DELETE_SENTENCE, CLEAR }

    private val TABLE: List<Pair<Cmd, List<String>>> = listOf(
        Cmd.NEW_LINE to listOf("নতুন লাইন", "নতুন প্যারা", "নিউ লাইন", "new line", "newline"),
        Cmd.DARI to listOf("দাঁড়ি", "দাড়ি", "পূর্ণচ্ছেদ", "ফুলস্টপ", "full stop"),
        Cmd.COMMA to listOf("কমা", "comma"),
        Cmd.QUESTION to listOf("প্রশ্নবোধক চিহ্ন", "প্রশ্নবোধক", "প্রশ্নচিহ্ন", "question mark"),
        Cmd.EXCLAMATION to listOf("আশ্চর্যবোধক চিহ্ন", "আশ্চর্যবোধক", "বিস্ময়সূচক চিহ্ন", "exclamation mark"),
        Cmd.DELETE_SENTENCE to listOf(
            "শেষ বাক্য মুছে দাও", "শেষ বাক্য মুছো", "শেষ বাক্য মুছুন", "শেষ বাক্য ডিলিট",
            "আগের বাক্য মুছে দাও", "আগের বাক্য মুছো", "delete last sentence"
        ),
        Cmd.CLEAR to listOf("সব মুছে দাও", "সব মুছো", "সব মুছুন", "সব ডিলিট", "clear all", "delete all")
    )

    private const val STRIP = ".,।?!"
    private const val SENTENCE_END = "।?!.\n"

    /** Unicode-normalise nukta letters (ড় ঢ় য়) and lower-case, so recogniser variants match. */
    private fun norm(s: String): String = s
        .replace("ড়", "ড়")
        .replace("ঢ়", "ঢ়")
        .replace("য়", "য়")
        .lowercase()

    private val TRIGGERS: List<Pair<List<String>, Cmd>> = TABLE
        .flatMap { (cmd, list) -> list.map { t -> t.split(" ").map { norm(it) } to cmd } }
        .sortedByDescending { it.first.size }

    private fun punct(cmd: Cmd): String? = when (cmd) {
        Cmd.DARI -> "।"
        Cmd.COMMA -> ","
        Cmd.QUESTION -> "?"
        Cmd.EXCLAMATION -> "!"
        else -> null
    }

    private fun joinWord(buf: String, word: String): String =
        if (buf.isEmpty() || buf.endsWith("\n")) buf + word else "$buf $word"

    fun deleteLastSentence(buf: String): String {
        val t = buf.trimEnd(' ')
        if (t.isEmpty()) return ""
        if (t.endsWith("\n")) return t.dropLast(1)
        val body = t.trimEnd { it in "।?!." }
        val idx = body.indexOfLast { it in SENTENCE_END }
        return if (idx >= 0) body.substring(0, idx + 1) else ""
    }

    /** Quick check used for Free users (commands are Pro-only). */
    fun containsCommand(segment: String): Boolean =
        apply("", segment).commandCount > 0

    fun apply(session: String, segment: String): Result {
        val words = segment.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val normWords = words.map { norm(it).trim { c -> c in STRIP } }
        var buf = session
        var commands = 0
        var fieldDeletes = 0
        var fieldClear = false
        var i = 0
        while (i < words.size) {
            var hit: Pair<Cmd, Int>? = null
            for ((tw, cmd) in TRIGGERS) {
                val n = tw.size
                if (i + n <= words.size && normWords.subList(i, i + n) == tw) {
                    hit = cmd to n
                    break
                }
            }
            if (hit != null) {
                val (cmd, n) = hit
                commands++
                i += n
                val p = punct(cmd)
                when {
                    cmd == Cmd.NEW_LINE -> buf = buf.trimEnd(' ') + "\n"
                    p != null -> {
                        val b = buf.trimEnd(' ')
                        if (b.isNotEmpty() && !b.endsWith("\n")) buf = b.trimEnd { it in STRIP } + p
                    }
                    cmd == Cmd.DELETE_SENTENCE -> {
                        if (buf.isNotBlank()) buf = deleteLastSentence(buf) else fieldDeletes++
                    }
                    cmd == Cmd.CLEAR -> {
                        if (buf.isNotBlank()) buf = "" else fieldClear = true
                    }
                }
                continue
            }
            buf = joinWord(buf, words[i])
            i++
        }
        return Result(buf, commands, fieldDeletes, fieldClear)
    }
}
