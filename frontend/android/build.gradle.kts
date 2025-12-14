import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

fun org.gradle.api.artifacts.dsl.RepositoryHandler.addMirrorsWhenEnabled() {
    val enableMirrors = System.getenv("USE_LOCAL_MAVEN_MIRRORS")?.toBoolean() ?: false

    if (enableMirrors) {
        maven {
            url = uri("http://192.168.1.100:8081/repository/android-group/")
            metadataSources { mavenPom(); artifact() }
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/google")
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

allprojects {
    repositories {
        google()
        mavenCentral()
        addMirrorsWhenEnabled()
    }
}

// Move build directories outside android folder (optional)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
