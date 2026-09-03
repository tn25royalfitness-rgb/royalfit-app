plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json - required for firebase_core/firebase_messaging (Phase 4).
    id("com.google.gms.google-services")
}

android {
    namespace = "Royal.fit"
    // flutter.compileSdkVersion resolved to 33 in CI, too old for several
    // AndroidX libraries pulled in by flutter_secure_storage (they require
    // 34+). Pin explicitly rather than relying on the auto-detected value.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires this (Phase 5's full-screen
        // reminder takeover) - see the coreLibraryDesugaring dependency below.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "Royal.fit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Pinned to 23 (not flutter.minSdkVersion) because KeyGenParameterSpec
        // and BiometricPrompt, used for the device-key punch-in signing flow,
        // require API 23+.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // First-party AndroidX artifact for BiometricPrompt, used by
    // DeviceKeySigner.kt for the punch-in signing flow. Deliberately not a
    // third-party plugin - see the comment in DeviceKeySigner.kt.
    implementation("androidx.biometric:biometric:1.1.0")
    // Required by flutter_local_notifications - see isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
