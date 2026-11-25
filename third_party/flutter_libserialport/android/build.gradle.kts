group = "org.sigrok.flutter_libserialport"
version = "0.5.0-SNAPSHOT"

// Build adaptado a Gradle 9.x / AGP 9.x (Flutter 3.50+). El original de
// pub.dev (0.6.0) usaba `jcenter()` y un `buildscript` con AGP 8.7, que ya no
// se evalúan en Gradle 9. Se mantiene la compilación nativa original
// (libserialport para Android vía CMake).
buildscript {
    val agpVersion = "9.3.1"
    val kotlinVersion = "2.4.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:$agpVersion")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "org.sigrok.flutter_libserialport"
    compileSdk = 36

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21
    }

    externalNativeBuild {
        cmake {
            path = file("libserialport/CMakeLists.txt")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
