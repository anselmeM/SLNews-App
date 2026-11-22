import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing is read from android/key.properties, which is git-ignored.
// Debug-signed release builds are compile-validation artefacts only: they need
// an explicit opt-in so an accidental release build cannot silently ship the
// debug certificate. Store builds must always use a real keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()
val allowDebugSignedRelease =
    System.getenv("SLNEWS_ALLOW_DEBUG_SIGNED_RELEASE") == "true"

android {
    namespace = "com.slnews.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications >= 19 needs the Java 8+ API backport.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.slnews.mobile"
        // Sierra Leone's mobile fleet is dominated by Android 8+ devices, and
        // Hive/sqflite both need API 23+.
        // 26 (Android 8.0) is the floor of sentry_flutter 10's Android SDK. The app used
        // 24 until crash reporting was added; Android 8+ covers the overwhelming majority
        // of active devices and Play requires targetSdk 36 anyway.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The HTTPS App Link host, substituted into AndroidManifest.xml. Keep in
        // step with core/routing/deep_link_uri.dart and the web assetlinks route.
        manifestPlaceholders["deepLinkHost"] = "slnews.sl"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Shrinking stays off: R8 rules for every plugin would need
            // per-plugin validation, and the APK is small already.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/*.kotlin_module", "DebugProbesKt.bin")
        }
    }
}

// Debug builds must keep working without a release keystore, so the signing
// config above falls back to debug. This guard fails only when a release task
// is actually requested: an accidental release build must not silently ship the
// debug certificate, while PR compile-validation can opt in explicitly.
gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { task ->
        val name = task.name
        name.startsWith("assembleRelease") ||
            name.startsWith("bundleRelease") ||
            name.startsWith("packageRelease")
    }
    if (wantsRelease && !hasReleaseKeystore && !allowDebugSignedRelease) {
        throw GradleException(
            "Release signing is not configured. Set android/key.properties, " +
                "or set SLNEWS_ALLOW_DEBUG_SIGNED_RELEASE=true for a local " +
                "compile-validation build. Never distribute that APK.",
        )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
