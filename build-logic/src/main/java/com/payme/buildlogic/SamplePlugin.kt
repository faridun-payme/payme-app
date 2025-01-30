package com.payme.buildlogic

import org.gradle.api.Plugin
import org.gradle.api.Project

class SamplePlugin : Plugin<Project> {
    override fun apply(project: Project) {
        project.tasks.register("helloTask") {
            doLast {
                println("Hello from Payme Sample Plugin!")
            }
        }
    }
}