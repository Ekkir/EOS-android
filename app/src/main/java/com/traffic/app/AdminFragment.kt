package com.traffic.app

import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class AdminFragment : Fragment() {

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = ServerUrlResolver.resolve(prefs)
    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private lateinit var cpuRow:  LinearLayout
    private lateinit var ramRow:  LinearLayout
    private lateinit var diskRow: LinearLayout
    private lateinit var statusDot: TextView

    private val statsRefresh = object : Runnable {
        override fun run() {
            if (isAdded) {
                loadStats(cpuRow, ramRow, diskRow)
                handler.postDelayed(this, 10_000)
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (12 * dp).toInt() + statusBarHeight(ctx), (20 * dp).toInt(), (32 * dp).toInt())
        }
        scroll.addView(layout)

        // ── Шапка ────────────────────────────────────────────────────────────
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (20 * dp).toInt())
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "Эндминестратор"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = (8 * dp).toInt()
            }
        })
        layout.addView(header)

        // ── Статус сервера ───────────────────────────────────────────────────
        layout.addView(sectionLabel(ctx, "СЕРВЕР", t, dp))
        layout.addView(spacer(ctx, dp, 8f))

        statusDot = TextView(ctx).apply { textSize = 13f; text = "● Проверяю..." }
        val statusCard = buildCard(ctx, t, dp).apply {
            addView(TextView(ctx).apply {
                text = serverUrl; textSize = 11f; typeface = Typeface.MONOSPACE
                setTextColor(Color.parseColor(t.textSecondary))
                setPadding(0, 0, 0, (8 * dp).toInt())
            })
            addView(statusDot)
            addView(buildBtn(ctx, t, dp, "Проверить") { checkServer(statusDot) })
            addView(buildBtn(ctx, t, dp, "Перезапустить сервер", accent = false) {
                confirm(ctx, "Перезапустить сервер?") { restartServer(statusDot) }
            })
        }
        layout.addView(statusCard)
        layout.addView(spacer(ctx, dp, 16f))

        // ── Система ─────────────────────────────────────────────────────────
        layout.addView(sectionLabel(ctx, "СИСТЕМА", t, dp))
        layout.addView(spacer(ctx, dp, 8f))

        cpuRow  = buildStatRow(ctx, t, dp, "ЦП")
        ramRow  = buildStatRow(ctx, t, dp, "ОЗУ")
        diskRow = buildStatRow(ctx, t, dp, "Диск")
        val statsCard = buildCard(ctx, t, dp).apply {
            addView(cpuRow)
            addView(ramRow)
            addView(diskRow)
            addView(buildBtn(ctx, t, dp, "Обновить") { loadStats(cpuRow, ramRow, diskRow) })
        }
        layout.addView(statsCard)
        layout.addView(spacer(ctx, dp, 16f))

        // ── Лог ─────────────────────────────────────────────────────────────
        layout.addView(sectionLabel(ctx, "ЖУРНАЛ СЕРВЕРА", t, dp))
        layout.addView(spacer(ctx, dp, 8f))

        val logView = TextView(ctx).apply {
            textSize = 12f; typeface = Typeface.MONOSPACE
            setTextColor(Color.parseColor(t.textSecondary))
            setLineSpacing(0f, 1.4f)
            visibility = View.GONE
        }
        val logCard = buildCard(ctx, t, dp).apply {
            addView(buildBtn(ctx, t, dp, "Загрузить журнал") { loadLog(logView) })
            addView(logView)
        }
        layout.addView(logCard)

        checkServer(statusDot)
        handler.post(statsRefresh)
        return scroll
    }

    private fun checkServer(dot: TextView) {
        dot.setTextColor(Color.parseColor(AppTheme.current.textSecondary))
        dot.text = "● Проверяю..."
        executor.execute {
            try {
                val conn = URL("$serverUrl/lights").openConnection() as HttpURLConnection
                conn.connectTimeout = 5000; conn.readTimeout = 5000
                val code = conn.responseCode; conn.disconnect()
                handler.post {
                    if (!isAdded) return@post
                    if (code == 200) { dot.setTextColor(Color.parseColor("#4CAF50")); dot.text = "● Онлайн" }
                    else             { dot.setTextColor(Color.parseColor("#FF6B6B")); dot.text = "● Ошибка HTTP $code" }
                }
            } catch (e: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    dot.setTextColor(Color.parseColor("#FF6B6B")); dot.text = "● Недоступен: ${e.message}"
                }
            }
        }
    }

    private fun restartServer(dot: TextView) {
        dot.setTextColor(Color.parseColor(AppTheme.current.textSecondary)); dot.text = "● Перезапуск..."
        executor.execute {
            try {
                val conn = URL("$serverUrl/restart").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.connectTimeout = 5000; conn.connect(); conn.disconnect()
            } catch (_: Exception) {}
            handler.postDelayed({ if (isAdded) checkServer(dot) }, 4000)
        }
    }

    private fun loadStats(cpuRow: LinearLayout, ramRow: LinearLayout, diskRow: LinearLayout) {
        setStatValue(cpuRow, "...")
        setStatValue(ramRow, "...")
        setStatValue(diskRow, "...")
        executor.execute {
            try {
                val json = JSONObject(URL("$serverUrl/stats").readText())
                val cpu  = json.optDouble("cpu_usage", 0.0)
                val memU = json.optInt("mem_used", 0)
                val memT = json.optInt("mem_total", 1)
                val dskU = json.optInt("disk_used", 0)
                val dskT = json.optInt("disk_total", 1)
                handler.post {
                    if (!isAdded) return@post
                    setStatValue(cpuRow,  "%.1f%%".format(cpu))
                    setStatValue(ramRow,  "$memU / $memT МБ")
                    setStatValue(diskRow, "$dskU / $dskT ГБ")
                }
            } catch (e: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    setStatValue(cpuRow,  "—")
                    setStatValue(ramRow,  "—")
                    setStatValue(diskRow, "—")
                }
            }
        }
    }

    private fun loadLog(logView: TextView) {
        logView.setTextColor(Color.parseColor(AppTheme.current.textSecondary))
        logView.text = "Загружаю..."; logView.visibility = View.VISIBLE
        executor.execute {
            try {
                val json = JSONObject(URL("$serverUrl/log").readText())
                val raw  = json.getString("log")
                val lines = raw.lines().filter { it.isNotBlank() }
                val formatted = lines.joinToString("\n") { line ->
                    // Форматируем строки лога: IP - - [дата] "метод url" код
                    val match = Regex("""^([\d.]+) - - \[(.+?)\] "(.+?)" (\d+)""").find(line)
                    if (match != null) {
                        val (ip, date, req, code) = match.destructured
                        val time = date.substringBefore(" +").substringAfter("/").let {
                            val parts = it.split("/", ":", " ")
                            if (parts.size >= 4) "${parts[1]} ${parts[0]} ${parts[2]}:${parts[3]}:${parts.getOrElse(4){"00"}}"
                            else date
                        }
                        val color = if (code == "200") "✓" else "✗"
                        "$color  $time   $code  ${req.take(40)}"
                    } else line.take(80)
                }
                handler.post {
                    if (!isAdded) return@post
                    logView.text = formatted.takeLast(3000).ifEmpty { "Журнал пуст" }
                }
            } catch (e: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    logView.setTextColor(Color.parseColor("#FF6B6B"))
                    logView.text = "Ошибка: ${e.message}"
                }
            }
        }
    }

    private fun confirm(ctx: Context, message: String, onConfirm: () -> Unit) {
        val t = AppTheme.current
        AlertDialog.Builder(ctx)
            .setMessage(message)
            .setPositiveButton("Да") { _, _ -> onConfirm() }
            .setNegativeButton("Отмена", null)
            .show()
            .apply {
                getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(Color.parseColor(t.accent))
                getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(Color.parseColor(t.textSecondary))
            }
    }

    private fun buildStatRow(ctx: Context, t: ThemeDef, dp: Float, label: String): LinearLayout {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (8 * dp).toInt() }
            addView(TextView(ctx).apply {
                text = label; textSize = 13f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.textSecondary))
                layoutParams = LinearLayout.LayoutParams((56 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
            })
            addView(TextView(ctx).apply {
                text = "..."; textSize = 13f; typeface = Typeface.MONOSPACE
                setTextColor(Color.parseColor(t.textPrimary))
                tag = "value"
            })
        }
    }

    private fun setStatValue(row: LinearLayout, value: String) {
        (row.findViewWithTag<TextView>("value"))?.text = value
    }

    private fun buildCard(ctx: Context, t: ThemeDef, dp: Float) = LinearLayout(ctx).apply {
        orientation = LinearLayout.VERTICAL
        setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
        background = cardDrawable(t, 16f, dp)
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    private fun buildBtn(ctx: Context, t: ThemeDef, dp: Float, label: String, accent: Boolean = true, onClick: () -> Unit) =
        Button(ctx).apply {
            text = label; textSize = 14f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (accent) Color.parseColor(t.bg) else Color.parseColor(t.textPrimary))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
                setColor(if (accent) Color.parseColor(t.accent) else Color.argb(40, 255, 255, 255))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (44 * dp).toInt()
            ).apply { topMargin = (8 * dp).toInt() }
            setOnClickListener { onClick() }
        }

    private fun sectionLabel(ctx: Context, text: String, t: ThemeDef, dp: Float) = TextView(ctx).apply {
        this.text = text; textSize = 11f; letterSpacing = 0.15f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
    }

    private fun spacer(ctx: Context, dp: Float, h: Float) = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (h * dp).toInt())
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacks(statsRefresh)
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }
}
