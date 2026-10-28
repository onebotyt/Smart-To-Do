import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefinesString = project.findProperty("dart-defines") as? String
val editionProp = project.findProperty("APP_EDITION") as? String
val isAiEdition = editionProp == "ai" || (dartDefinesString != null && run {
    try {
        val decoded = String(Base64.getDecoder().decode(dartDefinesString))
        decoded.contains("APP_EDITION=ai") || decoded.contains("APP_EDITION%3Dai")
    } catch (e: Exception) {
        false
    }
})

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
        manifestPlaceholders["appIcon"] = if (isAiEdition) "@mipmap/ic_launcher_ai" else "@mipmap/ic_launcher"
        manifestPlaceholders["appIconRound"] = if (isAiEdition) "@mipmap/ic_launcher_ai_round" else "@mipmap/ic_launcher_round"
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
