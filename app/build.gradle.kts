
import groovy.json.JsonSlurper
import org.gradle.api.GradleException
import org.gradle.api.Project
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Properties
import java.util.zip.ZipInputStream

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
}

fun envOrDefault(name: String, default: String): String {
    val v = System.getenv(name)
    return if (v.isNullOrBlank()) default else v
}

/** For BuildConfig string literals: escape so Gradle emits valid Java string contents inside "...". */
fun escapeForDoubleQuotedJavaString(value: String): String =
    value.replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")

/** Read optional key from repo-root `local.properties` (gitignored). */
fun Project.loadOptionalLocalProperty(key: String): String? {
    val local = rootProject.file("local.properties")
    if (!local.isFile) return null
    return local.inputStream().use { input ->
        Properties().apply { load(input) }.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }
    }
}


/** OTA manifest filename in BuildConfig; Makefile passes `-P` from RELEASE=1 (release.json) vs default staging. */
val lwsManifestJsonFile: String =
    (project.findProperty("MANIFEST_JSON_FILE") as String?)?.trim()?.takeIf { it.isNotEmpty() }
        ?: "staging.json"

val releaseChannelFromProp: Boolean =
    (project.findProperty("RELEASE_CHANNEL") as String?)?.trim()?.equals("true", ignoreCase = true)
        ?: (lwsManifestJsonFile == "release.json")

/** Bundled AI native libs variant; set `ai.library.variant` in repo-root `local.properties` if needed. */
val aiLibraryVariant: String =
    project.loadOptionalLocalProperty("ai.library.variant")
        ?: ""

/** Optional manifest-style tier hint (`dev` / `test` / `prod`); also readable from env `APP_ENV` when building. */
val appEnvFromGradle: String =
    (project.findProperty("APP_ENV") as String?)?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv("APP_ENV")?.trim()?.takeIf { it.isNotEmpty() }
        ?: ""

android {
    namespace = "com.lasercyber.lws.ui"
    compileSdk = 34

    signingConfigs {
        create("release") {
            // Relative paths are resolved from the repository root (rootProject), not app/.
            val path = envOrDefault("SIGNING_STORE_FILE", "platform.jks")
            storeFile = rootProject.file(path)
            storePassword = envOrDefault("SIGNING_STORE_PASSWORD", "android")
            keyAlias = envOrDefault("SIGNING_KEY_ALIAS", "android")
            keyPassword = envOrDefault("SIGNING_KEY_PASSWORD", "android")
        }
    }

    defaultConfig {
        applicationId = "com.lasercyber.lws.ui"
        minSdk = 29
        targetSdk = 34
        versionCode = 1037
        versionName = "1.0.37"
        buildConfigField("String", "LWS_MANIFEST_JSON_FILE", "\"$lwsManifestJsonFile\"")
        buildConfigField("boolean", "RELEASE_CHANNEL", releaseChannelFromProp.toString())
        buildConfigField(
            "String",
            "AI_LIBRARY_VARIANT",
            "\"${escapeForDoubleQuotedJavaString(aiLibraryVariant)}\"",
        )
        buildConfigField(
            "String",
            "APP_ENV",
            "\"${escapeForDoubleQuotedJavaString(appEnvFromGradle)}\"",
        )
        multiDexEnabled = true // 必须开启，解决64K方法数超限

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Room schema export path for annotation processor
        javaCompileOptions {
            annotationProcessorOptions {
                arguments += mapOf(
                    "room.schemaLocation" to "$projectDir/schemas"
                )
            }
        }
        // 镜片引擎 native：`make ai` 将 libai.so、librknnrt.so、libc++_shared.so 写入 jniLibs，随 APK 打包
        ndk{
            // 老旧 32 位安卓设备
//            abiFilters.add("armeabi-v7a")
            // 以下为注释掉的其他架构，按需启用
//            abiFilters.add("armeabi")
            // 主流安卓
            abiFilters.add("arm64-v8a")
//            abiFilters.add("x86_64")
        }
    }
    splits {
        abi {
            isEnable = false // 单架构无需拆分，关闭可减少打包产物
        }
    }
    testBuildType = "release"

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Ensure Android Studio debug-on-device also uses platform signing.
            signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // 解决 META-INF 文件冲突（Kotlin DSL 语法）
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += "META-INF/gradle/incremental.annotation.processors"
            // AWS SDK / Netty / Apache HTTP client bring duplicate META-INF entries; merge must pick one.
            pickFirsts += "META-INF/INDEX.LIST"
            pickFirsts += "META-INF/DEPENDENCIES"
            pickFirsts += "META-INF/io.netty.versions.properties"
            // 若有其他冲突文件，继续添加
            // excludes += "META-INF/LICENSE"
            // excludes += "META-INF/NOTICE"
        }
    }
    buildFeatures {
        viewBinding = true
        buildConfig = true
        dataBinding = true
        compose = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    // 在这里配置 allprojects
//    allprojects {
//        repositories {
//            google()  // 谷歌仓库（必须，用于下载 Android 官方库）
//            mavenCentral()  // Maven 中央仓库（必须，用于下载 Eclipse Paho 等第三方库）
//            // jcenter()  // 可选，已停止维护，尽量不使用
//        }
//    }

    testOptions {
        unitTests {
            // Allow android.util.Log in JVM unit tests (otherwise Log.* throws "not mocked").
            isReturnDefaultValues = true
        }
    }
}

