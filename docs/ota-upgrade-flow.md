# 设备 OTA 升级流程（ZIP 下载与解压）

本文档根据 Android 客户端源码整理，描述 **从哪里检测新版本**、**从哪里下载 ZIP**、**如何解压与落盘路径**，以及 **解压后各组件如何更新**。  
客户端在已 pin 的 Worker API Origin 上拉取 **manifest JSON**（文件名由 `BuildConfig.LWS_MANIFEST_JSON_FILE` 指定），解析后与当前应用版本比较；若有更新，再用 manifest 里的 **`url`** 通过 **HTTP** 下载 ZIP。JSON 字段以运维配置为准。

**主要源码**：`DeviceInformationFragment`、`DeviceApiOriginConfig`、`UpgradeActivity`、`ControllerUpgradeHandler`、`UpgradeFileReaderUtils`、`DeviceUpgradeRegisterAddress`、`BundledFirmwareBootstrap`（首页内置固件）。

---

## 0. 首页内置固件（与 OTA 并行）

除在线 `lws-app` OTA zip 外，控制卡固件还可随 APK 内置在 `assets/firmware/`（构建时由 `bundleFirmwareAssets` 从仓库 `firmware/` 拷贝）。

| 项目 | 说明 |
|------|------|
| 检测入口 | **仅首页** `MainActivity#onResume` → `BundledFirmwareBootstrap#checkAndPromptIfNeeded` |
| 前置条件 | Modbus 可用、缓存中有有效 `DeviceStatus`、内置固件 HW 匹配且 SW 高于设备 |
| 用户确认 | **必须弹窗确认**后才开始 Modbus OTA；无自动静默刷写 |
| 刷写链路 | 与 OTA 相同：`BinUtil.binFileConvert` → `ControllerUpgradeHandler` |
| 互斥 | `FirmwareUpgradeCoordinator` 保证 bundled 与 `UpgradeActivity` OTA 不同时刷写 |

其他界面（工程师模式、设置、监测等）**不**检测或提示内置固件升级。

---

## 1. 检测新版本（入口与远端对象）

### 1.1 用户操作与入口

- **界面**：设备信息页 → 检查升级。  
- **类与方法**：`com.lasercyber.lws.ui.activitys.setting.fragment.DeviceInformationFragment#checkUpgrade`。

### 1.2 远端地址与前置条件

- **Base URL**：`DeviceApiOriginConfig.getPinnedBase()`（Worker API Origin 探测成功后写入内存；未 pin 时无法拉 manifest）。  
- **Manifest URL**：`DeviceApiOriginConfig.lwsAppManifestHttpUrl(BuildConfig.LWS_MANIFEST_JSON_FILE)`，即 **`{pinnedBase}/view/lws-app/{LWS_MANIFEST_JSON_FILE}`**（路径中间无多余斜杠，由 `joinUnderBase` 拼接）。  
- **读取方式**：后台线程里 **`HttpURLConnection`** 对 manifest URL 发 **GET**，连接/读超时分别为 20s / 60s；响应体按 **UTF-8** 整段读成字符串后 **`Gson`** 反序列化为 `Map<String, String>`。

### 1.3 版本描述文件（manifest JSON）

| 项目 | 说明 |
|------|------|
| 文件名 | `BuildConfig.LWS_MANIFEST_JSON_FILE`：`staging.json` 或 `release.json`（Makefile 下由是否 `RELEASE=1` 决定），见 `app/build.gradle.kts` |
| 读取方式 | 见 §1.2：`HttpURLConnection` GET manifest URL |
| 内容格式 | **JSON 对象**，`Map<String, String>`，当前逻辑使用的键：`title`、`content`、`version`、**`url`**（ZIP 的绝对下载地址，见 `UpgradeActivity`） |
| 校验 | 若缺少 `version` 或 `url` 则抛错并提示升级失败 |

### 1.4 是否有新版本的判定

- **类与方法**：`DeviceInformationFragment#checkUpgrade` 内联逻辑（`SemanticVersionHelper.compare`）。  
- **规则**：若 manifest 中 `version` 与 **`BuildConfig.VERSION_NAME`** 做 semver 比较 **≤ 0**（即远程不高于当前应用 `versionName`），则视为**已是最新版本**（弹窗提示，不进入升级页）。  
- **否则**：携带 `title`、`content`、`version`、`downloadUrl`（= manifest 的 `url`）以及当前 `DeviceInfo`（`Intent` extra `info`）跳转 `UpgradeActivity`。

### 1.5 交互限制

- 检查升级有 **10 秒防连点**；检查过程中会先弹出等待类对话框，约 10 秒后关闭。

---

## 2. 下载新版本 ZIP（URL 与本地路径）

### 2.1 触发时机

- 进入 `UpgradeActivity` 后，用户点击 **立即升级**，调用 `upgradeSystem()`。

