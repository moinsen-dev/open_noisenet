package com.opennoisenet.mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Android Foreground Service for continuous noise monitoring
 * Allows the app to monitor noise levels even when in background
 */
class NoiseMonitoringService : Service() {

    companion object {
        const val CHANNEL_ID = "noise_monitoring_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_MONITORING = "START_MONITORING"
        const val ACTION_STOP_MONITORING = "STOP_MONITORING"
        const val METHOD_CHANNEL = "com.opennoisenet.mobile/noise_service"

        private const val FLUTTER_ENGINE_ID = "noise_monitoring_engine"
    }

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var isMonitoring = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initializeFlutterEngine()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_MONITORING -> startMonitoring()
            ACTION_STOP_MONITORING -> stopMonitoring()
        }
        return START_STICKY // Restart service if killed by system
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Noise Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuous environmental noise monitoring"
                setSound(null, null) // Silent notifications
                enableVibration(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun initializeFlutterEngine() {
        try {
            // Initialize Flutter engine for background processing
            flutterEngine = FlutterEngine(this)
            flutterEngine?.let { engine ->
                // Start executing Dart code
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )

                // Cache the engine for reuse
                FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, engine)

                // Set up method channel for communication
                methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                methodChannel?.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "updateNotification" -> {
                            val spl = call.argument<Double>("spl") ?: 0.0
                            val status = call.argument<String>("status") ?: "Monitoring"
                            updateNotification(spl, status)
                            result.success(null)
                        }
                        "isServiceRunning" -> {
                            result.success(isMonitoring)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("NoiseService", "Failed to initialize Flutter engine: ${e.message}")
        }
    }

    private fun startMonitoring() {
        if (isMonitoring) return

        isMonitoring = true

        // Start foreground service with notification
        val notification = createNotification(0.0, "Starting...")
        startForeground(NOTIFICATION_ID, notification)

        // Notify Flutter side to start monitoring
        methodChannel?.invokeMethod("startMonitoring", null)

        android.util.Log.i("NoiseService", "Noise monitoring service started")
    }

    private fun stopMonitoring() {
        isMonitoring = false

        // Notify Flutter side to stop monitoring
        methodChannel?.invokeMethod("stopMonitoring", null)

        // Stop foreground service
        stopForeground(true)
        stopSelf()

        android.util.Log.i("NoiseService", "Noise monitoring service stopped")
    }

    private fun createNotification(spl: Double, status: String): Notification {
        val splText = if (spl > 0) "${spl.toInt()} dB" else "-- dB"

        // Intent to open the app when notification is tapped
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop monitoring action
        val stopIntent = Intent(this, NoiseMonitoringService::class.java).apply {
            action = ACTION_STOP_MONITORING
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OpenNoiseNet Monitoring")
            .setContentText("$status • Current: $splText")
            .setSmallIcon(R.drawable.ic_notification) // You'll need to add this icon
            .setContentIntent(pendingIntent)
            .addAction(R.drawable.ic_stop, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(spl: Double, status: String) {
        if (!isMonitoring) return

        val notification = createNotification(spl, status)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        super.onDestroy()

        // Clean up Flutter engine
        flutterEngine?.destroy()
        FlutterEngineCache.getInstance().remove(FLUTTER_ENGINE_ID)

        android.util.Log.i("NoiseService", "Noise monitoring service destroyed")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)

        // Continue monitoring even when app is removed from recent apps
        // This ensures continuous monitoring for citizen science purposes
        if (isMonitoring) {
            android.util.Log.i("NoiseService", "App removed from recent apps, continuing monitoring")
        }
    }
}
