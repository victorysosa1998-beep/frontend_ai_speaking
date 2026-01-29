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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Add this to the very bottom of android/build.gradle.kts
subprojects {
    // We apply the configuration directly to each subproject as it's added
    val project = this
    project.plugins.whenPluginAdded {
        // If the plugin is an Android Library (like flutter_ringtone_player)
        if (this is com.android.build.gradle.api.AndroidBasePlugin || 
            this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin")) {
            
            val android = project.extensions.getByType(com.android.build.gradle.BaseExtension::class.java)
            
            // Set the namespace only if it's currently missing
            if (android.namespace == null) {
                android.namespace = project.group.toString().ifEmpty { 
                    "com.fix.ringtone.${project.name.replace("-", "_")}" 
                }
                println("Setting namespace for plugin: ${project.name} -> ${android.namespace}")
            }
        }
    }
}