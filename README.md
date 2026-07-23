## AI 算法开关状态

更新时间：2026-06-08

- 当前默认关闭 RKNN stain infer：`BuildConfig.ENABLE_RKNN_STAIN_APP=false`。
- 当前保留运行的算法链路：`lens_det`、`zero_point`。
- 需要重新引入 RKNN 时，构建参数使用 `-PENABLE_RKNN_STAIN_APP=true` 打开。
- RKNN 关闭时，App 层 JPG/I420/RGB/Video/Stream 入口会短路，不再提交 RKNN 推理任务；快速模式/工程师模式的 PR1 帧仍保留给 `lens_det` 和 `zero_point` 使用。
- `zero_point` Auto 方法一：快速/工程师模式的连续焊/点焊检测到偏移后，仅缓存触发弹窗的 `production_json` 偏移；进入设置页点击 Auto 时才按该偏移写入 Zero Offset。
- `zero_point` Auto 方法二：没有 pending JSON 时，在设置页将枪头对准安全区域并按住扳机后点击 Auto；App 会先按最近一次连续焊/点焊上下文下发设备控制、工艺参数和高级设置（测试脉冲临时将 Zero Offset 设为 0），再录临时视频并通过 Modbus 临时开启激光使能，物理出光仍由扳机触发，**15 秒**使能窗口内未出光则失败，关使能后再用在线/离线结果将 Zero Offset **设为** `round(-offset_x/3)`（绝对值，非在现值上累加）；失败提示「校正失败请再次点击 Auto 或者手动校正」。

## Build & Install (Makefile)

### Channel selection

- Default: OTA manifest `**staging.json**`, `BuildConfig.RELEASE_CHANNEL` `**false**` (non-production API tier).
- `**RELEASE=1**`: manifest `**release.json**`, `BuildConfig.RELEASE_CHANNEL` `**true**`, install/pack uses `**app-release.apk**` (not the staging copy path), and zip `**PACK_VERSION**` drops the `-beta` suffix.

### APK output path

- Default / staging: `make build` then install/pack from `app/build/outputs/apk/staging/app-staging.apk` (copied from `app-release.apk` after assemble).
- `**RELEASE=1**`: install/pack from `app/build/outputs/apk/release/app-release.apk` directly.

### Common commands

- Full build (native + APK, staging): `make build`
- Full build (release channel): `make build RELEASE=1`
- Daily Java/Kotlin sync to device/emulator: `make sync`
- Gradle APK only (no native): `make build-apk`
- Install (match your last build): `make install` or `make install RELEASE=1`
- Skip bundled library fetch when endpoint unavailable: `make build SKIP_BUNDLED_FETCH=1`

### System Priv-App 卸载旧版本并安装源码版本

当前设备上的 HMI App 是 system priv-app，不能按普通应用完整卸载。版本切换应覆盖系统 APK，并清理应用数据和 PackageManager 解析缓存。

```text
package: com.lasercyber.lws.ui
system apk: /system/priv-app/LwsUI/LwsUI.apk
launch activity: com.lasercyber.lws.ui/.activitys.SplashActivity
```

下面是以 `1.0.21 -> 源码 1.0.20` 为例。`DEVICE` 按实际设备号替换。

