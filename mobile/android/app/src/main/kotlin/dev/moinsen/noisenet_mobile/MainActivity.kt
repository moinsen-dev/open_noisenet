package dev.moinsen.noisenet_mobile

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        SensorEngine.activity = this
        return SensorEngine.obtain(context)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (SensorEngine.activity === this) SensorEngine.activity = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