dependencies {

    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.activity)
    implementation(libs.constraintlayout)
    implementation(libs.com.github.dimezis.blurview3)
    implementation(libs.navigation.fragment)
    implementation(libs.navigation.ui)
    implementation(libs.core.ktx)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.activity.compose)
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation(libs.junit)
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    androidTestImplementation(libs.ext.junit)
    androidTestImplementation(libs.espresso.core)
    implementation(project(":vendor:ynhapi"))
    // 消息总线
    implementation(libs.eventbus)
    implementation(libs.annotations)
    // lombok
    implementation(libs.lombok)
    {
        exclude(group = "com.intellij", module = "annotations")
    }
    annotationProcessor(libs.lombok)
    {
        exclude(group = "com.intellij", module = "annotations")
    }
    // AndroidUtilCode工具
    implementation(libs.android.util.code)
    // retrofit 网络访问
    implementation(libs.retrofit) {
        exclude(group = "com.intellij", module = "annotations")
    }

    // 日志拦截器（调试用）
    implementation(libs.logging.interceptor)
    // RxJava 适配器（可选，用于异步回调，Java 常用）
    implementation(libs.adapter.rxjava3)
    // RxAndroid 配合主线程回调
    implementation(libs.rxandroid)
    // Gson 转换器（必须添加，否则找不到 GsonConverterFactory）
    implementation(libs.converter.gson)
    // Room 核心库
    implementation(libs.room.runtime) {
        exclude(group = "com.intellij", module = "annotations")
    }
    // Room 注解处理器（必须添加，否则无法生成数据库类）
    annotationProcessor(libs.room.compiler)
    {
        exclude(group = "com.intellij", module = "annotations")
    }
    // LiveData（与 Room 配合，实现数据观察）
    implementation(libs.lifecycle.livedata)
    // ViewModel（管理数据和业务逻辑）
    implementation(libs.lifecycle.viewmodel)
    // 可选：Room 与 RxJava 配合（本文以 LiveData 为主）
    implementation(libs.room.rxjava3)
    implementation("androidx.work:work-runtime:2.9.0")
    // LAN mDNS/DNS-SD: NsdManager on some OEMs (e.g. Rockchip) registers OK but does not announce on Wi-Fi; JmDNS multicasts reliably.
    implementation("org.jmdns:jmdns:3.5.11")
    // Embedded LAN HTTP API (device-local :5580; :8080 deprecated)
    implementation("org.nanohttpd:nanohttpd:2.3.1")
//    MPAndroidChart图表库
    implementation(libs.github.mpandroidchart)
    // hutool
    implementation(libs.hutool.all)
    // 适配16KB页面版本，https://developer.android.google.cn/guide/practices/page-sizes?hl=zh-cn

    // ZXing 简化版依赖（生成二维码核心功能）
    implementation(libs.zxing.android.embedded)
    implementation(libs.core)
//    xui
    implementation(libs.xui)
    // xui 工具类
    implementation(libs.xutil.core)
    implementation(libs.xutil.sub)

    // 引用本地 library 模块
    implementation(project(":vendor:easydarwin"))

    // modbus库
