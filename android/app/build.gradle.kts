plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_app"
    compileSdk = 36
    ndkVersion = "27.0.12077973" // <-- Set to the required NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // <-- Recommended for Firebase
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("debug")

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
    outputs.all {
        val appName = "SmartDiet"
        val versionName = versionName
        val variantName = buildType.name
        (this as? com.android.build.gradle.internal.api.BaseVariantOutputImpl)?.outputFileName =
            "${appName}-v${versionName}-${variantName}.apk"
    }
}


}

flutter {
    source = "../.."
}

// Apply the Google Services plugin for Firebase
apply(plugin = "com.google.gms.google-services")

dependencies {
    implementation("com.google.android.gms:play-services-auth:21.0.0")
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.0")
    implementation("com.google.mlkit:text-recognition-korean:16.0.0")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.0")

    implementation("com.squareup.okhttp3:okhttp:4.10.0")
}