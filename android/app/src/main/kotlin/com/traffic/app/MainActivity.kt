package com.traffic.app

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        const val REQUEST_VPN_PERMISSION = 1000
    }

    private var awgPlugin: AwgFlutterPlugin? = null
    private var musicPlugin: MusicNotificationPlugin? = null
    var pendingConnectArgs: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Media Session / Music Notification ───────────────────────────────
        val musicChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.traffic.app/music_session"
        )
        musicPlugin = MusicNotificationPlugin(applicationContext, musicChannel)
        musicChannel.setMethodCallHandler(musicPlugin)

        // ── AmneziaWG VPN channels ────────────────────────────────────────────
        val plugin = AwgFlutterPlugin(this)
        awgPlugin = plugin
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AwgFlutterPlugin.METHOD_CHANNEL
        ).setMethodCallHandler(plugin)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AwgFlutterPlugin.EVENT_CHANNEL
        ).setStreamHandler(plugin)

        // ── PackageInstaller channel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.traffic.app/installer")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARG", "path is null", null)
                    return@setMethodCallHandler
                }
                try {
                    // На Android 8+ проверяем разрешение на установку из неизвестных источников
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            val settingsIntent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(settingsIntent)
                            result.error("NO_INSTALL_PERMISSION", path, null)
                            return@setMethodCallHandler
                        }
                    }
                    val apkFile = File(path)
                    val apkUri: Uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        apkFile
                    )
                    val installIntent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(apkUri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(installIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            }

        // ── Installed apps channel ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.traffic.app/apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        try {
                            val launchIntent = Intent(Intent.ACTION_MAIN, null).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            val apps = packageManager.queryIntentActivities(launchIntent, PackageManager.GET_META_DATA)
                            val list = apps
                                .map { info ->
                                    mapOf(
                                        "packageName" to info.activityInfo.packageName,
                                        "appName" to info.loadLabel(packageManager).toString()
                                    )
                                }
                                .filter { it["packageName"] != packageName }
                                .sortedBy { it["appName"] }
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "getAppIcon" -> {
                        val pkgName = call.argument<String>("packageName")
                        if (pkgName == null) {
                            result.error("INVALID_ARG", "packageName is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val drawable = packageManager.getApplicationIcon(pkgName)
                            val bitmap = drawableToBitmap(drawable, 48)
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                            result.success(stream.toByteArray())
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Media save channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.traffic.app/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes    = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName") ?: "download"
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes == null) {
                    result.error("INVALID_ARG", "bytes is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val saved = saveToDownloads(bytes, fileName, mimeType)
                    result.success(saved)
                } catch (e: Exception) {
                    result.error("SAVE_ERROR", e.message, null)
                }
            }
    }

    override fun onDestroy() {
        musicPlugin?.dispose()
        super.onDestroy()
    }

    @Deprecated("Deprecated but still needed for API < 33 compat")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION) {
            if (resultCode == RESULT_OK) {
                val args = pendingConnectArgs
                pendingConnectArgs = null
                if (args != null) {
                    try {
                        awgPlugin?.startVpnService(args)
                    } catch (e: Throwable) {
                        Log.e("MainActivity", "startVpnService failed", e)
                        AwgVpnService.onStatus?.invoke("error:${e.message ?: e.javaClass.simpleName}")
                    }
                }
            } else {
                pendingConnectArgs = null
                AwgVpnService.onStatus?.invoke("error:VPN permission denied")
            }
        }
    }

    private fun drawableToBitmap(drawable: Drawable, size: Int): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        }
        val w = drawable.intrinsicWidth.coerceAtLeast(1)
        val h = drawable.intrinsicHeight.coerceAtLeast(1)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(canvas)
        return Bitmap.createScaledBitmap(bmp, size, size, true)
    }

    private fun saveToDownloads(bytes: ByteArray, fileName: String, mimeType: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
            ) ?: throw Exception("Не удалось создать запись MediaStore")
            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw Exception("Не удалось открыть поток для записи")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            fileName
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            file.writeBytes(bytes)
            file.absolutePath
        }
    }
}