//    implementation(libs.com.github.licheedev.modbus4android)
    implementation(project(":vendor:modbus4android"))
    // Glide核心库
    implementation(libs.glide)
    // Glide注解处理器（可选，用于自定义模块）
    annotationProcessor(libs.compiler)
    implementation(libs.fragment)

    implementation(libs.recyclerview)

    implementation(libs.commons.net)// NTP校时依赖
//    EasyFloat 悬浮组件
    implementation(libs.easyfloat)
    // SmartRefreshLayout 核心库
    implementation(libs.refresh.layout.kernel)
    // 经典刷新头
    implementation(libs.refresh.header.classics)
    // 经典加载尾
    implementation(libs.refresh.footer.classics)
    // Media3 核心播放器
    implementation(libs.androidx.media3.exoplayer)
    // Media3 RTSP source (required for rtsp:// stream playback)
    implementation("androidx.media3:media3-exoplayer-rtsp:1.3.0")
    // Media3 UI 控件（替代原 ExoPlayer UI）
    implementation(libs.androidx.media3.ui)
    // Media3 兼容层（适配低版本 Android）
    implementation(libs.androidx.media3.common)

    // 1. EasyExcel 核心（保留原有版本）
    implementation(libs.easyexcel)
// 2. 补齐安卓缺失的 javax.xml.stream + Woodstox（EasyExcel / XML）。stax2-api 须与 woodstox-core-asl 一致（3.1.x），
    //    勿升到 4.x：4.x 中 EmptyIterator.getInstance() 签名与 woodstox 4.4.1 字节码不兼容，会在上传等路径触发 NoSuchMethodError。
    implementation(libs.stax.api)
    implementation(libs.woodstox.core.asl)
    implementation(libs.stax2.api)
// 4. 必要的辅助依赖
    implementation(libs.androidx.multidex.multidex4)
    implementation(libs.commons.collections4)
    implementation(libs.commons.compress)
    implementation(libs.java.semver)

    // Cloudflare R2 via AWS S3 API (STS credentials from Worker POST /v1/storage/r2/sts)
    val awsSdk2Version = "2.29.51"
    implementation(platform("software.amazon.awssdk:bom:$awsSdk2Version"))
    implementation("software.amazon.awssdk:s3")
    // S3Client defaults to Apache/Netty-style clients; on Android use HttpURLConnection-based client to avoid native/JNI crashes.
    implementation("software.amazon.awssdk:url-connection-client")
}

