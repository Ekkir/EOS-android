package com.traffic.app

import android.content.Context
import android.graphics.*
import android.view.View
import kotlin.math.cos
import kotlin.math.sin

data class LightState(val state: String, val remaining: Int, val toGreen: Int)

class RoadMapView(context: Context) : View(context) {

    private val bgColor       = Color.parseColor("#0d1117")
    private val roadColor     = Color.parseColor("#3a3a4a")
    private val centerColor   = Color.parseColor("#555566")
    private val approachColor = Color.parseColor("#2a2a3a")

    private val roadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = roadColor; strokeWidth = 90f
        strokeCap = Paint.Cap.BUTT; style = Paint.Style.STROKE
    }
    private val approachPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = approachColor; strokeWidth = 70f
        strokeCap = Paint.Cap.BUTT; style = Paint.Style.STROKE
        pathEffect = DashPathEffect(floatArrayOf(22f, 14f), 0f)
    }
    private val markingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#ffffff33"); strokeWidth = 5f
        style = Paint.Style.STROKE
        pathEffect = DashPathEffect(floatArrayOf(28f, 20f), 0f)
    }
    private val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE; textSize = 48f
        typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
    }
    private val timerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE; textSize = 34f
        typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
    }
    private val toGreenPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00e676"); textSize = 30f
        typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
    }
    private val fromLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#555577"); textSize = 30f
        typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER
    }
    private val lightPaint   = Paint(Paint.ANTI_ALIAS_FLAG)
    private val housePaint   = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#222233") }
    private val dimPaint     = Paint(Paint.ANTI_ALIAS_FLAG)
    private val centerPaint2 = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = centerColor }
    private val disconnectPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#ff4444"); textSize = 32f; textAlign = Paint.Align.CENTER
    }

    // viewpoint: ключ дороги, с которой едешь
    var viewpoint = "abaza"
        set(v) { field = v; invalidate() }

    // Triple: (угол градусы, ключ дороги, isApproach)
    // Угол 90=прямо(вверх), 0=вправо, 180=влево, 270=stub вниз (откуда едешь)
    // Вид с Абазы: Перевал прямо, Заречка вправо
    // Вид с Перевала: Абаза прямо, Заречка влево
    // Вид с Заречки: Перевал прямо, Абаза влево
    private val layouts = mapOf(
        // Из Абазы: Заречка влево, Перевал вправо
        "abaza"    to listOf(
            Triple(180.0, "zarechka", false),
            Triple(0.0,   "pereval",  false),
            Triple(270.0, "abaza",    true),
        ),
        // Из Перевала: Заречка прямо, Абаза влево
        "pereval"  to listOf(
            Triple(90.0,  "zarechka", false),
            Triple(180.0, "abaza",    false),
            Triple(270.0, "pereval",  true),
        ),
        // Из Заречки: Перевал прямо, Абаза вправо
        "zarechka" to listOf(
            Triple(90.0,  "pereval",  false),
            Triple(0.0,   "abaza",    false),
            Triple(270.0, "zarechka", true),
        ),
    )

    private val nameMap = mapOf("pereval" to "Перевал", "abaza" to "Абаза", "zarechka" to "Заречка")

    var lights = mapOf(
        "pereval"  to LightState("red", 0, 0),
        "abaza"    to LightState("red", 0, 0),
        "zarechka" to LightState("red", 0, 0)
    )
    var connected = false
    private var lastUpdateMs = 0L

    fun updateLights(newLights: Map<String, LightState>) {
        lights = newLights; connected = true; lastUpdateMs = System.currentTimeMillis(); invalidate()
    }
    fun setDisconnected() { connected = false; invalidate() }

    private fun elapsed() = if (lastUpdateMs > 0) ((System.currentTimeMillis() - lastUpdateMs) / 1000).toInt() else 0

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(bgColor)

        val cx = width / 2f
        val cy = height * 0.62f          // центр ниже середины — вид водителя
        val roadLen   = minOf(width, height) * 0.44f
        val stubLen   = roadLen * 0.38f   // длиннее, чтобы влез светофор
        val lightDist = roadLen * 0.52f

        val layout = layouts[viewpoint] ?: layouts["abaza"]!!

        // Дороги
        for ((angleDeg, _, isApproach) in layout) {
            val rad = Math.toRadians(angleDeg)
            val len = if (isApproach) stubLen else roadLen
            val ex  = cx + (len * cos(rad)).toFloat()
            val ey  = cy - (len * sin(rad)).toFloat()
            if (isApproach) {
                canvas.drawLine(cx, cy, ex, ey, approachPaint)
            } else {
                canvas.drawLine(cx, cy, ex, ey, roadPaint)
                canvas.drawLine(cx, cy, ex, ey, markingPaint)
            }
        }

        // Центральный круг (перекрёсток)
        canvas.drawCircle(cx, cy, 55f, centerPaint2)

        // Светофоры и подписи
        for ((angleDeg, roadKey, isApproach) in layout) {
            val rad   = Math.toRadians(angleDeg)
            val dist  = if (isApproach) stubLen * 0.60f else lightDist
            val lx    = cx + (dist * cos(rad)).toFloat()
            val ly    = cy - (dist * sin(rad)).toFloat()
            val light = lights[roadKey] ?: LightState("red", 0, 0)
            val name  = nameMap[roadKey] ?: roadKey

            if (isApproach) {
                // Светофор на дороге подъезда + название
                drawTrafficLight(canvas, lx, ly, angleDeg, light)
                val nameDist = stubLen * 0.96f
                val nx = cx + (nameDist * cos(rad)).toFloat()
                val ny = cy - (nameDist * sin(rad)).toFloat()
                canvas.drawText(name, nx, ny + namePaint.textSize / 3 + 14f, fromLabelPaint)
            } else {
                drawTrafficLight(canvas, lx, ly, angleDeg, light)
                val nameDist = roadLen * 0.85f
                val nx = cx + (nameDist * cos(rad)).toFloat()
                val ny = cy - (nameDist * sin(rad)).toFloat()
                val nameOffsetX = when {
                    angleDeg < 45 || angleDeg > 315 -> 70f
                    angleDeg in 135.0..225.0          -> -70f
                    else -> 0f
                }
                canvas.drawText(name, nx + nameOffsetX, ny + namePaint.textSize / 3, namePaint)
            }
        }

        if (!connected && lastUpdateMs > 0) {
            canvas.drawText("● нет связи — время расчётное", cx, height * 0.06f, disconnectPaint)
        } else if (!connected) {
            canvas.drawText("● нет связи с сервером", cx, height * 0.06f, disconnectPaint)
        }
    }

    private fun drawTrafficLight(canvas: Canvas, x: Float, y: Float, angleDeg: Double, light: LightState) {
        val w = 48f; val h = 136f; val r = 17f
        val rect = RectF(x - w, y - h / 2, x + w, y + h / 2)
        canvas.drawRoundRect(rect, 14f, 14f, housePaint)

        listOf(Pair(y - h / 2 + h / 6, "red"), Pair(y, "yellow"), Pair(y + h / 2 - h / 6, "green"))
            .forEach { (cy2, color) ->
                if (light.state == color) {
                    lightPaint.color = activeColor(color)
                    lightPaint.maskFilter = BlurMaskFilter(22f, BlurMaskFilter.Blur.NORMAL)
                    canvas.drawCircle(x, cy2, r + 4f, lightPaint)
                    lightPaint.maskFilter = null
                    canvas.drawCircle(x, cy2, r, lightPaint)
                } else {
                    dimPaint.color = dimColor(color)
                    canvas.drawCircle(x, cy2, r, dimPaint)
                }
            }

        val timerX = x
        val timerY = y + h / 2 + 40f
        val e = elapsed()
        val isOffline = !connected && e > 0
        val estRemaining = maxOf(0, light.remaining - e)
        val estToGreen   = maxOf(0, light.toGreen   - e)
        val prefix = if (isOffline) "~" else ""
        when (light.state) {
            "green", "yellow" -> if (light.remaining > 0) {
                timerPaint.alpha = if (isOffline) 180 else 255
                canvas.drawText("$prefix${estRemaining}с", timerX, timerY, timerPaint)
                timerPaint.alpha = 255
            }
            "red" -> if (light.toGreen > 0) {
                toGreenPaint.alpha = if (isOffline) 180 else 255
                canvas.drawText("зел. $prefix${estToGreen}с", timerX, timerY, toGreenPaint)
                toGreenPaint.alpha = 255
            }
        }
    }

    private fun activeColor(c: String) = when (c) {
        "red"    -> Color.parseColor("#ff2222")
        "yellow" -> Color.parseColor("#ffcc00")
        "green"  -> Color.parseColor("#00e676")
        else     -> Color.GRAY
    }
    private fun dimColor(c: String) = when (c) {
        "red"    -> Color.parseColor("#3a0a0a")
        "yellow" -> Color.parseColor("#3a3000")
        "green"  -> Color.parseColor("#0a2a0a")
        else     -> Color.DKGRAY
    }
}
