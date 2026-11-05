package dev.moinsen.noisenet_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground host for the Flutter-owned sensor pipeline.
 *
 * Audio capture and YAMNet inference stay in the already running Flutter
 * engine. This service gives that process the Android microphone foreground
 * service lifetime and a persistent, user-visible stop affordance.
 */
class NoiseMonitoringService : Service() {

    companion object {
        const val CHANNEL_ID = "noise_monitoring_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_MONITORING = "START_MONITORING"
        const val ACTION_STOP_MONITORING = "STOP_MONITORING"
        const val ACTION_UPDATE_NOTIFICATION = "UPDATE_NOTIFICATION"
        const val EXTRA_SPL = "spl"
        const val EXTRA_STATUS = "status"
        const val EXTRA_NOTIFY_FLUTTER = "notify_flutter"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_MONITORING -> stopMonitoring(
                intent.getBooleanExtra(EXTRA_NOTIFY_FLUTTER, false),
            )
            ACTION_UPDATE_NOTIFICATION -> updateNotification(
                intent.getDoubleExtra(EXTRA_SPL, 0.0),
                intent.getStringExtra(EXTRA_STATUS) ?: "Monitoring",
            )
            ACTION_START_MONITORING, null -> startMonitoring()
        }
        return if (isRunning) START_STICKY else START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Noise Monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Continuous environmental noise monitoring"
                setSound(null, null)
                enableVibration(false)
            }
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startMonitoring() {
        if (isRunning) return
        startForeground(NOTIFICATION_ID, createNotification(0.0, "Starting…"))
        isRunning = true
        android.util.Log.i("NoiseService", "Noise monitoring foreground host started")
    }

    private fun stopMonitoring(notifyFlutter: Boolean) {
        if (notifyFlutter) {
            MainActivity.sensorChannel?.invokeMethod("stopMonitoring", null)
        }
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        android.util.Log.i("NoiseService", "Noise monitoring foreground host stopped")
    }

    private fun createNotification(spl: Double, status: String): Notification {
        val splText = if (spl > 0) "${spl.toInt()} dB" else "-- dB"
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(this, NoiseMonitoringService::class.java).apply {
            action = ACTION_STOP_MONITORING
            putExtra(EXTRA_NOTIFY_FLUTTER, true)
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OpenNoiseNet Monitoring")
            .setContentText("$status • Current: $splText")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(spl: Double, status: String) {
        if (!isRunning) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createNotification(spl, status))
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
