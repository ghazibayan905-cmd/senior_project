plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bayan.senior"
    compileSdk = 36   // ⚠️ الأفضل 34 بدل 36 حالياً
    ndkVersion = "28.2.13676358"

    // Required for TFLite models: YOLO loads via AssetFileDescriptor (openFd),
    // which fails if the asset is compressed inside the APK.
    androidResources {
        noCompress += setOf("tflite")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.senior"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}