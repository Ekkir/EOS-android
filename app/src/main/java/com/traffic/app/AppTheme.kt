package com.traffic.app

import android.content.Context

data class ThemeDef(
    val id: String,
    val name: String,
    val bg: String,
    val surface: String,
    val nav: String,
    val accent: String,
    val textPrimary: String   = "#E8F4FF",
    val textSecondary: String = "#8AADCC",
    val cardBorder: String    = "#30FFFFFF",
    val isGlass: Boolean      = false,
)

object AppTheme {
    val themes = listOf(
        ThemeDef(
            "glass", "Стекло", "#0A1428", "#1EFFFFFF", "#CC0D1A36", "#56D4FF",
            textPrimary = "#EDF6FF", textSecondary = "#7BAFC8",
            cardBorder = "#48FFFFFF", isGlass = true,
        ),
        ThemeDef(
            "glassneon", "Стекло+Неон", "#0A002A", "#1ECC00FF", "#CC0A0025", "#CC00FF",
            textPrimary = "#F2E8FF", textSecondary = "#9A70BB",
            cardBorder = "#55CC00FF", isGlass = true,
        ),
        ThemeDef(
            "neon", "Неон", "#000000", "#0A0A0A", "#050505", "#00FFFF",
            textPrimary = "#FFFFFF", textSecondary = "#AAAAAA",
            cardBorder = "#8000FFFF",
        ),
        ThemeDef(
            "minimal", "Минимал", "#0C0C0C", "#141414", "#080808", "#DDDDDD",
            textPrimary = "#EEEEEE", textSecondary = "#666666",
            cardBorder = "#2A2A2A",
        ),
    )

    lateinit var current: ThemeDef
        private set

    fun load(ctx: Context) {
        val id = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
            .getString("theme_id", "glass") ?: "glass"
        current = themes.find { it.id == id } ?: themes[0]
    }

    fun apply(ctx: Context, id: String) {
        ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
            .edit().putString("theme_id", id).apply()
        current = themes.find { it.id == id } ?: themes[0]
    }
}
