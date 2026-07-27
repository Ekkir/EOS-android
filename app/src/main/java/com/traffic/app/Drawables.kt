package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Outline
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.ImageView
import android.widget.LinearLayout

fun bgDrawable(theme: ThemeDef): Drawable {
    if (!theme.isGlass) return ColorDrawable(Color.parseColor(theme.bg))
    val (c1, c2) = when (theme.id) {
        "glassneon" -> Pair("#07001A", "#001407")
        "glass"     -> Pair("#3A2000", "#100800")
        else        -> Pair("#080F28", "#17082E")
    }
    return GradientDrawable(GradientDrawable.Orientation.TL_BR,
        intArrayOf(Color.parseColor(c1), Color.parseColor(c2)))
}

fun cardDrawable(theme: ThemeDef, cornerDp: Float, density: Float): Drawable =
    if (theme.isGlass) {
        val cr = cornerDp * density
        LayerDrawable(arrayOf(
            // тёмная прозрачная основа — фон просвечивает сквозь стекло
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = cr
                setColor(Color.argb(50, 0, 0, 0))
            },
            // световой блик сверху — отражение света
            GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(
                Color.argb(90, 255, 255, 255),
                Color.argb(0,  255, 255, 255),
            )).apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = cr
            },
            // диагональный отблеск TL→BR
            GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(
                Color.argb(30, 255, 255, 255),
                Color.argb(0,  255, 255, 255),
            )).apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = cr
            },
            // яркая светящаяся граница — как на реальном стекле
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = cr
                setColor(Color.TRANSPARENT)
                setStroke((2 * density).toInt(), Color.argb(190, 255, 255, 255))
            },
        ))
    } else {
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = cornerDp * density
            setColor(Color.parseColor(theme.surface))
            setStroke(2, Color.parseColor(theme.cardBorder))
        }
    }

fun hexAlpha(hex: String, alpha: Int): Int {
    val c = Color.parseColor(hex)
    return Color.argb(alpha, Color.red(c), Color.green(c), Color.blue(c))
}

fun statusBarHeight(ctx: Context): Int {
    val id = ctx.resources.getIdentifier("status_bar_height", "dimen", "android")
    return if (id > 0) ctx.resources.getDimensionPixelSize(id) else 0
}

fun miniAvatarView(ctx: Context, dp: Float, theme: ThemeDef, onTap: () -> Unit): ImageView {
    val size = (36 * dp).toInt()
    return ImageView(ctx).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        clipToOutline = true
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(v: View, outline: Outline) { outline.setOval(0, 0, v.width, v.height) }
        }
        background = ColorDrawable(hexAlpha(theme.accent, 30))
        layoutParams = LinearLayout.LayoutParams(size, size)
        MainActivity.loadAvatarBitmap(ctx)?.let { setImageBitmap(it) }
        setOnClickListener { onTap() }
    }
}

fun accentBox(theme: ThemeDef, density: Float, cornerDp: Float = 8f): GradientDrawable =
    GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = cornerDp * density
        setColor(hexAlpha(theme.accent, 30))
    }
