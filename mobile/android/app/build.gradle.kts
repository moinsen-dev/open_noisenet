plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.moinsen.noisenet_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "dev.moinsen.noisenet_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // Required by tflite_flutter package
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["applicationLabel"] = "OpenNoiseNet"
    }

    buildTypes {
        debug {
            val isolatedTestSuffix = System.getenv("NOISENET_TEST_APP_SUFFIX")
            if (System.getenv("NOISENET_FIELD_TEST_APP") == "1") {
                applicationIdSuffix = ".fieldtest"
                manifestPlaceholders["applicationLabel"] = "OpenNoiseNet Field Test"
            } else if (isolatedTestSuffix != null) {
                require(isolatedTestSuffix.matches(Regex("[a-z][a-z0-9_]*")))
                applicationIdSuffix = ".$isolatedTestSuffix"
                manifestPlaceholders["applicationLabel"] = "OpenNoiseNet Episode Test"
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
