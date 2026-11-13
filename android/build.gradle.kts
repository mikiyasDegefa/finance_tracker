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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Lint bundled with AGP 9.3.x crashes ("NoSuchMethodError: java.util.List.removeLast()",
// https://issuetracker.google.com/issues/522845800) while analyzing Javadoc comments in
// plugin projects such as url_launcher_android, which fails release builds. The vital lint
// tasks are not required to produce release APKs/AABs, so skip them until the toolchain no
// longer ships the broken lint.
subprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital")) {
            enabled = false
            logger.lifecycle("Skipping $path (AGP lint crash workaround, issue 522845800)")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
