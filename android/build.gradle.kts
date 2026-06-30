allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ─────────────────────────────────────────────────────────────────
    // Some Android-library plugins ship with compileSdk = 34 while
    // their transitive dependencies (e.g. flutter_plugin_android_lifecycle)
    // now demand compileSdk >= 36. CheckAarMetadata then aborts the build.
    // Force every library subproject to compile against the same SDK
    // level as the application.
    //
    // ⚠ This block must run BEFORE the `evaluationDependsOn(":app")`
    //   block below — otherwise the subprojects are already evaluated
    //   and Gradle refuses to attach an afterEvaluate callback.
    // ─────────────────────────────────────────────────────────────────
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
