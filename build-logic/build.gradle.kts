plugins {
    `kotlin-dsl`
}

gradlePlugin {
    plugins {
        create("samplePlugin") {
            id = "payme.sample.plugin"
            implementationClass = "com.payme.buildlogic.SamplePlugin"
        }
    }
}