// android/build.gradle.kts ← PROJECT-LEVEL
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.repositories
import com.android.build.gradle.BaseExtension
import org.gradle.api.Project
import java.io.File

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.5.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.20")
        classpath("com.google.gms:google-services:4.4.2") // Firebase
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // AUTO-FIX NAMESPACE FOR ALL PLUGINS (including flutter_inappwebview)
    // This version compiles 100% without smart cast errors
    afterEvaluate {
        extensions.findByType(BaseExtension::class.java)?.apply {
            if (namespace == null || namespace?.isEmpty() == true) {
                namespace = "com.example.${project.name.replace("-", "_")}"
            }
        }
    }
}

// Custom build directory (your existing setup)
val newBuildDir: File = rootProject.layout.buildDirectory.dir("../../build").get().asFile
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val subprojectBuildDir: File = newBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}