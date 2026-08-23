package com.fryfrog.hub.ui.music

/**
 * 歌词解析：支持标准 LRC 时间戳（[mm:ss.xx] / [mm:ss.xxx]，可多标签），无时间戳行按纯文本展示。
 */
data class LyricLine(
    val timeMs: Long?,
    val text: String
)

object LyricsParser {

    private val tagRegex = Regex("""\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]""")

    fun parse(raw: String): List<LyricLine> {
        if (raw.isBlank()) return emptyList()
        val lines = mutableListOf<LyricLine>()
        raw.lines().forEach { original ->
            val text = original.trim()
            if (text.isEmpty()) return@forEach
            val matches = tagRegex.findAll(text).toList()
            if (matches.isEmpty()) {
                // 无时间戳的纯文本行（或元数据标签，过滤常见 key:value）
                if (!text.startsWith("[") || !text.contains("]")) {
                    lines.add(LyricLine(null, cleanText(text)))
                } else {
                    val content = text.substringAfterLast(']').trim()
                    if (content.isNotEmpty()) lines.add(LyricLine(null, content))
                }
            } else {
                val content = cleanText(text.substringAfterLast(']').trim())
                matches.forEach { m ->
                    val minutes = m.groupValues[1].toLong()
                    val seconds = m.groupValues[2].toLong()
                    val fracStr = m.groupValues[3]
                    val fractionMs = when (fracStr.length) {
                        0 -> 0L
                        1 -> fracStr.toLong() * 100
                        2 -> fracStr.toLong() * 10
                        else -> fracStr.take(3).toLong()
                    }
                    lines.add(LyricLine(minutes * 60_000 + seconds * 1000 + fractionMs, content))
                }
            }
        }
        return lines.sortedWith(compareBy(nullsFirst()) { it.timeMs })
    }

    /** 定位当前播放位置对应的歌词下标；无时间戳返回 -1 */
    fun activeIndex(lines: List<LyricLine>, positionMs: Long): Int {
        var result = -1
        for (i in lines.indices) {
            val t = lines[i].timeMs ?: continue
            if (t <= positionMs) result = i else break
        }
        return result
    }

    private fun cleanText(text: String): String = when {
        text.isEmpty() -> ""
        text.startsWith("ti:", true) || text.startsWith("ar:", true) ||
            text.startsWith("al:", true) || text.startsWith("by:", true) ||
            text.startsWith("offset", true) -> ""
        else -> text
    }

    private fun <T : Comparable<T>> nullsFirst(): Comparator<T?> =
        Comparator { a, b ->
            when {
                a == null && b == null -> 0
                a == null -> -1
                b == null -> 1
                else -> a.compareTo(b)
            }
        }
}
