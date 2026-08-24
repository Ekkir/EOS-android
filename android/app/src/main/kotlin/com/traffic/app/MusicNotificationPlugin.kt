package com.traffic.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MusicNotificationPlugin(
    private val ctx: Context,
    private val flutterChannel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_ID = "eos_music_v2"
        private const val NOTIF_ID   = 0xE051
        const val ACTION_TOGGLE = "com.traffic.app.MUSIC_TOGGLE"
        const val ACTION_NEXT   = "com.traffic.app.MUSIC_NEXT"
        const val ACTION_PREV   = "com.traffic.app.MUSIC_PREV"
    }

    private val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var session: MediaSession? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_TOGGLE -> flutterChannel.invokeMethod("onToggle", null)
                ACTION_NEXT   -> flutterChannel.invokeMethod("onNext",   null)
                ACTION_PREV   -> flutterChannel.invokeMethod("onPrev",   null)
            }
        }
    }

    init {
        ensureChannel()
        val filter = IntentFilter().apply {
            addAction(ACTION_TOGGLE); addAction(ACTION_NEXT); addAction(ACTION_PREV)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            ctx.registerReceiver(receiver, filter)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        android.util.Log.d("MusicNotif", "onMethodCall: ${call.method}")
        when (call.method) {
            "show" -> {
                try {
                    val title = call.argument<String>("title") ?: ""
                    val playing = call.argument<Boolean>("playing") ?: false
                    android.util.Log.d("MusicNotif", "show title=$title playing=$playing")
                    show(title, playing)
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("MusicNotif", "show error", e)
                    result.error("SHOW_ERROR", e.message, null)
                }
            }
            "hide" -> { hide(); result.success(null) }
            else   -> result.notImplemented()
        }
    }

    fun show(title: String, isPlaying: Boolean) {
        val s = session ?: MediaSession(ctx, "EOS").also { newSession ->
            newSession.setCallback(object : MediaSession.Callback() {
                override fun onPlay()           { flutterChannel.invokeMethod("onToggle", null) }
                override fun onPause()          { flutterChannel.invokeMethod("onToggle", null) }
                override fun onSkipToNext()     { flutterChannel.invokeMethod("onNext",   null) }
                override fun onSkipToPrevious() { flutterChannel.invokeMethod("onPrev",   null) }
                override fun onStop()           { flutterChannel.invokeMethod("onToggle", null) }
            })
            session = newSession
        }

        s.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, "EOS Music")
                .build()
        )
        s.setPlaybackState(
            PlaybackState.Builder()
                .setState(
                    if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f
                )
                .setActions(
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS
                )
                .build()
        )
        s.isActive = true

        val playIcon  = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playLabel = if (isPlaying) "Пауза" else "Играет"

        val launchIntent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val contentPi = PendingIntent.getActivity(
            ctx, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(ctx, CHANNEL_ID)
        else
            @Suppress("DEPRECATION") Notification.Builder(ctx))
            .setContentTitle(title)
            .setContentText("EOS Music")
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(BitmapFactory.decodeResource(ctx.resources, R.mipmap.ic_launcher))
            .setContentIntent(contentPi)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(s.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .addAction(action(android.R.drawable.ic_media_previous, "Назад",  ACTION_PREV))
            .addAction(action(playIcon,                              playLabel, ACTION_TOGGLE))
            .addAction(action(android.R.drawable.ic_media_next,     "Далее",  ACTION_NEXT))
            .build()

        MusicForegroundService.start(ctx, notif)
    }

    fun hide() {
        MusicForegroundService.stop(ctx)
        session?.isActive = false
        session?.release()
        session = null
    }

    private fun action(icon: Int, label: String, broadcastAction: String): Notification.Action {
        val i = Intent(broadcastAction).also { it.setPackage(ctx.packageName) }
        val pi = PendingIntent.getBroadcast(
            ctx, broadcastAction.hashCode(), i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        @Suppress("DEPRECATION")
        return Notification.Action.Builder(icon, label, pi).build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Музыка", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    setSound(null, null)
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
    }

    fun dispose() {
        hide()
        try { ctx.unregisterReceiver(receiver) } catch (_: Exception) {}
    }
}
