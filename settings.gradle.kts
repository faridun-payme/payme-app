pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }

    versionCatalogs {
        create("libs") {
            from(files("build-logic/gradle/libs.versions.toml"))
        }
    }
}

// Path to the script
val script = File(rootDir, "pull-build-logic.sh")

// Run script before including build-logic
if (script.exists() && script.canExecute()) {
    println("Running pull-build-logic.sh before project sync...")
    val process = ProcessBuilder(script.absolutePath)
        .inheritIO()
        .start()
    val exitCode = process.waitFor()

    if (exitCode != 0) {
        error("pull-build-logic.sh failed with exit code: $exitCode")
    }
} else {
    println("Script not found or not executable: $script")
}

includeBuild("build-logic")

rootProject.name = "PaymeSuperApp"
include(":app")