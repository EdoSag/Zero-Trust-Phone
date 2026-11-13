package dev.sagron.zerotrustphone

/**
 * Hide my number for one call (P22). A third-party Phone app can't change
 * the SIM's caller ID setting, but it can dial the carrier's per-call code
 * in front of the number, which the phone's own telephony turns into a
 * "withhold caller ID" request: `#31#` on GSM / LTE networks (Israel,
 * Europe and most of the world), `*67` in the US and Canada. The carrier
 * decides in the end; emergency and service numbers always show.
 */
object CallerId {
    fun hide(number: String, simCountry: String?): String {
        val trimmed = number.trim()
        // Service codes ("*2700", "#31#…") and short numbers are left alone.
        if (trimmed.startsWith("*") || trimmed.startsWith("#")) return trimmed
        val main = trimmed.substringBefore(',').substringBefore(';')
        if (main.count { it.isDigit() } < 5) return trimmed
        val code = when (simCountry?.lowercase()) {
            "us", "ca" -> "*67"
            else -> "#31#"
        }
        return code + trimmed
    }
}
