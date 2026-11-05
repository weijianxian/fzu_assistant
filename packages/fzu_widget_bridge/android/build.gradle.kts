group = "com.weijx.fzu_widget_bridge"
version = "0.0.1"

plugins {
    id("com.android.library")
}

// The host uses AGP 9 built-in Kotlin, Flutter's compile SDK, and Java 17.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.weijx.fzu_widget_bridge"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // Android's org.json implementation is a stub in host JVM tests.
    testImplementation("org.json:json:20240303")
}
