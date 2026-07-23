# 模拟器系统级运行 App（摘要）

> 原文：[`../system_run.md`](../system_run.md)  
> 更新：2026-05-15

## 一句话

用 **`make emulator` + `make run`** 在可写 `/system` 的 AVD 上以 **priv-app** 方式安装 lws-ui，模拟真机系统级部署；**不要用 Android Studio 绿色 Run**（会装到 `/data/app`）。

## 推荐流程

```bash
# 终端 1：启动模拟器、remount、推 privapp 白名单
make emulator

# 终端 2：构建 + 推 APK 到 /system/priv-app + 重启 + 启动
make run
```

## 关键环境变量

| 变量 | 作用 |
|------|------|
| `ADB_SERIAL` | 指定设备（默认 `emulator-5554`） |
| `EMULATOR_PORT` | 模拟器端口，默认 5554 |
| `MODEL` | 写入 `/system/etc/model.properties`；AVD 名 |
| `SKIP_BUNDLED_FETCH=1` | 跳过内置资源拉取 |
| `RELEASE=1` | release 构建路径 |

根目录 `.env` 会被 Makefile 加载；命令行变量优先。

## 底层脚本

- `scripts/emulator-launch.sh` → `make emulator`
- `scripts/emulator-system-run.sh` → `make run`

APK 目标路径：`/system/priv-app/LwsUI/LwsUI.apk`

## 典型故障：重启卡在启动动画

**现象**：`pm path` 报 `Can't find service: package`

**根因**：Manifest 申请了 privileged 权限，但 `privapp-permissions-com.lasercyber.lws.ui.xml` 未列入白名单 → `system_server` 崩溃。

**修复**：在 XML 中补充缺失权限（如 `MOUNT_UNMOUNT_FILESYSTEMS`），重新 push 并 reboot。

## 调试方式

系统级安装后，用 **Run → Attach Debugger to Android Process**，选 `com.lasercyber.lws.ui`。

## 其它 Makefile 目标

| 目标 | 说明 |
|------|------|
| `make build` | assembleRelease + staging APK |
| `make install` | 真机 priv-app 安装（需先 build） |
| `make deploy` | build + install |
| `make test` | CI + instrumentation |

## 注意

- 需 AOSP / Google APIs 镜像（可 `adb root`），非 Play 商店镜像
- 模拟器无 NPU，AI Vision 离线推理不可用属预期
- 完整变量表与手动步骤见原文档