### 2.2 远端 ZIP 来源

| 项目 | 说明 |
|------|------|
| 下载 URL | `Intent` extra `downloadUrl`，来自 manifest JSON 的 **`url`** 字段（一般为 **HTTPS 绝对地址**，由运维/发布系统配置） |
| 版本字符串 | `Intent` extra `version`，来自 manifest 的 **`version`**（与 semver 比较、本地 ZIP 文件名基名共用） |

**约定**：`url` 须可被设备端直接访问（匿名下载或 URL 自带鉴权参数均可）。`version` 与 ZIP 内容版本应对齐，便于排查「有更新但包不对」等问题。

### 2.3 本地下载路径

- **根目录**：`Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)`（系统公共 **下载** 目录）。  
- **本地 ZIP 文件名**：对 `version` 去首尾空白后，将非 `[a-zA-Z0-9._-]` 字符替换为 `_` 得到 `zipBase`；若 `version` 为空则 `zipBase` 为 `ota`。最终 **`zipName = zipBase + ".zip"`**，完整路径 **`ZIP_PATH = {公共下载目录}/{zipName}`**（见 `UpgradeActivity#upgradeSystem`）。

### 2.4 下载实现要点

- 使用 **`HttpURLConnection`** 对 `downloadUrl` 发 GET（`setInstanceFollowRedirects(true)`），连接超时 **30s**，读超时 **`TIMEOUT_MS`（20 分钟，与整段升级 UI 超时一致）**。  
- **写入**：`writeZipToLocal` 以 **8KB** 缓冲从响应流写入 `ZIP_PATH`；若响应头 **`Content-Length`** 已知，则按已写字节更新下载进度条，并在收尾用 **`totalFileSize`** 与本地文件长度校验。  
- **超时**：升级开始后 `handler.postDelayed(timeoutRunnable, 1200000)`（20 分钟），超时弹窗并结束升级 UI 状态。

---

## 3. 解压过程与解压目录

### 3.1 解压目标目录

| 项目 | 说明 |
|------|------|
| 常量 / 路径 | `UNZIP_DIR` = `{公共下载目录}/update_unzip/` |
| 创建方式 | 解压前 **`deleteDir(update_unzip)`** 删除旧目录，再 `mkdirs()` |

### 3.2 解压实现要点（`unzipFile`）

- 先校验 ZIP 存在、非空、且 **文件大小等于下载阶段记录的 `totalFileSize`**（避免不完整文件）。  
- 使用 **`ZipInputStream`** + **`BufferedInputStream(FileInputStream)`**，条目名字符集 **`Charset.forName("GBK")`**（兼容中文路径）。  
- 逐 `ZipEntry` 写出：目录则 `mkdirs`，文件则缓冲写出 8KB 块。

### 3.3 解压后的处理顺序

- `parseUnzipFiles(UNZIP_DIR)` 列出目录下文件；通过 `sortApkToLast` 调整顺序：**`.bin` 插入靠前**（在「非 apk」列表之后追加 bin 列表），**`.apk` 留在靠后**（实际 APK 安装放在控制卡升级结束流程中执行，见下文）。  
- 对 **非 `.apk`** 文件调用 `upgradeType(file)` 做分类升级。

---

## 4. 解压后如何更新各组件

### 4.1 总览

| 组件 / 字段 | 是否依赖 ZIP 内文件名 | 更新时机与说明 |
|-------------|------------------------|----------------|
| **System Version** | 否 | 在 `controllerBardUpgradeEnd()` 中设为 Intent 传入的 `versionCode`（即 manifest 的 `version`） |
| **Firmware Version** | 是（固定下标） | 控制卡 **升级成功** 后，用 `UpgradeFileReaderUtils.getFileSoftwareVersion(binFileName)` 写入 |
| **Process Library Version** | 是（`_V` 规则） | `.xlsx` 且版本判断通过时，`proUp` 写入 |
| **App / AI native** | 是（APK `_V` 规则） | AI 库（`libai.so` 等）随 APK `jniLibs` 一体发布；升级 APK 即升级 AI，无独立 `.ai` 包 |
| **UI Version** | 是（`_V` 规则） | `controllerBardUpgradeEnd()` 中对 `.apk` 判断通过后静默安装并写入 |

### 4.2 文件名中的版本号（两套规则）

**规则 A — `getBeginVersion`（工艺库 `.xlsx`、`.apk`）**

- 取文件名中 **最后一个 `_V` 之后** 到 **最后一个 `.` 之前** 的子串。  
- 若缺少 `_V` 或格式不合法，得到空串，可能导致「是否升级」判断异常，需保证命名形如：`xxx_V{版本}.xlsx` / `.apk`。

**规则 B — `UpgradeFileReaderUtils`（控制卡 `.bin`）**

