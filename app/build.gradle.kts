plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// 版本号管理：优先使用命令行参数，其次使用 git tag，最后使用默认值
fun getVersionName(): String {
    // 检查是否有命令行参数
    val cmdVersion = project.findProperty("versionName") as? String
    if (cmdVersion != null && cmdVersion != "1.0.0") return cmdVersion

    // 尝试从 git tag 获取
    return try {
        val process = ProcessBuilder("git", "describe", "--tags", "--abbrev=0")
            .directory(project.rootDir)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().readText().trim()
        process.waitFor()
        if (process.exitValue() == 0 && output.startsWith("v")) {
            output.removePrefix("v")
        } else {
            "1.0.0"
        }
    } catch (e: Exception) {
        "1.0.0"
    }
}

fun getVersionCode(): Int {
    val cmdCode = project.findProperty("versionCode") as? String
    if (cmdCode != null && cmdCode != "1") return cmdCode.toIntOrNull() ?: 1

    return try {
        val process = ProcessBuilder("git", "rev-list", "--count", "HEAD")
            .directory(project.rootDir)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().readText().trim()
        process.waitFor()
        if (process.exitValue() == 0) {
            output.toIntOrNull() ?: 1
        } else {
            1
        }
    } catch (e: Exception) {
        1
    }
}

android {
    namespace = "com.fryfrog.hub"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.fryfrog.hub"
        minSdk = 24
        targetSdk = 35
        versionCode = getVersionCode()
        versionName = getVersionName()

        ndk {
            // 只生成 arm64-v8a 架构的 APK
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        create("release") {
            val ksFile = file("release.jks")
            if (ksFile.exists()) {
                storeFile = ksFile
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "fryfrog123"
                keyAlias = System.getenv("KEY_ALIAS") ?: "fryfrog"
                keyPassword = System.getenv("KEY_PASSWORD") ?: "fryfrog123"
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            val ksFile = file("release.jks")
            if (ksFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "fryfrog-hub-${versionName}-arm64.apk"
        }
    }
}

dependencies {
    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)

    // Compose
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.foundation:foundation")

    // Activity & Lifecycle
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // Core
    implementation("androidx.core:core-ktx:1.15.0")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Coil for image loading
    implementation("io.coil-kt:coil-compose:2.7.0")

    // Gson
    implementation("com.google.code.gson:gson:2.11.0")

    // MPV player - loaded via jniLibs

    // Debug
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