tasks.register("fetchBundledLibraries") {
    group = "build"
    description = "Download process-library from Workers API into src/main/assets"
    onlyIf { project.findProperty("skipBundledFetch") != "true" }
    doLast {
        val slurper = JsonSlurper()
        val base = "https://api-prod.lasercyber.workers.dev/view"
        val assetsRoot = layout.projectDirectory.file("src/main/assets").asFile
        val processLibrarySourceMeta = "__source_filename.txt"
        fun hasLocalBundledArtifact(artifact: String): Boolean {
            val dir = assetsRoot.resolve(artifact)
            if (!dir.isDirectory) return false
            val files = dir.listFiles()?.filter { it.isFile } ?: return false
            return when (artifact) {
                "process-library" -> files.any { it.name.lowercase().endsWith(".xlsx") }
                else -> files.isNotEmpty()
            }
        }
        fun digestHex(bytes: ByteArray): String {
            val md = MessageDigest.getInstance("SHA-512")
            return md.digest(bytes).joinToString("") { b -> "%02x".format(b) }
        }
        fun clearDirectoryFiles(dir: java.io.File) {
            val existing = dir.listFiles()
            if (existing != null) {
                for (file in existing) {
                    if (file.isFile()) {
                        file.delete()
                    }
                }
            }
        }

        fun extractProcessLibraryZip(bytes: ByteArray, targetDir: java.io.File) {
            ZipInputStream(bytes.inputStream()).use { zis ->
                var entry = zis.nextEntry
                while (entry != null) {
                    if (!entry.isDirectory) {
                        val name = entry.name.substringAfterLast('/').trim()
                        if (name.lowercase().endsWith(".xlsx")) {
                            targetDir.resolve(name).outputStream().use { out ->
                                zis.copyTo(out)
                            }
                        }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }
        }
        fun fetchArtifact(artifact: String) {
            try {
                val manifestUrl = URL("$base/$artifact/$lwsManifestJsonFile")
                val conn = manifestUrl.openConnection() as HttpURLConnection
                conn.connectTimeout = 120_000
                conn.readTimeout = 300_000
                conn.connect()
                if (conn.responseCode !in 200..299) {
                    throw GradleException("GET $manifestUrl failed: HTTP ${conn.responseCode}")
                }
                val text = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                @Suppress("UNCHECKED_CAST")
                val map = slurper.parseText(text) as Map<String, Any?>
                val downloadUrl = map["url"] as? String ?: error("$artifact manifest missing url")
                val filename = map["filename"] as? String ?: error("$artifact manifest missing filename")
                val sha512 = map["sha512"] as? String ?: error("$artifact manifest missing sha512")
                val dlConn = URL(downloadUrl).openConnection() as HttpURLConnection
                dlConn.connectTimeout = 120_000
                dlConn.readTimeout = 600_000
                dlConn.connect()
                if (dlConn.responseCode !in 200..299) {
                    throw GradleException("download $downloadUrl failed: HTTP ${dlConn.responseCode}")
                }
                val bytes = dlConn.inputStream.use { it.readBytes() }
                dlConn.disconnect()
                val got = digestHex(bytes).lowercase()
                val expected = sha512.trim().lowercase()
                if (!got.equals(expected, ignoreCase = true)) {
                    throw GradleException("$artifact sha512 mismatch")
                }
                val dir = assetsRoot.resolve(artifact)
                dir.mkdirs()
                if (artifact != "process-library") {
                    // Keep exactly one bundled artifact per type.
                    clearDirectoryFiles(dir)
                    val outFile = dir.resolve(filename)
                    outFile.writeBytes(bytes)
                    println("fetchBundledLibraries: wrote ${outFile.relativeTo(layout.projectDirectory.asFile)}")
                    return
                }
                clearDirectoryFiles(dir)
                val lowerName = filename.lowercase()
                when {
                    lowerName.endsWith(".xlsx") -> {
                        val outFile = dir.resolve(filename)
                        outFile.writeBytes(bytes)
                        dir.resolve(processLibrarySourceMeta).writeText(filename)
                        println("fetchBundledLibraries: wrote process-library xlsx ${outFile.relativeTo(layout.projectDirectory.asFile)}")
                    }
                    lowerName.endsWith(".zip") -> {
                        extractProcessLibraryZip(bytes, dir)
                        dir.resolve(processLibrarySourceMeta).writeText(filename)
                        val xlsxCount = dir.listFiles()?.count { it.isFile && it.name.lowercase().endsWith(".xlsx") } ?: 0
                        if (xlsxCount == 0) {
                            throw GradleException("process-library zip contains no xlsx entries: $filename")
                        }
                        println("fetchBundledLibraries: extracted process-library zip $filename with $xlsxCount xlsx files")
                    }
                    else -> throw GradleException("process-library unsupported filename suffix: $filename")
                }
            } catch (e: Exception) {
                if (hasLocalBundledArtifact(artifact)) {
                    println("fetchBundledLibraries: WARN network fetch failed for $artifact, using local cached assets (${e.javaClass.simpleName}: ${e.message})")
                    return
                }
                throw GradleException("fetchBundledLibraries: failed for $artifact and no local cached asset exists", e)
            }
        }
        fetchArtifact("process-library")
    }
}

tasks.register("bundleFirmwareAssets") {
    group = "build"
    description = "Copy control-card firmware from repo firmware/ into src/main/assets/firmware/"
    doLast {
        val firmwareDir = rootProject.layout.projectDirectory.dir("firmware").asFile
        val assetsDir = layout.projectDirectory.file("src/main/assets/firmware").asFile
        val pattern = Regex("^LSW01H(\\d{4})S(\\d{4})\\.bin$", RegexOption.IGNORE_CASE)

        /** Remove all files and subdirectories so only the freshly copied bin remains. */
        fun scrubFirmwareAssetsDir(dir: File) {
            if (dir.exists()) {
                val ok = dir.deleteRecursively()
                if (!ok && dir.exists()) {
                    throw GradleException("bundleFirmwareAssets: failed to clear ${dir.absolutePath}")
                }
            }
        }

        data class Candidate(val file: File, val hw: Int, val sw: Int)

        val candidates: List<Candidate> = firmwareDir.listFiles()
            ?.filter { it.isFile && pattern.matches(it.name) }
            ?.map { f ->
                val m = pattern.matchEntire(f.name)!!
                val hw = m.groupValues[1].toInt()
                val sw = m.groupValues[2].toInt()
                Candidate(f, hw, sw)
            }
            ?: emptyList()

        if (candidates.isEmpty()) {
            println("bundleFirmwareAssets: WARN no matching firmware bin in ${firmwareDir.absolutePath}, skipping")
            scrubFirmwareAssetsDir(assetsDir)
        } else {
            val best = candidates.maxWith(compareBy<Candidate> { it.sw }.thenBy { it.hw })
            scrubFirmwareAssetsDir(assetsDir)
            if (!assetsDir.mkdirs() && !assetsDir.isDirectory) {
                throw GradleException("bundleFirmwareAssets: cannot mkdir ${assetsDir.absolutePath}")
            }
            val dest = assetsDir.resolve(best.file.name)
            best.file.copyTo(dest, overwrite = true)
            println("bundleFirmwareAssets: wrote ${dest.relativeTo(layout.projectDirectory.asFile)}")
        }
    }
}

tasks.register("bundleMediaMtxAssets") {
    group = "build"
    description = "Warn or use prebuilt MediaMTX under src/main/assets/mediamtx/ (run make mediamtx)"
    doLast {
        val assetsDir = layout.projectDirectory.file("src/main/assets/mediamtx/arm64-v8a").asFile
        val binary = assetsDir.resolve("mediamtx")
        if (!binary.isFile) {
            println(
                "bundleMediaMtxAssets: WARN missing ${binary.absolutePath}; " +
                    "camera relay disabled until 'make mediamtx' is run"
            )
        } else {
            println("bundleMediaMtxAssets: OK ${binary.absolutePath}")
        }
    }
}

tasks.register("bundleAiDaemonAssets") {
    group = "build"
    description = "Warn if AI daemon missing from jniLibs/assets (run make ai)"
    doLast {
        val jniSo = layout.projectDirectory.file("src/main/jniLibs/arm64-v8a/liblws_ai_daemon.so").asFile
        val assetsDir = layout.projectDirectory.file("src/main/assets/ai_daemon/arm64-v8a").asFile
        val assetsBin = assetsDir.resolve("lws_ai_daemon")
        when {
            jniSo.isFile -> println("bundleAiDaemonAssets: OK ${jniSo.absolutePath}")
            assetsBin.isFile -> println(
                "bundleAiDaemonAssets: WARN missing ${jniSo.name} under jniLibs; " +
                    "assets fallback present (may fail noexec on spawn)"
            )
            else -> println(
                "bundleAiDaemonAssets: WARN missing daemon binary; " +
                    "AI daemon disabled until 'make ai' is run"
            )
        }
    }
}

tasks.register("bundleAiNativeLibs") {
    group = "build"
    description = "Verify libai.so runtime libs under src/main/jniLibs (run make ai)"
    doLast {
        val jniDir = layout.projectDirectory.file("src/main/jniLibs/arm64-v8a").asFile
        val required = listOf("libai.so", "librknnrt.so", "libc++_shared.so")
        val missing = required.filter { name -> !jniDir.resolve(name).isFile }
        if (missing.isNotEmpty()) {
            println(
                "bundleAiNativeLibs: WARN missing ${missing.joinToString()} under ${jniDir.absolutePath}; " +
                    "Lens Guard native disabled until 'make ai' is run"
            )
        } else {
            println("bundleAiNativeLibs: OK ${jniDir.absolutePath}")
        }
    }
}

tasks.named("preBuild") {
    dependsOn(
        "fetchBundledLibraries",
        "bundleFirmwareAssets",
        "bundleMediaMtxAssets",
        "bundleAiNativeLibs",
        "bundleAiDaemonAssets",
    )
}
