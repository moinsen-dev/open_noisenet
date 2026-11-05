package dev.moinsen.noisenet_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One process-owned engine: attaching/detaching the screen must not own capture. */
object SensorEngine {
    private var engine: FlutterEngine? = null
    private var resumeOnBoot = false
    var activity: MainActivity? = null
    var channel: MethodChannel? = null
        private set

    fun obtain(context: Context, resume: Boolean = false): FlutterEngine {
        engine?.let { return it }
        val app = context.applicationContext
        resumeOnBoot = resume
        val created = FlutterEngine(app)
        engine = created
        channel = MethodChannel(created.dartExecutor.binaryMessenger,
            "com.opennoisenet.mobile/noise_service").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "consumeRestartRequest" -> {
                            result.success(resumeOnBoot && NoiseMonitoringService.isRequested(app))
                            resumeOnBoot = false
                        }
                        "startService" -> {
                            if (call.argument<Boolean>("resumeOnly") == true && !NoiseMonitoringService.isRequested(app)) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            NoiseMonitoringService.setRequested(app, true)
                            if (!NoiseMonitoringService.isRunning) {
                                ContextCompat.startForegroundService(app, Intent(app, NoiseMonitoringService::class.java).apply {
                                    action = NoiseMonitoringService.ACTION_START_MONITORING
                                })
                            }
                            result.success(true)
                        }
                        "stopService" -> {
                            NoiseMonitoringService.setRequested(app, false)
                            if (NoiseMonitoringService.isRunning) {
                                app.startService(Intent(app, NoiseMonitoringService::class.java).apply {
                                    action = NoiseMonitoringService.ACTION_STOP_MONITORING
                                })
                            }
                            result.success(true)
                        }
                        "updateNotification" -> {
                            if (NoiseMonitoringService.isRunning) {
                                app.startService(Intent(app, NoiseMonitoringService::class.java).apply {
                                    action = NoiseMonitoringService.ACTION_UPDATE_NOTIFICATION
                                    putExtra(NoiseMonitoringService.EXTRA_SPL, call.argument<Double>("spl") ?: 0.0)
                                    putExtra(NoiseMonitoringService.EXTRA_STATUS, call.argument<String>("status") ?: "Monitoring")
                                })
                            }
                            result.success(true)
                        }
                        "isServiceRunning" -> result.success(NoiseMonitoringService.isRunning)
                        "isBatteryOptimizationDisabled" -> {
                            val power = app.getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(power.isIgnoringBatteryOptimizations(app.packageName))
                        }
                        "requestBatteryOptimization" -> {
                            val screen = activity
                            if (screen == null) result.success(false) else {
                                screen.startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:${app.packageName}")))
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SENSOR_SERVICE", error.javaClass.simpleName, null)
                }
            }
        }
        // Uses the entrypoint compiled into this APK, including isolated field-test CA setup.
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }
}
