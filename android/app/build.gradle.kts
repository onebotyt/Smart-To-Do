import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefinesString = project.findProperty("dart-defines") as? String
val isAiEdition = if (dartDefinesString != null) {
    try {
        val decoded = String(Base64.getDecoder().decode(dartDefinesString))
        decoded.contains("APP_EDITION=ai")
    } catch (e: Exception) {
        false
    }
} else {
    false
}

android {
    namespace = "com.synctask.synctask"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (isAiEdition) "com.synctask.aistudio" else "com.synctask.pure"
        manifestPlaceholders["appName"] = if (isAiEdition) "SyncTask AI Studio" else "SyncTask"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = "synctask"
            keyPassword = "synctask123"
            storeFile = file("synctask_release.jks")
            storePassword = "synctask123"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
