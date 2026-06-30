import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val signingProps = Properties()
val signingPropsFile = rootProject.file("key.properties")
val hasSigning = signingPropsFile.exists()
if (hasSigning) {
    signingProps.load(FileInputStream(signingPropsFile))
}

android {
    namespace = "com.chickhop.chickenhop"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18.x relies on java.time.* via
        // core-library desugaring (Android < 26 fallback).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.chickhop.chickenhop"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(signingProps["storeFile"] as String)
                storePassword = signingProps["storePassword"] as String
                keyAlias = signingProps["keyAlias"] as String
                keyPassword = signingProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/DEPENDENCIES",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
