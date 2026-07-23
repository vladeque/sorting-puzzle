import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginPackageName = "com.sortingpuzzle.securestore"

android {
    namespace = pluginPackageName
    compileSdk = 36

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = "SortingPuzzleSecureStoreBridge"
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField(
            "String",
            "GODOT_PLUGIN_NAME",
            "\"SortingPuzzleSecureStoreBridge\"",
        )
        setProperty("archivesBaseName", "SortingPuzzleSecureStoreBridge")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

dependencies {
    implementation("org.godotengine:godot:4.6.2.stable")
}