```bash
# 指定目标设备、包名和系统 APK 路径。
DEVICE=fd87348a9694574b
PKG=com.lasercyber.lws.ui
SYSTEM_APK=/system/priv-app/LwsUI/LwsUI.apk
APK=app/build/outputs/apk/release/app-release.apk

# 构建当前源码 release APK；当前源码 versionName 为 1.0.20。
./gradlew :app:assembleRelease

# 确认构建产物存在。
ls -lh "$APK"

# 确认 APK 内的版本号，本次应看到 versionName='1.0.20'、versionCode='89'。
/Users/ah0lic/Library/Android/sdk/build-tools/35.0.0/aapt dump badging "$APK" | grep "package:"

# 确认设备当前安装包版本、安装路径和是否存在 Hidden system packages。
adb -s "$DEVICE" shell dumpsys package "$PKG" | grep -E "codePath=|versionCode=|versionName=|Hidden system packages"

# 确认当前激活 APK 路径；干净的 system app 应指向 /system/priv-app/LwsUI/LwsUI.apk。
adb -s "$DEVICE" shell pm path "$PKG"

# 以 root 重启 adbd，后续才能清缓存、remount 和替换 system APK。
adb -s "$DEVICE" root

# 等待 adb root 后设备重新连接。
adb -s "$DEVICE" wait-for-device

# 停止当前运行中的 1.0.21 进程。
adb -s "$DEVICE" shell am force-stop "$PKG"

# 清除当前版本应用数据、数据库和缓存。
adb -s "$DEVICE" shell pm clear "$PKG"

# 尝试删除 /data/app 下的 updated system app 覆盖包。
# 如果返回 DELETE_FAILED_INTERNAL_ERROR，说明当前是纯 system priv-app，不能像普通应用卸载，可继续后续流程。
adb -s "$DEVICE" shell pm uninstall "$PKG"

# 检查 /data/app 是否还有该包覆盖安装残留；无输出表示没有残留。
adb -s "$DEVICE" shell find /data/app -maxdepth 2 -name "com.lasercyber.lws.ui-*" -print

# 清除 PackageManager 解析缓存，避免系统继续使用旧版本 metadata。
adb -s "$DEVICE" shell rm -rf /data/system/package_cache

# 重建 package_cache 目录，保证系统后续可以重新写入缓存。
adb -s "$DEVICE" shell mkdir -p /data/system/package_cache

# 将 system 分区重新挂载为可写。
adb -s "$DEVICE" remount

# 将源码构建出的 1.0.20 APK 推到设备临时目录。
adb -s "$DEVICE" push "$APK" /data/local/tmp/LwsUI-1.0.20.apk

# 用 1.0.20 APK 覆盖系统预装 APK。
adb -s "$DEVICE" shell cp /data/local/tmp/LwsUI-1.0.20.apk "$SYSTEM_APK"

# 设置 system APK 权限，PackageManager 要求 APK 对系统可读。
adb -s "$DEVICE" shell chmod 0644 "$SYSTEM_APK"

# 设置 system APK 属主为 root:root。
adb -s "$DEVICE" shell chown root:root "$SYSTEM_APK"

# 删除设备临时目录里的安装包。
adb -s "$DEVICE" shell rm -f /data/local/tmp/LwsUI-1.0.20.apk

# 替换 system APK 后再次清 PackageManager 解析缓存。
adb -s "$DEVICE" shell rm -rf /data/system/package_cache

# 重建 package_cache 目录。
adb -s "$DEVICE" shell mkdir -p /data/system/package_cache

# 重启设备，让 PackageManager 重新扫描 /system/priv-app/LwsUI/LwsUI.apk。
adb -s "$DEVICE" reboot

# 等待设备重启后重新连接。
adb -s "$DEVICE" wait-for-device

# 等待 Android 系统启动完成；输出 1 表示已完成。
adb -s "$DEVICE" shell getprop sys.boot_completed

# 重启后 adbd 可能回到非 root，重新获取 root 便于检查 /data/app 和缓存目录。
adb -s "$DEVICE" root

# 等待 adb root 后重新连接。
adb -s "$DEVICE" wait-for-device

# 验证设备实际解析出的版本；本次应看到 versionName=1.0.20、versionCode=89。
adb -s "$DEVICE" shell dumpsys package "$PKG" | grep -E "codePath=|versionCode=|versionName=|Hidden system packages"

# 验证当前激活路径仍是 system APK，而不是 /data/app 覆盖包。
adb -s "$DEVICE" shell pm path "$PKG"

# 再次确认 /data/app 没有覆盖包残留；无输出表示干净。
adb -s "$DEVICE" shell find /data/app -maxdepth 2 -name "com.lasercyber.lws.ui-*" -print

# 查看 PackageManager 缓存目录；重启后出现新缓存目录是正常的。
adb -s "$DEVICE" shell ls -la /data/system/package_cache
```

如果是从高版本回退到低版本，需要在安装完成后再清一次数据。本次 1.0.21 降到 1.0.20 时，旧数据库 schema 40 会导致 1.0.20 的 schema 39 启动崩溃，日志为 `A migration from 40 to 39 was required but not found`。处理命令如下：