- **硬件版本**：文件名子串 **索引 `[6, 10)`** 解析为整数。  
- **软件版本**：文件名子串 **索引 `[11, 15)`** 解析为整数。  
- 文件名长度不足 15 会返回 `null`。  
- 下发前在 `ControllerUpgradeHandler.sendControllerUpgradeInfo` 中与设备 `DeviceStatus` 的软硬件版本比对；与设备一致则报「版本相同无需升级」。  
- 升级成功后写入 `DeviceInfo.firmwareVersion` 的是 **软件版本**（`getFileSoftwareVersion` → 字符串）。

**注意**：`.bin` **不使用** `_V` 规则；与工艺库/APK 的命名约定不同，打 ZIP 包时需同时满足两套规则（若包内同时含 bin 与 xlsx/apk）。

### 4.3 控制卡固件（`.bin`）— Modbus OTA

- `BinUtil.binFileConvert` → `ControllerUpgradeHandler.sendControllerUpgradeInfo(file)`：下发固件信息、缓存文件、加快设备状态轮询并挂升级状态检查任务。  
- 设备通过状态字请求数据包后，`ControllerUpgradeHandler.upgradeHandler` 按偏移分包写寄存器（地址与命令见 `DeviceUpgradeRegisterAddress`、`DeviceUpgradeConstant`）。  
- 结果通过 **EventBus** `DeviceUpgradeEvent` 通知 `UpgradeActivity#controllerBardUpgradeResult`；成功则更新 `firmwareVersion` 并进入 `controllerBardUpgradeEnd()`。

### 4.4 工艺库（`.xlsx`）

- `EasyExcelUtil.proFileConvert` 解析后 **`resetAllProcessData`** 替换工艺库相关数据，并 `setProcessLibVersion(版本)`（版本来自规则 A）。

### 4.5 应用 APK（`.apk`）

- 在 **`controllerBardUpgradeEnd()`** 中遍历解压文件列表，对 `.apk` 用规则 A 取版本，与 **已安装 APK 的 `PackageManager.versionName`**（或 `BuildConfig.VERSION_NAME`）比较后决定是否 **`YNHAPI.installApkSilently`**；`DeviceInfo.setUiVersion` 仅作内存字段（`@Ignore`），供 MQTT 打包前与 APK 对齐，**不写入 Room**。

### 4.6 整段流程收束

- `controllerBardUpgradeEnd()` 中处理 APK、弹成功/失败、**`devModel.updateOrAddInfo`** 持久化 `DeviceInfo`（**不再**写入 Room `systemVersion`；应用版本以已安装 APK 为准）。  
- **`cleanTempFiles()`** 会删除公共下载目录下 **所有文件**、当前 ZIP 及 **`update_unzip` 整个目录**；若下载目录中有用户其它文件会被一并删除（当前实现副作用，运维与测试需注意）。

---

## 5. 流程简图（文字）

1. **检查更新**：对已 pin 的 Worker base 请求 **`/view/lws-app/{manifest文件}`** → 解析 JSON → 与 **`BuildConfig.VERSION_NAME`** semver 比较 → 有更新则带 `downloadUrl`（manifest 的 `url`）打开升级页。  
2. **下载**：对 **`downloadUrl` HTTP GET** → 写入公共 **`Downloads/{zipBase}.zip`**（`zipBase` 由 `version` 清洗得到，见 §2.3）。  
3. **解压**：校验大小 → 清空并创建 `Downloads/update_unzip/` → GBK 解压。  
4. **应用**：非 apk 先处理（bin / xlsx / ai）；bin 走 Modbus OTA；成功后统一在 `controllerBardUpgradeEnd` 更新 **`uiVersion`（若安装新 APK）** 等并写回数据库。  
5. **清理**：删除临时 ZIP 与解压目录（以及下载目录内其它文件，见上）。

---

## 6. 源码索引（便于跳转）

| 主题 | 类 / 方法 |
|------|-----------|
| Manifest URL | `DeviceApiOriginConfig#lwsAppManifestHttpUrl`、`#getPinnedBase` |
| 检查版本 | `DeviceInformationFragment#checkUpgrade`（`SemanticVersionHelper.compare`） |
| 下载与解压 | `UpgradeActivity#upgradeSystem`、`#writeZipToLocal`、`#unzipFile`、`#parseUnzipFiles` |
| 分类处理 | `UpgradeActivity#upgradeType`、`#getBeginVersion`、`#judgeVersion` |
| 控制卡 OTA | `ControllerUpgradeHandler`、`BinUtil` |
| bin 文件名版本 | `UpgradeFileReaderUtils#getFileHardwareVersion`、`#getFileSoftwareVersion` |
| 升级结束与持久化 | `UpgradeActivity#controllerBardUpgradeEnd`、`#controllerBardUpgradeResult` |
