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
            "glassneon", "Стекло+Неон", "#0A002A", "#1ECC00FF", "#CC0A0025", "#CC00FF",
            textPrimary = "#F2E8FF", textSecondary = "#9A70BB",
            cardBorder = "#55CC00FF", isGlass = true,
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
        val prefs = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val id = prefs.getString("theme_id", "glass") ?: "glass"
        val base = themes.find { it.id == id } ?: themes.find { it.id == "minimal" } ?: themes[0]
        val customAccent = prefs.getString("accent_$id", null)
        current = if (customAccent != null) base.copy(accent = customAccent) else base
    }

    fun apply(ctx: Context, id: String) {
        ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
            .edit().putString("theme_id", id).apply()
        load(ctx)
    }
}
