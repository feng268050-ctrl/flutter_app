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
        // 添加 JitPack 仓库
        maven { url = uri("https://jitpack.io") }
        maven { url=uri("https://maven.aliyun.com/repository/jcenter") }
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // 添加 JitPack 仓库
        maven { url = uri("https://jitpack.io") }
        maven { url=uri("https://maven.aliyun.com/repository/jcenter") }
    }
}

rootProject.name = "lwsui"
include(
    ":app",
    ":vendor:easydarwin",
    ":vendor:modbus4j",
    ":vendor:modbus4android",
    ":vendor:ynhapi",
)
 