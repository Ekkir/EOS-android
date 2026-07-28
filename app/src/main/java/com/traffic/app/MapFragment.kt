package com.traffic.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.cachemanager.CacheManager
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import java.io.File
import java.net.URL
import java.util.concurrent.Executors

class MapFragment : Fragment() {

    private lateinit var mapView: MapView
    private var locationOverlay: MyLocationNewOverlay? = null
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = ServerUrlResolver.resolve(prefs)

    private var permissionAsked = false
    private var lightStates = mapOf<String, String>()  // road -> "red"/"yellow"/"green"

    data class CrossroadDef(val key: String, val name: String, val color: Int)

    private val crossroads = listOf(
        CrossroadDef("pereval",  "Перевал", Color.parseColor("#00c853")),
        CrossroadDef("abaza",    "Абаза",   Color.parseColor("#2979ff")),
        CrossroadDef("zarechka", "Заречка", Color.parseColor("#ff6d00")),
    )

    private val markers = mutableMapOf<String, Marker>()

    // Опрос светофоров пока карта видима
    private val pollRunnable = object : Runnable {
        override fun run() {
            fetchLights()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        Configuration.getInstance().apply {
            userAgentValue = ctx.packageName
            osmdroidBasePath = File(ctx.getExternalFilesDir(null), "osmdroid")
            osmdroidTileCache = File(ctx.getExternalFilesDir(null), "osmdroid/tiles")
            tileDownloadThreads = 4
            tileFileSystemCacheMaxBytes = 200L * 1024 * 1024
        }

        mapView = MapView(ctx).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            controller.setZoom(16.0)
            isTilesScaledToDpi = true
        }

        // Если разрешение уже есть — сразу включаем GPS
        if (hasLocationPermission()) setupLocationOverlay()

        // Восстановить сохранённые маркеры
        crossroads.forEach { def ->
            val lat = prefs.getFloat("cross_${def.key}_lat", 0f).toDouble()
            val lon = prefs.getFloat("cross_${def.key}_lon", 0f).toDouble()
            if (lat != 0.0 && lon != 0.0) placeMarker(def, GeoPoint(lat, lon))
        }

        // Долгое нажатие → выбор перекрёстка
        mapView.overlays.add(object : Overlay() {
            override fun onLongPress(e: MotionEvent, mapView: MapView): Boolean {
                val point = mapView.projection.fromPixels(e.x.toInt(), e.y.toInt()) as GeoPoint
                showPickDialog(point)
                return true
            }
        })

        val frame = FrameLayout(ctx)
        frame.addView(mapView)

        // Кнопка центровки
        val btnCenter = makeButton("◎")
        frame.addView(btnCenter, FrameLayout.LayoutParams(130, 130).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            bottomMargin = 60; marginEnd = 30
        })
        btnCenter.setOnClickListener {
            val loc = locationOverlay?.myLocation
            if (loc != null) { mapView.controller.animateTo(loc); mapView.controller.setZoom(17.0) }
            else Toast.makeText(ctx, "GPS не найден", Toast.LENGTH_SHORT).show()
        }

