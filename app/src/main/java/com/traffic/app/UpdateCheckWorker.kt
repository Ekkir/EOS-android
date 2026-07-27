package com.traffic.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class UpdateCheckWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val currentVersion = AboutFragment.CURRENT_VERSION
        try {
            val url = "https://api.github.com/repos/${AboutFragment.GITHUB_OWNER}/${AboutFragment.GITHUB_REPO}/releases/latest"
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.setRequestProperty("Accept", "application/vnd.github.v3+json")
            conn.connectTimeout = 10000; conn.readTimeout = 10000
            val code = conn.responseCode
            if (code == 404) { conn.disconnect(); return Result.success() }
            val json = JSONObject(conn.inputStream.bufferedReader().readText())
            conn.disconnect()
            val tagName = json.getString("tag_name").trimStart('v', 'V')
            val body    = json.optString("body", "")
            if (isNewerVersion(tagName, currentVersion)) {
                sendNotification(tagName, body)
            }
        } catch (_: Exception) {}
        return Result.success()
    }

    private fun sendNotification(version: String, body: String) {
        val ctx = applicationContext
        val channelId = "eos_updates"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Обновления EOS", NotificationManager.IMPORTANCE_DEFAULT)
            ctx.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
        val launchIntent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pi = PendingIntent.getActivity(ctx, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE)
        val summary = body.lines().firstOrNull { it.isNotBlank() }?.take(80) ?: "Нажмите чтобы обновить"
        val notification = NotificationCompat.Builder(ctx, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Доступно обновление EOS v$version")
            .setContentText(summary)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(1001, notification)
        } catch (_: SecurityException) {}
    }

    private fun isNewerVersion(remote: String, current: String): Boolean {
        val r = remote.split(".").mapNotNull { it.trim().toIntOrNull() }
        val c = current.split(".").mapNotNull { it.trim().toIntOrNull() }
        for (i in 0 until maxOf(r.size, c.size)) {
            val rv = r.getOrElse(i) { 0 }
            val cv = c.getOrElse(i) { 0 }
            if (rv > cv) return true; if (rv < cv) return false
        }
        return false
    }
}
