package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class CalibrationFragment : Fragment() {

    private val executor = Executors.newSingleThreadExecutor()
    private val handler  = Handler(Looper.getMainLooper())
    private val prefs    get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = prefs.getString("server_url", "http://eos-traffic.ddns.net:5000")!!

    private val nameMap  = mapOf("pereval" to "Перевал", "abaza" to "Абаза", "zarechka" to "Заречка")
    private val colorMap = mapOf("pereval" to "#00c853", "abaza" to "#2979ff", "zarechka" to "#ff6d00")

    private val currentOrder = mutableListOf("pereval", "abaza", "zarechka")
    private val greenInputs  = mutableMapOf<String, EditText>()
    private val yellowInputs = mutableMapOf<String, EditText>()
    private val redDisplays  = mutableMapOf<String, TextView>()
    private lateinit var pauseInput: EditText
    private lateinit var cycleText: TextView
    private lateinit var roadContainer: LinearLayout
    private lateinit var startRow: LinearLayout


    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = bgDrawable(t)
        }

        // Шапка с кнопкой назад
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor(t.nav))
            setPadding((16 * dp).toInt(), (12 * dp).toInt() + statusBarHeight(ctx), (16 * dp).toInt(), (12 * dp).toInt())
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "Светофоры"; textSize = 19f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            setPadding((12 * dp).toInt(), 0, 0, 0)
        })
        root.addView(header)

        root.addView(buildTrafficContent(ctx, t, dp))

        loadConfig()
        return root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }

    // ── Светофоры ─────────────────────────────────────────────────────────────
    private fun buildTrafficContent(ctx: Context, t: ThemeDef, dp: Float): ScrollView {
        val scroll = ScrollView(ctx).apply { if (!t.isGlass) setBackgroundColor(Color.parseColor(t.bg)) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (24 * dp).toInt(), (20 * dp).toInt(), (48 * dp).toInt())
        }
        scroll.addView(layout)

        layout.addView(sectionLabel(ctx, "Калибровка светофоров", t, dp))
        layout.addView(spacer(ctx, dp, 12f))

        roadContainer = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        layout.addView(roadContainer)

        layout.addView(spacer(ctx, dp, 24f))
        layout.addView(sectionLabel(ctx, "Задержка (все красные)", t, dp))
        layout.addView(spacer(ctx, dp, 12f))

        val pauseCard = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
        }
        pauseInput = editInput(ctx, t, dp, "Секунды")
        pauseCard.addView(inputRow(ctx, t, dp, "⏸", "Пауза", pauseInput))
        layout.addView(pauseCard)

        layout.addView(spacer(ctx, dp, 20f))
        cycleText = TextView(ctx).apply {
            textSize = 13f; setTextColor(Color.parseColor(t.textSecondary))
            setPadding(0, 0, 0, (8 * dp).toInt())
        }
        layout.addView(cycleText)

        layout.addView(sectionLabel(ctx, "Начать с зелёного", t, dp))
        layout.addView(spacer(ctx, dp, 12f))

        startRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        layout.addView(startRow)
        layout.addView(spacer(ctx, dp, 24f))

        layout.addView(Button(ctx).apply {
            text = "Применить"; textSize = 17f
            setTextColor(Color.parseColor(t.bg)); isAllCaps = false
            typeface = Typeface.DEFAULT_BOLD
            setBackgroundColor(Color.parseColor(t.accent))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 14f * dp
                setColor(Color.parseColor(t.accent))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt()
            )
            setOnClickListener { applyConfig(this) }
        })

        return scroll
    }


    // ── Рендеры дорог ─────────────────────────────────────────────────────────
    private fun renderRoads() {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density
        roadContainer.removeAllViews()
        currentOrder.forEachIndexed { index, key ->
            val name  = nameMap[key] ?: key
            val color = colorMap[key] ?: "#ffffff"

            val card = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.bottomMargin = (10 * dp).toInt() }
                background = cardDrawable(t, 16f, dp)
            }

            val headerRow = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                setPadding(0, 0, 0, (10 * dp).toInt())
            }
            headerRow.addView(TextView(ctx).apply {
                text = name; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(color))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })
            val btnUp = Button(ctx).apply {
                text = "↑"; textSize = 15f; setTextColor(Color.parseColor(t.textPrimary))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE; cornerRadius = 8f * dp
                    setColor(hexAlpha(t.textSecondary, 40))
                }
                layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (36 * dp).toInt()).also {
                    it.marginEnd = (8 * dp).toInt()
                }
                isEnabled = index > 0; alpha = if (index > 0) 1f else 0.3f
            }
            btnUp.setOnClickListener {
                currentOrder.removeAt(index); currentOrder.add(index - 1, key)
                renderRoads(); renderStartButtons()
            }
            val btnDown = Button(ctx).apply {
                text = "↓"; textSize = 15f; setTextColor(Color.parseColor(t.textPrimary))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE; cornerRadius = 8f * dp
                    setColor(hexAlpha(t.textSecondary, 40))
                }
                layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (36 * dp).toInt())
                isEnabled = index < currentOrder.size - 1
                alpha = if (index < currentOrder.size - 1) 1f else 0.3f
            }
            btnDown.setOnClickListener {
                currentOrder.removeAt(index); currentOrder.add(index + 1, key)
                renderRoads(); renderStartButtons()
            }
            headerRow.addView(btnUp); headerRow.addView(btnDown)
            card.addView(headerRow)

            if (!greenInputs.containsKey(key)) {
                greenInputs[key]  = editInput(ctx, t, dp, "сек")
                yellowInputs[key] = editInput(ctx, t, dp, "сек")
                val w = makeWatcher()
                greenInputs[key]!!.addTextChangedListener(w)
                yellowInputs[key]!!.addTextChangedListener(w)
            }
            // redDisplays всегда пересоздаётся — это только отображение, не ввод
            val redText = TextView(ctx).apply {
                textSize = 13f; setTextColor(Color.parseColor("#ff6666"))
                setPadding(0, (4 * dp).toInt(), 0, 0)
            }
            redDisplays[key] = redText

            // Detach EditTexts от старого parent перед повторным добавлением
            val greenInput  = greenInputs[key]!!
            val yellowInput = yellowInputs[key]!!
            (greenInput.parent  as? android.view.ViewGroup)?.removeView(greenInput)
            (yellowInput.parent as? android.view.ViewGroup)?.removeView(yellowInput)

            card.addView(inputRow(ctx, t, dp, "🟢", "Зелёный", greenInput))
            card.addView(inputRow(ctx, t, dp, "🟡", "Жёлтый", yellowInput))
            card.addView(redText)
            roadContainer.addView(card)
        }
        recalculate()
    }

    private fun renderStartButtons() {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density
        startRow.removeAllViews()
        currentOrder.forEachIndexed { i, key ->
            val btn = Button(ctx).apply {
                text = nameMap[key]; textSize = 13f
                setTextColor(Color.parseColor(t.bg)); isAllCaps = false
                typeface = Typeface.DEFAULT_BOLD
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
                    setColor(Color.parseColor(colorMap[key] ?: "#444444"))
                }
                layoutParams = LinearLayout.LayoutParams(0, (48 * dp).toInt(), 1f).also {
                    it.marginEnd = if (i < currentOrder.size - 1) (8 * dp).toInt() else 0
                }
            }
            btn.setOnClickListener { sendReset(key, btn) }
            startRow.addView(btn)
        }
    }

    private fun recalculate() {
        val pause  = pauseInput.text.toString().toIntOrNull() ?: 0
        val greens = currentOrder.associateWith { greenInputs[it]?.text?.toString()?.toIntOrNull() ?: 0 }
        val yellows= currentOrder.associateWith { yellowInputs[it]?.text?.toString()?.toIntOrNull() ?: 0 }
        val total  = currentOrder.sumOf { greens[it]!! + yellows[it]!! } + pause * currentOrder.size
        currentOrder.forEach { key ->
            val red = total - (greens[key]!! + yellows[key]!!) - pause
            redDisplays[key]?.text = "🔴 Красный: $red сек (${red/60}м ${red%60}с)"
        }
        cycleText.text = "Полный цикл: $total сек  (${total/60} мин ${total%60} сек)"
    }

    private fun makeWatcher() = object : TextWatcher {
        override fun afterTextChanged(s: Editable) = recalculate()
        override fun beforeTextChanged(s: CharSequence, st: Int, c: Int, a: Int) {}
        override fun onTextChanged(s: CharSequence, st: Int, b: Int, c: Int) {}
    }

    private fun loadConfig() {
        executor.execute {
            try {
                val cfg = JSONObject(URL("$serverUrl/config").readText())
                handler.post {
                    if (!isAdded) return@post
                    val ctx = requireContext(); val t = AppTheme.current; val dp = ctx.resources.displayMetrics.density
                    val orderArr = cfg.optJSONArray("order")
                    if (orderArr != null) {
                        currentOrder.clear()
                        for (j in 0 until orderArr.length()) currentOrder.add(orderArr.getString(j))
                    }
                    listOf("pereval", "abaza", "zarechka").forEach { key ->
                        if (!greenInputs.containsKey(key)) {
                            greenInputs[key]  = editInput(ctx, t, dp, "сек")
                            yellowInputs[key] = editInput(ctx, t, dp, "сек")
                            val w = makeWatcher()
                            greenInputs[key]!!.addTextChangedListener(w)
                            yellowInputs[key]!!.addTextChangedListener(w)
                        }
                        val obj = cfg.optJSONObject(key)
                        greenInputs[key]?.setText(obj?.optInt("green", 30)?.toString() ?: "30")
                        yellowInputs[key]?.setText(obj?.optInt("yellow", 3)?.toString() ?: "3")
                    }
                    pauseInput.setText(cfg.optInt("pause", 60).toString())
                    pauseInput.addTextChangedListener(makeWatcher())
                    renderRoads(); renderStartButtons()
                }
            } catch (_: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    val ctx = requireContext(); val t = AppTheme.current; val dp = ctx.resources.displayMetrics.density
                    listOf("pereval" to "132", "abaza" to "42", "zarechka" to "42").forEach { (key, def) ->
                        greenInputs.getOrPut(key) { editInput(ctx, t, dp, "сек").also { e -> e.addTextChangedListener(makeWatcher()) } }.setText(def)
                    }
                    listOf("pereval", "abaza", "zarechka").forEach { key ->
                        yellowInputs.getOrPut(key) { editInput(ctx, t, dp, "сек").also { e -> e.addTextChangedListener(makeWatcher()) } }.setText("3")
                    }
                    pauseInput.setText("60")
                    renderRoads(); renderStartButtons()
                }
            }
        }
    }

    private fun applyConfig(btn: Button) {
        val cfg = JSONObject()
        listOf("pereval", "abaza", "zarechka").forEach { key ->
            cfg.put(key, JSONObject()
                .put("green",  greenInputs[key]?.text?.toString()?.toIntOrNull()?.coerceIn(5, 300) ?: 30)
                .put("yellow", yellowInputs[key]?.text?.toString()?.toIntOrNull()?.coerceIn(1, 30) ?: 3))
        }
        cfg.put("pause", pauseInput.text.toString().toIntOrNull()?.coerceIn(0, 300) ?: 60)
        cfg.put("order", JSONArray().apply { currentOrder.forEach { put(it) } })
        btn.isEnabled = false; btn.text = "Отправка..."
        executor.execute {
            try {
                val conn = URL("$serverUrl/config").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.write(cfg.toString().toByteArray())
                val code = conn.responseCode; conn.disconnect()
                handler.post {
                    btn.isEnabled = true
                    btn.text = if (code == 200) "✓ Применено" else "Ошибка"
                    handler.postDelayed({ btn.text = "Применить" }, 2000)
                }
            } catch (_: Exception) {
                handler.post { btn.isEnabled = true; btn.text = "Нет связи" }
            }
        }
    }

    private fun sendReset(road: String, btn: Button) {
        val orig = btn.text.toString(); btn.isEnabled = false
        executor.execute {
            try {
                val conn = URL("$serverUrl/reset").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.write("{\"road\":\"$road\"}".toByteArray())
                conn.responseCode; conn.disconnect()
                handler.post { btn.isEnabled = true; btn.text = "✓"; handler.postDelayed({ btn.text = orig }, 1500) }
            } catch (_: Exception) { handler.post { btn.isEnabled = true; btn.text = orig } }
        }
    }

    // ── Вспомогательные ───────────────────────────────────────────────────────

    private fun sectionLabel(ctx: Context, text: String, t: ThemeDef, dp: Float) = TextView(ctx).apply {
        this.text = text.uppercase()
        textSize = 11f; letterSpacing = 0.15f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
        setPadding(0, 0, 0, 0)
    }

    private fun settingsLabel(ctx: Context, t: ThemeDef, dp: Float, text: String) = TextView(ctx).apply {
        this.text = text.uppercase()
        textSize = 10f; letterSpacing = 0.1f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
    }

    private fun editInput(ctx: Context, t: ThemeDef, dp: Float, hint: String) = EditText(ctx).apply {
        inputType = InputType.TYPE_CLASS_NUMBER; this.hint = hint
        setTextColor(Color.parseColor(t.textPrimary))
        setHintTextColor(hexAlpha(t.textSecondary, 90))
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = 8f * dp
            setColor(hexAlpha(t.bg, 220))
            setStroke(1, Color.parseColor(t.cardBorder))
        }
        setPadding((12 * dp).toInt(), (10 * dp).toInt(), (12 * dp).toInt(), (10 * dp).toInt())
        textSize = 15f
        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
    }

    private fun inputRow(ctx: Context, t: ThemeDef, dp: Float, icon: String, label: String, input: View): LinearLayout {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = (10 * dp).toInt() }
            val iconTv = TextView(ctx).apply {
                text = icon; textSize = 16f; gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams((28 * dp).toInt(), (28 * dp).toInt()).also {
                    it.marginEnd = (8 * dp).toInt()
                }
            }
            val labelTv = TextView(ctx).apply {
                text = label; textSize = 14f
                setTextColor(Color.parseColor(t.textSecondary))
                layoutParams = LinearLayout.LayoutParams((110 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
            }
            addView(iconTv); addView(labelTv); addView(input)
        }
    }

    private fun spacer(ctx: Context, dp: Float, heightDp: Float) = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, (heightDp * dp).toInt()
        )
    }
}