        // Кнопка кэширования
        val btnCache = makeButton("📥")
        frame.addView(btnCache, FrameLayout.LayoutParams(130, 130).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            bottomMargin = 210; marginEnd = 30
        })
        btnCache.setOnClickListener { cacheVisibleArea(btnCache) }

        return frame
    }

    // Запрашиваем разрешение только когда пользователь открыл этот раздел
    override fun onHiddenChanged(hidden: Boolean) {
        super.onHiddenChanged(hidden)
        if (!hidden) {
            if (!permissionAsked && !hasLocationPermission()) {
                permissionAsked = true
                requestPermissions(arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ), 1001)
            }
            handler.post(pollRunnable)
        } else {
            handler.removeCallbacks(pollRunnable)
        }
    }

    override fun onResume() {
        super.onResume()
        mapView.onResume()
        locationOverlay?.enableMyLocation()
        if (!isHidden) handler.post(pollRunnable)
    }

    override fun onPause() {
        super.onPause()
        mapView.onPause()
        locationOverlay?.disableMyLocation()
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
                val states = mutableMapOf<String, String>()
                for (road in listOf("pereval", "abaza", "zarechka"))
                    states[road] = obj.getJSONObject(road).getString("state")
                handler.post {
                    if (!isAdded) return@post
                    lightStates = states
                    refreshMarkerIcons()
                }
            } catch (_: Exception) {}
        }
    }

    private fun refreshMarkerIcons() {
        crossroads.forEach { def ->
            val marker = markers[def.key] ?: return@forEach
            val state = lightStates[def.key] ?: "red"
            marker.icon = makeMarkerIcon(def.color, def.name, state)
        }
        mapView.invalidate()
    }

    private fun showPickDialog(point: GeoPoint) {
        val items = crossroads.map { it.name }.toTypedArray()
        androidx.appcompat.app.AlertDialog.Builder(requireContext())
            .setTitle("Установить перекрёсток:")
            .setItems(items) { _, i ->
                val def = crossroads[i]
                placeMarker(def, point)
                prefs.edit()
                    .putFloat("cross_${def.key}_lat", point.latitude.toFloat())
                    .putFloat("cross_${def.key}_lon", point.longitude.toFloat())
                    .apply()
                Toast.makeText(requireContext(), "${def.name} установлен", Toast.LENGTH_SHORT).show()
            }
            .show()
    }

    private fun placeMarker(def: CrossroadDef, point: GeoPoint) {
        markers[def.key]?.let { mapView.overlays.remove(it) }
        val state = lightStates[def.key] ?: "red"
        val marker = Marker(mapView).apply {
            position = point
            title = def.name
            snippet = "Перекрёсток"
            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            icon = makeMarkerIcon(def.color, def.name, state)
        }
        mapView.overlays.add(marker)
        markers[def.key] = marker
        mapView.invalidate()
    }

    private fun makeMarkerIcon(baseColor: Int, label: String, lightState: String): BitmapDrawable {
        val w = 120; val h = 150
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Основной круг
        paint.color = baseColor
        canvas.drawCircle(w / 2f, w / 2f, w / 2f - 4, paint)

        // Белый центр
        paint.color = Color.WHITE
        canvas.drawCircle(w / 2f, w / 2f, w / 5f, paint)

        // Хвостик-треугольник
        paint.color = baseColor
        val path = Path().apply {
            moveTo(w * 0.35f, w * 0.85f)
            lineTo(w * 0.65f, w * 0.85f)
            lineTo(w / 2f, h.toFloat())
            close()
        }
        canvas.drawPath(path, paint)

        // Подпись
        paint.color = Color.WHITE
        paint.textSize = 26f
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textAlign = Paint.Align.CENTER
        canvas.drawText(label, w / 2f, w / 2f + 10f, paint)

        // Индикатор светофора — цветной кружок в правом верхнем углу
        val lightColor = when (lightState) {
            "green"  -> Color.parseColor("#00e676")
            "yellow" -> Color.parseColor("#ffcc00")
            else     -> Color.parseColor("#ff2222")
        }
        paint.color = Color.WHITE
        canvas.drawCircle(w - 16f, 16f, 14f, paint)
        paint.color = lightColor
        canvas.drawCircle(w - 16f, 16f, 11f, paint)

        return BitmapDrawable(resources, bmp)
    }

    private fun cacheVisibleArea(btn: Button) {
        val ctx = requireContext()
        val act = requireActivity()
        val box = mapView.boundingBox
        val minZoom = mapView.zoomLevelDouble.toInt().coerceAtLeast(12)
        val maxZoom = (minZoom + 2).coerceAtMost(18)
        btn.isEnabled = false; btn.text = "⏳"
        val cacheManager = CacheManager(mapView)
        val total = cacheManager.possibleTilesInArea(box, minZoom, maxZoom)
        Toast.makeText(ctx, "Загружаю ~$total тайлов...", Toast.LENGTH_SHORT).show()
        cacheManager.downloadAreaAsync(ctx, box, minZoom, maxZoom,
            object : CacheManager.CacheManagerCallback {
                override fun onTaskComplete() { act.runOnUiThread { if (isAdded) { btn.isEnabled = true; btn.text = "📥"; Toast.makeText(ctx, "Карта сохранена", Toast.LENGTH_SHORT).show() } } }
                override fun onTaskFailed(errors: Int) { act.runOnUiThread { if (isAdded) { btn.isEnabled = true; btn.text = "📥" } } }
                override fun updateProgress(p: Int, z: Int, zMin: Int, zMax: Int) { act.runOnUiThread { if (isAdded) btn.text = "$p%" } }
                override fun downloadStarted() {}
                override fun setPossibleTilesInArea(total: Int) {}
            })
    }

    private fun makeButton(text: String) = Button(requireContext()).apply {
        val t = AppTheme.current
        this.text = text; textSize = 22f
        setTextColor(Color.parseColor(t.textPrimary))
        setBackgroundColor(hexAlpha(t.accent, 50))
    }

    private fun setupLocationOverlay() {
        val act = activity ?: return
        locationOverlay = MyLocationNewOverlay(GpsMyLocationProvider(act), mapView).apply {
            enableMyLocation()
            enableFollowLocation()
            runOnFirstFix {
                act.runOnUiThread {
                    if (isAdded) {
                        mapView.controller.setCenter(myLocation)
                        mapView.controller.setZoom(17.0)
                    }
                }
            }
        }
        mapView.overlays.add(locationOverlay)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == 1001 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            setupLocationOverlay()
    }

    private fun hasLocationPermission() = ContextCompat.checkSelfPermission(
        requireContext(), Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
}
