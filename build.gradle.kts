// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.android.library) apply false
//    id("org.jetbrains.kotlin.android") version "1.9.23" apply false // 适配 AGP 8.6.0 的 Kotlin 版本
}

tasks.register("devRefresh") {
    group = "dev"
    description = "Build, install, and restart debug app"

    dependsOn(":app:assembleDebug", ":app:installDebug")

    doLast {
        val serial = (findProperty("deviceSerial") as String?)?.trim().orEmpty()
        val adbPrefix = if (serial.isNotEmpty()) "adb -s $serial" else "adb"
        val appId = "com.lasercyber.lws.ui"
        val launchActivity = "com.lasercyber.lws.ui.MainActivity"

        exec {
            commandLine("sh", "-c", "$adbPrefix shell am force-stop $appId")
        }
        exec {
            commandLine("sh", "-c", "$adbPrefix shell am start -n $appId/$launchActivity")
        }
    }
}

tasks.register("deployPrivApp") {
    group = "dev"
    description = "Build release APK, install it as system priv-app, then reboot the configured adb device"

    dependsOn(":app:assembleRelease")

    doLast {
        val manifestJsonFile =
            (findProperty("MANIFEST_JSON_FILE") as String?)?.trim()?.takeIf { it.isNotEmpty() }
                ?: if ((findProperty("RELEASE") as String?)?.trim() == "1") "release.json" else "staging.json"

        val sourceReleaseApk = file("app/build/outputs/apk/release/app-release.apk")
        val targetApk =
            if (manifestJsonFile == "release.json") {
                sourceReleaseApk
            } else {
                file("app/build/outputs/apk/staging/app-staging.apk")
            }

        if (!sourceReleaseApk.isFile) {
            throw GradleException("APK not found at ${sourceReleaseApk.path}")
        }
        if (targetApk != sourceReleaseApk) {
            targetApk.parentFile.mkdirs()
            sourceReleaseApk.copyTo(targetApk, overwrite = true)
        }

        exec {
            commandLine(
                "chmod",
                "+x",
                "scripts/ci/prepare-device.sh",
                "scripts/ci/install-priv-app.sh",
                "scripts/ci/reboot-and-wait-boot.sh",
            )
        }
        exec {
            commandLine(
                "bash",
                "-lc",
                "set -euo pipefail; set -a; [[ -f .env ]] && source .env; set +a; ./scripts/ci/prepare-device.sh",
            )
        }
        exec {
            commandLine(
                "bash",
                "-lc",
                "set -euo pipefail; set -a; [[ -f .env ]] && source .env; set +a; ./scripts/ci/install-priv-app.sh '${targetApk.path}'",
            )
        }
        exec {
            commandLine(
                "bash",
                "-lc",
                "set -euo pipefail; set -a; [[ -f .env ]] && source .env; set +a; ./scripts/ci/reboot-and-wait-boot.sh",
            )
        }

        println("APK: ${targetApk.path}")
    }
}
