package com.traffic.app

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class MusicForegroundService : Service() {

    companion object {
        private const val NOTIF_ID = 0xE051
        private const val TAG = "MusicFgService"

        @Volatile internal var pendingNotification: Notification? = null

        fun start(context: Context, notification: Notification) {
            pendingNotification = notification
            val intent = Intent(context, MusicForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                @Suppress("DEPRECATION")
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MusicForegroundService::class.java))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notif = pendingNotification ?: run {
            Log.w(TAG, "pendingNotification is null, stopping")
            stopSelf()
            return START_NOT_STICKY
        }
        Log.d(TAG, "calling startForeground, api=${Build.VERSION.SDK_INT}")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIF_ID, notif)
            }
            Log.d(TAG, "startForeground OK")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground FAILED: ${e.javaClass.simpleName}: ${e.message}")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