```bash
# 停止应用，避免保活服务反复拉起旧进程。
adb -s "$DEVICE" shell am force-stop "$PKG"

# 清除高版本遗留数据库和缓存，解决 Room 降级 schema 不兼容。
adb -s "$DEVICE" shell pm clear "$PKG"

# 确认旧数据库目录已经被清掉；如果提示 No such file or directory，说明已清理。
adb -s "$DEVICE" shell ls -la /data/user/0/com.lasercyber.lws.ui/databases

# 启动 1.0.20。
adb -s "$DEVICE" shell am start -n "$PKG"/.activitys.SplashActivity

# 确认应用进程存在。
adb -s "$DEVICE" shell pidof "$PKG"

# 查看最近日志，确认没有新的 FATAL EXCEPTION。
adb -s "$DEVICE" logcat -d -t 120
```

验收标准：

```text
dumpsys package -> codePath=/system/priv-app/LwsUI
dumpsys package -> versionName=1.0.20
dumpsys package -> versionCode=89
pm path -> package:/system/priv-app/LwsUI/LwsUI.apk
/data/app 下没有 com.lasercyber.lws.ui-* 覆盖包
pidof com.lasercyber.lws.ui 能返回进程号
最近 logcat 没有新的 FATAL EXCEPTION
```

注意事项：

- 不要用 `adb install -r` 或 `pm install -r` 切换该 system priv-app 版本，否则可能生成 `/data/app` 覆盖包，造成当前激活版本和系统预装版本不一致。
- `pm uninstall "$PKG"` 对纯 system priv-app 可能返回 `DELETE_FAILED_INTERNAL_ERROR`，这不代表流程失败；它只说明系统预装包不能按普通应用卸载。
- 高版本回退到低版本时必须清应用数据，否则 Room 数据库 schema 降级可能导致启动崩溃。

SERIAL=10.0.1.191:5555
PKG=com.lasercyber.lws.ui
ZIP=/Users/ah0lic/release/libai_v1.2.7.zip
AI_VER=1.2.7
AI_ROOT="/data/data/${PKG}/files/bundled-libraries/ai-library"
TARGET="${AI_ROOT}/${AI_VER}"
LENS_CFG="/data/data/${PKG}/files/lens_guard/config.yaml"

adb -s $SERIAL root

adb -s $SERIAL push "$ZIP" /data/local/tmp/libai_v1.2.7.zip

adb -s $SERIAL shell "su 0 sh -c '
  set -e
  am force-stop $PKG
  rm -rf ${AI_ROOT}/*
  rm -rf /data/data/${PKG}/cache/ai-vision-video-inference
  rm -rf /data/data/${PKG}/files/ai-vision-inference-videos
  rm -f ${LENS_CFG}
  mkdir -p ${TARGET}
  unzip -o /data/local/tmp/libai_v1.2.7.zip -d ${TARGET}
  chown -R u0_a70:u0_a70 ${TARGET} ${AI_ROOT}
  chmod -R u+rwX ${TARGET}
  cp ${TARGET}/assets/config.yaml ${LENS_CFG}
  chown u0_a70:u0_a70 ${LENS_CFG}
  grep -E stain_conf|stain_nms|stain_max|use_rknn ${LENS_CFG}
  ls -la ${AI_ROOT}/
  ls -la ${TARGET}/jniLibs/arm64-v8a/libai.so
'"

adb -s $SERIAL shell "su 0 sqlite3 /data/data/${PKG}/databases/lws_ui UPDATE t_device_info SET AIVersion='1.2.7'; SELECT AIVersion FROM t_device_info LIMIT 1;"

adb -s $SERIAL shell "su 0 sh -c 'test ! -d /data/data/$PKG/cache/ai-vision-video-inference && echo cache_cleared; test ! -d /data/data/$PKG/files/ai-vision-inference-videos && echo videos_cleared'"


SKIP_RKNN_CONVERT=1 make ai AI_INSTALL=1 ENABLE_LENS_DET_APP=true AI_GRADLE_PROPS='-PRELEASE_CHANNEL=false'
