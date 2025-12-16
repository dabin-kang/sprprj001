plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    // 1. compileSdk 버전 업데이트 (최신 camera_android 요구사항: 36 이상)
    compileSdk = 36 // or 34, 35 depending on your flutter sdk setup, but 36 is highest required.

    // 2. NDK 버전 업데이트 (대부분의 플러그인 요구사항: 27.0.12077973)
    ndkVersion = "27.0.12077973" // 로그에서 권장하는 버전

    namespace = "com.example.sprprj001"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Put your application ID here.
        applicationId = "com.example.sprprj001"
        // 3. minSdkVersion 업데이트 (tflite_flutter 요구사항: 26 이상)
        minSdk = 26
        targetSdk = 34 // or 36 if you update compileSdk, but targetSdk 34 is generally safe
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
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
