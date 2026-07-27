package com.traffic.app

import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
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

class TrafficFragment : Fragment() {

    private lateinit var roadMapView: RoadMapView
    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val prefs     get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = prefs.getString("server_url", "http://2.61.59.197:5000")!!

    private val viewpoints = listOf(
        "pereval"  to "Перевал",
        "abaza"    to "Абаза",
        "zarechka" to "Заречка",
    )
    private val vpBtnColors = mapOf(
        "pereval"  to "#00c853",
        "abaza"    to "#2979ff",
        "zarechka" to "#ff6d00",
    )

    private val vpButtons = mutableMapOf<String, Button>()

    private val pollRunnable = object : Runnable {
        override fun run() {
            fetchLights()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()

        val t = AppTheme.current
        // Корневой LinearLayout (вертикальный): карта + нижняя панель
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(t.bg))
        }

        // RoadMapView — занимает всё свободное пространство
        roadMapView = RoadMapView(ctx)
        root.addView(roadMapView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
        ))

        val dp = ctx.resources.displayMetrics.density
        // Нижняя панель: кнопки «Еду из»
        val bottomPanel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(t.nav))
            setPadding((16 * dp).toInt(), (8 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
        }

        bottomPanel.addView(TextView(ctx).apply {
            text = "Еду из:"
            textSize = 13f
            setTextColor(Color.parseColor(t.textSecondary))
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(0, 0, 0, (6 * dp).toInt())
        })

        val btnRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val savedVp = prefs.getString("viewpoint", "abaza") ?: "abaza"

        viewpoints.forEachIndexed { i, (key, label) ->
            val btn = Button(ctx).apply {
                text = label
                textSize = 14f
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(0, (48 * dp).toInt(), 1f).also {
                    it.marginEnd = if (i < viewpoints.size - 1) (8 * dp).toInt() else 0
                }
                setPadding((4 * dp).toInt(), 0, (4 * dp).toInt(), 0)
                isAllCaps = false
            }
            btn.setOnClickListener { selectViewpoint(key) }
            vpButtons[key] = btn
            btnRow.addView(btn)
        }

        bottomPanel.addView(btnRow)
        root.addView(bottomPanel, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Кнопка настроек
        val frame = FrameLayout(ctx)
        frame.addView(root, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
        ))

        val settingsBtn = Button(ctx).apply {
            text = "⚙"
            textSize = 22f
            setTextColor(Color.parseColor(AppTheme.current.textPrimary))
            setBackgroundColor(hexAlpha(AppTheme.current.accent, 40))
        }
        frame.addView(settingsBtn, FrameLayout.LayoutParams(130, 130).apply {
            gravity = Gravity.TOP or Gravity.END
            topMargin = 50; marginEnd = 30
        })
        settingsBtn.setOnClickListener { openSettings() }

        // Восстановить сохранённый viewpoint
        selectViewpoint(savedVp)

        return frame
    }

    private fun selectViewpoint(key: String) {
        roadMapView.viewpoint = key
        prefs.edit().putString("viewpoint", key).apply()
        // Обновить стиль кнопок
        vpButtons.forEach { (k, btn) ->
            if (k == key) {
                btn.setTextColor(Color.WHITE)
                btn.setBackgroundColor(Color.parseColor(vpBtnColors[k] ?: "#444466"))
            } else {
                val t2 = AppTheme.current
                btn.setTextColor(Color.parseColor(t2.textSecondary))
                btn.setBackgroundColor(hexAlpha(t2.textSecondary, 20))
            }
        }
    }

    override fun onResume() {
        super.onResume()
        handler.post(pollRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(pollRunnable)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }

    private fun fetchLights() {
        executor.execute {
            try {
                val obj = JSONObject(URL("$serverUrl/lights").readText())
                val newLights = mutableMapOf<String, LightState>()
                for (road in listOf("pereval", "abaza", "zarechka")) {
                    val r = obj.getJSONObject(road)
                    newLights[road] = LightState(r.getString("state"), r.getInt("remaining"), r.getInt("to_green"))
                }
                handler.post { if (isAdded) roadMapView.updateLights(newLights) }
            } catch (_: Exception) {
                handler.post { if (isAdded) roadMapView.setDisconnected() }
            }
        }
    }

    private fun openSettings() {
        executor.execute {
            var cfg: JSONObject? = null
            try { cfg = JSONObject(URL("$serverUrl/config").readText()) } catch (_: Exception) {}
            handler.post { if (isAdded) showSettingsDialog(cfg) }
        }
    }

    private fun showSettingsDialog(cfg: JSONObject?) {
        if (!isAdded) return
        val ctx = requireContext()
        val roads = listOf(
            Triple("pereval",  "Перевал",  cfg?.optJSONObject("pereval")?.optInt("green",  30) ?: 30),
            Triple("abaza",    "Абаза",    cfg?.optJSONObject("abaza")?.optInt("green",    25) ?: 25),
            Triple("zarechka", "Заречка",  cfg?.optJSONObject("zarechka")?.optInt("green", 25) ?: 25),
        )

        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 20)
            setBackgroundColor(Color.parseColor("#1a1a2e"))
        }

        layout.addView(TextView(ctx).apply {
            text = "Адрес сервера:"
            setTextColor(Color.parseColor("#aaaacc")); textSize = 15f; setPadding(0, 0, 0, 4)
        })
        val urlInput = EditText(ctx).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor("#2a2a4a"))
            setPadding(12, 8, 12, 8); setText(serverUrl)
        }
        layout.addView(urlInput)
        layout.addView(TextView(ctx).apply {
            text = "Дома (WiFi): http://192.168.0.15:5000\nИнтернет:    http://2.61.59.197:5000"
            setTextColor(Color.parseColor("#555577")); textSize = 12f; setPadding(0, 4, 0, 24)
        })

        layout.addView(TextView(ctx).apply {
            text = "Пауза (все красные, сек):"
            setTextColor(Color.parseColor("#aaaacc")); textSize = 15f; setPadding(0, 12, 0, 4)
        })
        val pauseRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
        }
        val pauseCurrent = cfg?.optInt("pause", 60) ?: 60
        val pauseSeek = SeekBar(ctx).apply {
            max = 295; progress = pauseCurrent - 5
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val pauseText = EditText(ctx).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor("#2a2a4a"))
            setPadding(12, 8, 12, 8); setText(pauseCurrent.toString())
            layoutParams = LinearLayout.LayoutParams(160, LinearLayout.LayoutParams.WRAP_CONTENT).also { it.marginStart = 16 }
        }
        pauseSeek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar, p: Int, fromUser: Boolean) { if (fromUser) pauseText.setText((p + 5).toString()) }
            override fun onStartTrackingTouch(sb: SeekBar) {}
            override fun onStopTrackingTouch(sb: SeekBar) {}
        })
        pauseText.addTextChangedListener(object : android.text.TextWatcher {
            override fun afterTextChanged(s: android.text.Editable) {
                val v = s.toString().toIntOrNull()?.coerceIn(0, 300) ?: return
                if (pauseSeek.progress != v - 5) pauseSeek.progress = (v - 5).coerceAtLeast(0)
            }
            override fun beforeTextChanged(s: CharSequence, st: Int, c: Int, a: Int) {}
            override fun onTextChanged(s: CharSequence, st: Int, b: Int, c: Int) {}
        })
        pauseRow.addView(pauseSeek); pauseRow.addView(pauseText)
        layout.addView(pauseRow)

        val inputs = mutableMapOf<String, EditText>()
        for ((key, name, current) in roads) {
            layout.addView(TextView(ctx).apply {
                text = "$name — секунд зелёного:"
                setTextColor(Color.parseColor("#aaaacc")); textSize = 15f; setPadding(0, 12, 0, 4)
            })
            val row = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            }
            val seekBar = SeekBar(ctx).apply {
                max = 295; progress = current - 5
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val valueText = EditText(ctx).apply {
                inputType = InputType.TYPE_CLASS_NUMBER
                setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor("#2a2a4a"))
                setPadding(12, 8, 12, 8); setText(current.toString())
                layoutParams = LinearLayout.LayoutParams(160, LinearLayout.LayoutParams.WRAP_CONTENT).also { it.marginStart = 16 }
            }
            seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar, p: Int, fromUser: Boolean) { if (fromUser) valueText.setText((p + 5).toString()) }
                override fun onStartTrackingTouch(sb: SeekBar) {}
                override fun onStopTrackingTouch(sb: SeekBar) {}
            })
            valueText.addTextChangedListener(object : android.text.TextWatcher {
                override fun afterTextChanged(s: android.text.Editable) {
                    val v = s.toString().toIntOrNull()?.coerceIn(5, 300) ?: return
                    if (seekBar.progress != v - 5) seekBar.progress = v - 5
                }
                override fun beforeTextChanged(s: CharSequence, st: Int, c: Int, a: Int) {}
                override fun onTextChanged(s: CharSequence, st: Int, b: Int, c: Int) {}
            })
            row.addView(seekBar); row.addView(valueText)
            layout.addView(row)
            inputs[key] = valueText
        }

        AlertDialog.Builder(ctx)
            .setTitle("Настройки")
            .setView(ScrollView(ctx).apply { addView(layout) })
            .setPositiveButton("Сохранить") { _, _ ->
                prefs.edit().putString("server_url", urlInput.text.toString().trimEnd('/')).apply()
                val newCfg = JSONObject()
                for ((key, _, _) in roads) {
                    val secs = inputs[key]?.text?.toString()?.toIntOrNull()?.coerceIn(5, 300) ?: 30
                    newCfg.put(key, JSONObject().put("green", secs))
                }
                newCfg.put("pause", pauseText.text.toString().toIntOrNull()?.coerceIn(0, 300) ?: 60)
                applyConfig(newCfg)
            }
            .setNegativeButton("Отмена", null)
            .show()
    }

    private fun applyConfig(cfg: JSONObject) {
        executor.execute {
            try {
                val conn = URL("$serverUrl/config").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.write(cfg.toString().toByteArray())
                conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }
    }
}
