package dev.moinsen.noisenet_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SENSOR_CHANNEL = "com.opennoisenet.mobile/noise_service"

        var sensorChannel: MethodChannel? = null
            private set
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SENSOR_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, NoiseMonitoringService::class.java).apply {
                            action = NoiseMonitoringService.ACTION_START_MONITORING
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(this, NoiseMonitoringService::class.java).apply {
                            action = NoiseMonitoringService.ACTION_STOP_MONITORING
                            putExtra(NoiseMonitoringService.EXTRA_NOTIFY_FLUTTER, false)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "updateNotification" -> {
                        val intent = Intent(this, NoiseMonitoringService::class.java).apply {
                            action = NoiseMonitoringService.ACTION_UPDATE_NOTIFICATION
                            putExtra(
                                NoiseMonitoringService.EXTRA_SPL,
                                call.argument<Double>("spl") ?: 0.0,
                            )
                            putExtra(
                                NoiseMonitoringService.EXTRA_STATUS,
                                call.argument<String>("status") ?: "Monitoring",
                            )
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "isServiceRunning" -> result.success(NoiseMonitoringService.isRunning)
                    "isBatteryOptimizationDisabled" -> {
                        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(manager.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sensorChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
