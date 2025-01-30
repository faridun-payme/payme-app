rootProject.name = "payme-android"
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

dependencyResolutionManagement {

    repositories {
        google()

        mavenCentral()

        maven { url = uri("https://jitpack.io") }
    }

    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

include(
    ":convention",
    ":obfuscation"
)