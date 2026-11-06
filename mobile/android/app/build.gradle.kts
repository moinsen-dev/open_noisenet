import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Store credentials live outside the checkout. Debug builds never need them.
val uploadProperties = Properties()
val uploadConfig = providers.environmentVariable("NOISENET_ANDROID_SIGNING_PROPERTIES").orNull
if (uploadConfig != null) {
    file(uploadConfig).inputStream().use { uploadProperties.load(it) }
    for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!uploadProperties.getProperty(key).isNullOrBlank()) { "Missing upload signing field: $key" }
    }
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

    signingConfigs {
        create("upload") {
            if (uploadConfig != null) {
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
            }
        }
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
            signingConfig = signingConfigs.getByName("upload")
        }
    }
}

flutter {
    source = "../.."
}


// AGP can silently emit unsigned artifacts if a signing configuration is empty.
tasks.matching { it.name in setOf("packageRelease", "packageReleaseBundle", "signReleaseBundle", "bundleRelease", "assembleRelease") }.configureEach {
    doFirst {
        check(uploadConfig != null) {
            "Release signing requires NOISENET_ANDROID_SIGNING_PROPERTIES (see docs/mobile/store-beta.md)."
        }
    }
}
