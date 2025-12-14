pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    fun org.gradle.api.artifacts.dsl.RepositoryHandler.addPluginMirrorsWhenEnabled() {
        val enableMirrors = System.getenv("USE_LOCAL_MAVEN_MIRRORS")?.toBoolean() ?: false
        if (enableMirrors) {
            maven {
                url = uri("http://127.0.0.1:8081/repository/android-group/")
                metadataSources { mavenPom(); artifact() }
            }
            maven {
                url = uri("https://maven.aliyun.com/repository/google")
                metadataSources { mavenPom(); artifact() }
            }
            maven {
                url = uri("https://maven.aliyun.com/repository/gradle-plugin")
                metadataSources { mavenPom(); artifact() }
            }
            maven {
                url = uri("https://maven.aliyun.com/repository/central")
                metadataSources { mavenPom(); artifact() }
            }
            maven {
                url = uri("https://mirrors.huaweicloud.com/repository/maven/google")
                metadataSources { mavenPom(); artifact() }
            }
        }
    }

    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
        addPluginMirrorsWhenEnabled()
    }

    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "org.jetbrains.kotlin.android") {
                useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
            }
        }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.23" apply false
}

include(":app")
