package com.funny.replaysdk.sample

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.funny.replaysdk.RecordingManager

class RecordingFgService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val data = intent?.getParcelableExtra<Intent>(EXTRA_DATA)
        startForeground(NOTI_ID, buildNotification())
        if (resultCode == RESULT_OK && data != null) {
            RecordingManager.startWithProjection(resultCode, data)
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        val channelId = "replay_record_channel"
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(channelId) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(channelId, "Recording", NotificationManager.IMPORTANCE_LOW)
                )
            }
        }
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("Recording in progress")
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val NOTI_ID = 1001
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_DATA = "data_intent"
        const val RESULT_OK = -1

        fun start(context: Context, resultCode: Int, data: Intent) {
            val i = Intent(context, RecordingFgService::class.java)
            i.putExtra(EXTRA_RESULT_CODE, resultCode)
            i.putExtra(EXTRA_DATA, data)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        }
    }
}


