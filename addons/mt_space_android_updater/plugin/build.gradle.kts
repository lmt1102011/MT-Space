plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.mtspace.androidupdater"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = "MTSpaceAndroidUpdater"
        manifestPlaceholders["godotPluginPackageName"] = "com.mtspace.androidupdater"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.godotengine:godot:4.7.2.stable")
    implementation("androidx.core:core:1.15.0")
}
