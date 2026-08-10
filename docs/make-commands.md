# Make 命令参考

权威目标列表：仓库根目录运行 `make help`。本文补充每个目标的**用法、时机、环境变量/参数**。

工作流示例（按改动类型选命令链）仍在 [`README.md`](../README.md) → **Make commands**；构建加速见 [`docs/build-optimization.md`](build-optimization.md)；模拟器细节见 [`docs/p32-emulator.md`](p32-emulator.md)。

---

## 怎么传参数

| 方式 | 示例 |
|------|------|
| 命令行前缀 | `APP=lws_hmi SN=abc make push-app` |
| 仓库根 `.env` | 从 [`.env.example`](../.env.example) 复制；多数目标会 `source .env` |
| Make 覆盖（写入类） | `make write-identity BRAND=x MODEL=y PRODUCT_SN=z` |
| 位置参数 | `make connect 192.168.1.50`、`make extract-linux-sdk /path/to/volumes` |

**优先级：** 命令行已设置的变量通常覆盖 `.env`（Makefile `WITH_DOTENV` 对 `SN`/`IP`/`APP`/`OEM_*`/`FLUTTER_SDK`/`BUILD_*` 等做了显式覆盖）。

---

## 公共环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `APP` | `lws_hmi` | `app/<APP>/`；`*_hmi` → `/opt/hmi`；产物 `output/firmware/<APP>/` |
| `FLUTTER_SDK` | `flutter-sdk/` | 已安装主机 Flutter SDK 路径（`build-app` / debug / l10n）；**不是** `fetch-flutter-sdk` 的安装目标（那个用 `DEST`） |
| `BUILD_JOBS` | `8` | 并行编译任务数（Docker OOM 时可降到 4） |
| `BUILD_BIND_MOUNT` | 空 | macOS：`1` = 绑定挂载 SDK（易崩；优先用 Docker volume） |
| `DOCKER_IMAGE` | `lws-hmi-builder:22.04` | 构建镜像 |
| `DOCKER_PLATFORM` | `linux/amd64` | Docker 平台 |
| `DOCKER_VOLUME` | `lws-hmi-sdk` | macOS SDK volume 名 |
| `NAS_CACHE_ROOT` | 空 | 大文件 NAS 挂载根（见 `docs/cache-mirror.md`） |
| `NAS_READ_ONLY` | `0` | `1` = 不写回 NAS |
| `FORCE` | `0` | 强制覆盖/重建（各目标语义见下文） |
| `FACTORY_SKU` | `ynh960-p800` | 出厂变体主键；查 `board/factory-skus.tsv` 得到下面两个 ID；也是 `factory.img` 子目录名 |
| `UBOOT_ID` | 由表推出（默认 `rockchip-ynh960`） | bootloader 包：`prebuilt/bootloader/<id>/`；日常勿设，用 `FACTORY_SKU`；模拟器不用 |
| `OEM_ID` | 由表推出（默认 `ynh960_panel-800x1280`） | OEM 包：`oem/packs/<id>/` → `oem/out/<id>/oem.img`；日常勿设；模拟器用 `sim_virt` |
| `BOARD` / `CHIP` / `DEFCONFIG` | `ynh960` / `rk3566_rk3568` / `ynh960_defconfig` | lunch 用（一般勿改） |

`FACTORY_SKU` → `UBOOT_ID` + `OEM_ID`（已设的 ID 覆盖表值）。`APP` 选软件/rootfs；SKU 族选 U-Boot+OEM；kernel FIT 各 SKU 共用。

---

## 设备选择（SSH / USB-SSH / 烧录）

多数板端目标共用（`scripts/device-target.sh`）：

| 变量 | 说明 |
|------|------|
| `SN` | 按 `make devices` 的 SN 列匹配（多板时必填） |
| `IP` | 已 `make connect` 的 LAN SSH，或模拟器 `127.0.0.1:2222` |
| `IFACE` | 按主机 USB 网卡名选 USB-SSH |
| `SERIAL` | 已弃用，等同 `SN` |
| `IMAGE` | `make flash` 镜像路径覆盖 |
| `SN=SIM-EMU` / `SN=EMU` | QEMU 模拟器稳定别名 |

**选择优先级：** `IP` → `IFACE` → `SN` → 唯一已连接设备。

USB-SSH 凭据（一般不用改）：`USB_SSH_USER=root`、`USB_SSH_PASS=rockchip`、`USB_SSH_ADDR=192.168.55.1`。

先看板子：`make devices`。

---

## Setup

### `make setup`

- **怎么用：** `make setup`
- **何时用：** 新机器首次；或需要确认 host 工具 + overlay 已就位。
- **做什么：** `apply-overlay`，再跑 `scripts/setup-host.sh`（macOS 会确保 Docker 镜像）。
- **参数：** 无专用；继承 Docker / SDK 相关公共变量。

### `make apply-overlay`

- **怎么用：** `make apply-overlay`；改 DTS/kernel 后常用 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`
- **何时用：** 改了 `overlay/**`、`board/**`（非纯 app 热更）后、多数 `build-*` 之前。
- **做什么：** 把 board/buildroot/kernel overlay 打进 `linux-sdk/`（macOS volume 模式下在容器内执行）。
- **参数：**

| 变量 / 标志 | 说明 |
|-------------|------|
| `FORCE_PLATFORM_OVERLAY=1` | 在已 owned 的 SDK 树上强制重打 kernel/device 补丁 |
| `BUILD_BIND_MOUNT=1` | macOS：在宿主机跑 overlay（非 volume） |
| `--restore`（经 `clean-overlay`） | 还原被 patch 的 SDK 文件 |

### `make clean-overlay`

- **怎么用：** `make clean-overlay`
- **何时用：** 排查 overlay 污染、准备重新 apply。
- **做什么：** `apply-overlay.sh --restore`。

---

## Docker（仅 macOS）

### `make docker-image`

- **怎么用：** `make docker-image`
- **何时用：** 首次 macOS 构建，或改了 `docker/Dockerfile`。
- **参数：** `DOCKER_IMAGE`、`DOCKER_PLATFORM`。

### `make docker-volume-init`

- **怎么用：** `make docker-volume-init`
- **何时用：** 首次；或 `trim-linux-sdk` 后需丢掉 volume 里旧 vendor 树时重新 init。
- **做什么：** 宿主机 `linux-sdk/` → Docker volume（一次性拷贝）。

### `make docker-volume-sync`

- **怎么用：** `make docker-volume-sync`
- **何时用：** 宿主机 SDK/overlay 有变更、构建前想刷新 volume。
- **参数：** `DOCKER_VOLUME`。

### `make docker-export-artifacts`

- **怎么用：** `SCOPE=boot\|rootfs\|update\|firmware make docker-export-artifacts`
- **何时用：** 日常一般**不必**（`build-kernel` / `build-rootfs` / `build-img` 已自动导出）；手工补导出时用。
- **参数：** `SCOPE`（默认 `firmware`）、`APP`（rootfs 路径）。

### `make docker-volume-pull`

- **怎么用：** `make docker-volume-pull`
- **何时用：** 旧别名；等同 `SCOPE=firmware` 导出（不镜像 `linux-sdk/output/`）。

### `make docker-volume-status`

- **怎么用：** `make docker-volume-status`
- **何时用：** 排查 volume / SDK 树是否就绪。

### `make sdk-shell`

- **怎么用：** `make sdk-shell`
- **何时用：** 需要进 SDK 树交互调试（Linux 本机或 macOS 容器）。

---

## Build（固件主路径）

### `make build`

- **怎么用：** `make build`
- **何时用：** 全量出厂镜像（新机、发版、干净树）。
- **流水线：** `check-prebuilt` → `apply-overlay` → `lunch` → `build-boot-logo` → `build-ai` → `build-app` → `build-kernel` → `build-rootfs` → `build-oem` → `build-img`。
- **参数：** `APP`、`FACTORY_SKU`、公共构建变量。
- **产物：** `output/firmware/<APP>/<sku>/factory.img`，`update.img` 为 symlink。

### `make lunch`

- **怎么用：** `make lunch`
- **何时用：** 首次选板型/Buildroot 配置，或 `.config` 丢失后。
- **做什么：** `./build.sh $(CHIP):$(DEFCONFIG)` + 同步 lunch 配置。
- **参数：** `CHIP`、`DEFCONFIG`（默认 ynh960）。

### `make show-config`

- **怎么用：** `make show-config`
- **何时用：** 确认 `RK_*` 芯片/DTS/rootfs/defconfig 行。
- **前提：** 已 `lunch`。

### `make build-boot-logo`

- **怎么用：** `make build-boot-logo`
- **何时用：** 改了 `board/logo/`。
- **做什么：** 生成 kernel FIT splash `logo.bmp`，并刷新 overlay Weston `boot-splash.png`（横屏直立，对齐 `rotate-270`）。
- **后续：** 通常 `make build-kernel`（+ 若 splash 进 rootfs 则 `build-rootfs`）再 `upgrade`。

### `make build-ai` / `make rebuild-ai`

- **怎么用：** 日常 `make build-ai`；强制清 cmake 全量：`make rebuild-ai` 或 `FORCE=1 make build-ai`
- **何时用：** 改了 `native/lws_ai/`；产物进 `prebuilt/ai/`，再 `make build-app`（打包进 `/opt/hmi`）。`make build` 全量流水线也会跑此阶段。
- **参数：** `AI_VERSION`；增量保留 `.cache/lws_ai/` cmake。
- **依赖：** 已有 `build-opencv` + `fetch-rknn-rt`（或缺则先补齐）。

### `make prepare-app-assets`

- **怎么用：** `make prepare-app-assets`
- **何时用：** 只想生成 ship assets、不跑 Flutter AOT（本地 IDE / `flutter test`）；**`make build-app` 已自动调用**，日常不必单独跑。
- **做什么：** 把源树里的工艺库 Excel、控制板/相机固件筛成一份可随包发布的树 → `app/<APP>/assets/.generated/`（由 `scripts/prepare-hmi-ship-assets.sh`）。

### `make build-app`

- **怎么用：** `make build-app` 或 `APP=factory_test make build-app`
- **何时用：** 改了 Flutter App / `cyber_*` 包 / 随 App 打包的 `bin/` 后；日常热更首选（再 `push-app`）。
- **做什么：** 先按需跑 `prepare-hmi-ship-assets`（同 `prepare-app-assets`），再 release AOT → overlay（`*_hmi`→`/opt/hmi`），并 `apply-overlay`。
- **参数：**

| 变量 | 说明 |
|------|------|
| `APP` | 产品目录 |
| `FLUTTER_SDK` | 主机 SDK |
| `REQUIRE_AI=1` | AI 预编译缺失则失败（发版门禁） |

**注意：** 不重建 rootfs；板端已有可推送 HMI 时用 `push-app`（Debug）或 `upgrade-app`（签名），无需 `build-rootfs`。

### `make build-debug-app`

- **怎么用：** `make build-debug-app`
- **何时用：** 很少单独跑；`debug-app` / IDE 会用到 debug bundle 缓存。
- **产物：** `.cache` 下 debug 包。

### `make version` / `make version-bump`

- **怎么用：**
  - `make version` → 打印 **OS Version**（`/etc/os-release` 的 `VERSION=`，Cyber OS）
  - `APP=lws_hmi make version` → 打印 Flutter pubspec `name+build`
  - `make version-bump VERSION=1.0.1` →  bump OS（同步 `VERSION=` / `VERSION_ID=` / `PRETTY_NAME=`）
  - `APP=lws_hmi make version-bump VERSION=1.0.42` → bump Flutter（同步 `kHmiVersion`）
- **何时用：** 查/改 OS 或 HMI 版本。默认无 `APP=` 时操作 OS；显式 `APP=` 时操作 Flutter。
- **参数：** `VERSION`（bump 必填）、`APP`（可选，选 Flutter）。
- **后续上板：** OS 需 `apply-overlay` + `build-rootfs` + `upgrade`；HMI 用 `build-app` + `upgrade-app`。

### `make l10n` / `l10n-sync` / `l10n-gen` / `l10n-verify`

- **怎么用：** 改父 ARB（`app_en.arb` / `app_zh.arb`）后 `make l10n`；CI/自检 `make l10n-verify`。
- **何时用：** 文案/多语言；`l10n-sync` 只重生子 ARB；`l10n-gen` 只 `flutter gen-l10n`。
- **后续上板：** `build-app` + `upgrade-app`。

### `make check-typography`

- **怎么用：** `make check-typography`
- **何时用：** 禁止裸 `fontSize: N` / 业务误用 `AppTypography.*Size`；本地或 CI。
- **参数：** 无（不产固件）。

### `make build-kernel`

- **怎么用：** `make build-kernel`
- **何时用：** 改 kernel、DTS（`overlay/kernel/`）、boot logo、FIT 多 conf。
- **产物：** `output/firmware/boot.img`（rootfs_a）、`boot_b.img`（rootfs_b）、裸 `Image`（模拟器用）。
- **参数：** 经 Docker/`BUILD_JOBS`；DTS 变更先 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`。
- **后续：** 板端 `make upgrade`（不必 `build-img`）。

### `make prepare-rootfs`

- **怎么用：** `make prepare-rootfs`；强制重刷栈 `FORCE=1 make prepare-rootfs`
- **何时用：** 只想确保 Weston/Mali/embedder 栈，不打包 `rootfs.img`。
- **注意：** `build-rootfs` 会先调用它（stamp 命中则跳过）。

### `make build-rootfs`

- **怎么用：** `make build-rootfs` 或 `APP=cnc_hmi make build-rootfs`
- **何时用：** overlay/systemd/LCD、Bake App 进镜像、Buildroot 用户态变更后。
- **产物：** `output/firmware/<APP>/rootfs.img`。
- **参数：** `APP`；若存在 `app/factory_test` 会自动确保 `/opt/factory_test`。
- **重要：** 改 `overlay/buildroot/chips/*.config` 等**已有包的编译选项**时，`build-rootfs` **不会**重编该包；需先 `bash scripts/br-make-packages.sh <label> <pkg>…`。
- **后续：** `make upgrade`。

### `make build-oem`

- **怎么用：** `make build-oem`；模拟器：`OEM_ID=sim_virt make build-oem`
- **何时用：** 改了 `oem/**`、屏参包、board helpers。
- **产物：** `oem/out/<OEM_ID>/oem.img`。
- **参数：** `FACTORY_SKU`（推荐）或直接 `OEM_ID=`；`UBOOT_ID` 无关。
- **后续日常：** `OEM_ONLY=1 make upgrade`（只刷 oem + 普通重启）。

### `make build-img`

- **怎么用：** 先 `make build-oem`，再 `make build-img`
- **何时用：** 出厂/USB 烧录用的 `factory.img`；**不**编译 kernel/rootfs。
- **产物：** `output/firmware/<APP>/<FACTORY_SKU>/factory.img` + `update.img` symlink。
- **参数：** `APP`、`FACTORY_SKU`（由此取 `UBOOT_ID`/`OEM_ID` 打进镜像）。
- **后续：** `make reboot-loader` → `make flash`。

---

---

## Debug / 板端运维

### `make setup-usb-ssh`

- **怎么用：** `make setup-usb-ssh`
- **何时用：** 首次 USB 网卡调试；配置 ECM/RNDIS IP + `sshpass`（Win 需管理员；macOS 可能要 sudo）。

### `make connect` / `make disconnect`

- **怎么用：** `make connect 192.168.1.50`；`make disconnect 192.168.1.50`（也可用 `IP=`）
- **何时用：** 注册/注销 LAN SSH 板（含 `host:port` 模拟器）。

### `make devices`

- **怎么用：** `make devices`
- **何时用：** 选板前看 RockUSB / USB-SSH / SSH / EMU 表。
- **参数：** 无；输出用于填 `SN=` / `IP=`。

### `make shell`

- **怎么用：** `make shell`；多板 `SN=… make shell`
- **何时用：** 交互 SSH（USB-SSH 或已注册 SSH）。

### `make logs`

- **怎么用：** `make logs`；过滤示例：`UNIT=hmi.service make logs`、`GREP=WARN make logs`
- **参数：**

| 变量 | 说明 |
|------|------|
| `UNIT` | systemd unit（可逗号分隔） |
| `TAG` | syslog identifier |
| `GREP` | journalctl `--grep` |
| `PRIORITY` | `emerg`…`debug` 或 `0`–`7` |
| `KERNEL_ONLY=1` | 仅内核日志 |
| `SN` / `IP` | 选板 |

### `make write-identity`

- **怎么用：** `make write-identity BRAND=Innohi MODEL='L1 Pro' PRODUCT_SN=SN123`；覆盖已有 SN 加 `FORCE=1`
- **何时用：** 产测/出厂写入 brand/model/产品 SN（Vendor Storage）。
- **注意：** 选板用 `SN=`/`IP=`；载荷用 `PRODUCT_SN=`（可含 `-`，写入前自动去掉；其余须为 `[A-Za-z0-9]`，因 Rockchip U-Boot 会截断进 DT）。

### `make reset-process-library`

- **怎么用：** `make reset-process-library`
- **何时用：** **Debug**——清板端工艺库 DB 后强制重导捆绑包（不重启 HMI）。
- **前提：** HMI watcher 在跑。

### `make migrate-secrets`

- **怎么用：** `make migrate-secrets`；仅 Wi‑Fi：`SCOPE=wifi make migrate-secrets`；仅云密钥：`SCOPE=cloud make migrate-secrets`
- **何时用：** 设备曾用 software KEK 封存 Wi‑Fi vault / Vendor Storage 云 Ed25519，OEM 已切到 `secrets_backend: optee` 后一次性重封到 OP-TEE。
- **行为：** SSH 写 `/run/hmi/migrate-secrets.cmd`；HMI 用 software 解封再 OP-TEE 重封；已是 `LWS1` 的条目跳过。
- **前提：** HMI 含 `MigrateSecretsCommandWatcher`；`secrets-seal probe` 通过；云路径需要产品 SN。

### `make migrate-seal-kek`

- **怎么用：** `make migrate-seal-kek`
- **何时用：** OP-TEE 已在用时，把 seal KEK 以 HUK wrap 写入 Vendor Storage ID **23**（或从 ID 23 恢复到 REE `/userdata/tee`），使刷机清 userdata 后仍能解 VS 云密钥。
- **行为：** SSH 在板上跑 `secrets-seal sync-kek` / CA `kek-export-wrap`↔`kek-import-wrap`；**不**改云 Ed25519 种子。
- **前提：** vendor 签名 seal TA/CA；`read/write-seal-kek-wrapped` helpers；`/dev/vendor_storage`。

### `make set-prop` / `make del-prop`

- **怎么用：** `make set-prop CAMERA_IP=192.168.1.10`；`make del-prop CAMERA_IP`
- **何时用：** 改 `/var/lib/hal/properties.ini` 可调项（**不能**改 brand/model/sn → 用 `write-identity`）。
- **行为：** 成功后重启 `hmi`。

### `make alarm` / `make alarm-clean`

- **怎么用：** `make alarm CODE=L001`；清理限制：`make alarm-clean`
- **何时用：** 演示告警弹窗（HMI 须在跑）。

### `make smoke-ai`

- **怎么用：** `make smoke-ai`；自定义图 `SMOKE_AI_IMAGE=foo.jpg make smoke-ai`
- **何时用：** 上传 stain demo，经 AI daemon sock 做离线 RKNN 冒烟。
- **前提：** 板端 AI daemon（通常随 HMI）。

### `make prepare-debug-host`

- **怎么用：** `make prepare-debug-host`
- **何时用：** `debug-app` / IDE 前确认 USB-SSH 或已注册 SSH 可达。

### `make debug-setup` / `make debug-app`

- **怎么用：** 一次性 `make debug-setup`；日常 `make debug-app`（多板 `SN=…`）
- **何时用：** Flutter Custom Device + `flutter run -d lws-hmi`。
- **参数：** `FLUTTER_SDK`、设备选择。

### `make push-app`

- **怎么用：** `make build-app` 后 `make push-app`（多板 `SN=` / `IP=`）
- **何时用：** **Debug** 热更——无签名，SSH 流式推 overlay APP 到板端 `/opt/hmi`（或 `/opt/<APP>`）并重启 `hmi.service`（仅 `*_hmi`）。**不是** `upgrade-app` 的别名。
- **行为：** 上传到 `/var/lib/hmi/push-app-staging/` → 刷新并执行 `/usr/libexec/hmi/push-app-apply-and-restart.sh`（host overlay 每次推送刷新）→ 安装 + 重启。
- **参数：** `APP`、设备选择。
- **签名发布：** 用 `make upgrade-app` / `make publish-app`。

### `make serial-console` / `make serial-ports` / `make serial-sniff`

- **怎么用：**
  - `make serial-console`（默认 TTL）
  - `MODE=RS485 make serial-console` / `MODE=RS232 …`
  - `make serial-ports` 列端口
  - `make serial-sniff` 上电循环探测波特率
- **何时用：** 主机串口调试（TTL 调试口 / RS485 / RS232）。
- **参数：**

| 变量 | 默认 | 说明 |
|------|------|------|
| `MODE` | `TTL` | `TTL`=miniterm；`RS485`/`RS232`=hex+TX |
| `PORT` | 自动 | 如 `/dev/cu.wchusbserial…` |
| `BAUD` | TTL `1500000`；其它 `115200` | |
| `LOG_FILE` | 空 | hex 模式会话日志文件 |
| `SNIFF_SEC` | `8` | sniff 每档波特率监听秒数 |

退出：TTL `Ctrl+]`；RS485/RS232 `Esc` 或 `:q`。

---

---

## Dependencies（预编译 / 拉取）

首次 `build-rootfs` 前跑 `make build-deps` + `make check-prebuilt`。强制刷新：对应 `rebuild-*` 或 `FORCE=1 make build-*`。

### SDK 导入

| 目标 | 用法 | 何时 | 参数 |
|------|------|------|------|
| `extract-linux-sdk` | `SRC=/path make extract-linux-sdk` 或位置参数 | 从 Innohi xz 分卷得到 `linux-sdk/` | `SRC`、`DEST`、`FORCE=1` 替换、`TRIM=1` 提取后 trim |
| `trim-linux-sdk` | `make trim-linux-sdk` | 白名单裁剪 + platform squash | `DEST`、`CLEAN_OUTPUT=1` |
| `check-linux-sdk` | `make check-linux-sdk` | 校验禁止目录/大文件 | — |
| `squash-linux-sdk-platform` | `make squash-linux-sdk-platform` | 重打 overlay/kernel 进 owned 树 | 同 `FORCE_PLATFORM_OVERLAY` 场景 |

### 聚合

| 目标 | 说明 |
|------|------|
| `check-prebuilt` | 按已启用 defconfig fragment 检查 `prebuilt/` |
| `build-deps` | `build-dev-deps` + `build-runtime-deps` |
| `rebuild-deps` | `FORCE=1` 全量依赖 |
| `build-dev-deps` | 主机 Flutter SDK + RKNN-Toolkit |
| `rebuild-dev-deps` | 强制重做 dev 依赖 |
| `build-runtime-deps` | flutter engine（release+debug）、gstreamer、mediamtx、opencv、ai、btop、rknn-rt 等 |
| `rebuild-runtime-deps` | 强制 runtime |

### 单项 build / fetch

| 目标 | 何时用 | 主要参数 / 产物 |
|------|--------|-----------------|
| `build-flutter-engine` | 改 engine pin / 缺 prebuilt | `FLUTTER_ENGINE_RUNTIME_MODE=debug\|release`、`FLUTTER_ENGINE_VERSION`、`FORCE` → `prebuilt/flutter-engine/…` |
| `rebuild-flutter-engine` | 强制重编 engine | 同上，`FORCE=1` |
| `fetch-flutter-engine` / `refetch-flutter-engine` | 拉 engine 源码到 `.cache/` | `FORCE` |
| `cache-publish-flutter-engine` | 发布 engine 到团队缓存 | 见 cache-mirror |
| `build-flutter-embedded-linux` | Weston 镜像必做 | eLinux Wayland client → prebuilt；`rebuild-*` + `FORCE=1` |
| `build-gstreamer` | MPP/GStreamer pin 变更 | `FORCE`；改后常需 `rebuild-flutter-embedded-linux` |
| `build-platform-packages` | libmodbus/yaml-cpp/sqlite/avahi | `FORCE` |
| `build-mediamtx` | MediaMTX 二进制 | → prebuilt；随 `build-app` 进 `/opt/hmi` |
| `build-opencv` / `fetch-opencv` / `fetch-opencv-ximgproc` | AI 依赖 | OpenCV 源码/产物 |
| `build-umtprd` | USB MTP | → prebuilt + overlay |
| `build-extract-video-frame` | MP4→JPEG helper | → prebuilt + libexec |
| `build-secrets-seal` | OP-TEE seal TA + CA | → prebuilt + overlay |
| `fetch-btop` | btop 二进制 | → prebuilt + overlay |
| `fetch-rknn-rt` | `librknnrt` | → `prebuilt/rknn-rt/` |
| `fetch-flutter-sdk` / `refetch-flutter-sdk` | 主机 Flutter | `DEST`（默认 `flutter-sdk/`）、`FORCE` |
| `fetch-rknn-toolkit` | 主机 ONNX→RKNN | `FORCE` |
| `export-prebuilt` | 重导出 flutter+runtime | 通常 build 已导出；`rebuild-prebuilt`=`FORCE=1` |
| `build-prebuilt` | 仅 flutter 导出 | `EXPORT_RUNTIME=0` |
| `export-prebuilt-runtime` | 仅 runtime 导出 | `EXPORT_FLUTTER=0` |

---

---

## Cloud + Upgrade（api-server / R2 发布 / A/B + App/外设升级）

### `make login`

- **怎么用：** `make login`；或 `CLOUD_ACCOUNT=… CLOUD_PASSWORD=… make login`
- **做什么：** 登录 api-server，把 token 写到 `output/cloud/credentials.json`（供 `register-device` / `publish`）。
- **参数：** `CLOUD_API_BASE`、`CLOUD_ACCOUNT`、`CLOUD_PASSWORD`

### `make register-device`

- **怎么用：** `make login` 后 `make register-device`（多板 `SN=`/`IP=`）
- **做什么：** SSH 读板端 identity，向云端注册该设备（勿传 `PRODUCT_SN=`/`MODEL=`）。
- **前提：** 板端已 `write-identity`；已 login 或 `CLOUD_ACCESS_TOKEN=`。

### `make sign-keys`

- **怎么用：** `make sign-keys`；强制重生成 `FORCE=1 make sign-keys`（会使旧 `.sig` 失效）
- **做什么：** 生成 release Ed25519 钥对 → 私钥 `keys/ota/`（勿提交），公钥进 overlay `/etc/ota/ed25519.pub`。
- **参数：** `FORCE`、`OTA_KEY_DIR`

### `make pack-ota`

- **怎么用：** `make pack-ota`；仅 OEM：`OEM_ONLY=1 make pack-ota`；强制签名：`REQUIRE_OTA_SIG=1 make pack-ota`
- **做什么（不编译）：**
  1. 从已有产物拷贝分区镜像到临时目录：`boot.img` + `boot_b.img`（`output/firmware/`）+ `rootfs.img`（`output/firmware/<APP>/`）+ 可选 `oem.img`（`OEM_ONLY=1` 时只要 oem）
  2. 写 `manifest.json`（各文件 sha256 / size）
  3. 打成 `output/firmware/<APP>/ota-package.tar.gz`（平铺成员，供板端 BusyBox tar）
  4. 若有签名钥（`OTA_SIGNING_KEY` 或默认 `keys/ota/ed25519.pem`）→ 旁路写 `ota-package.tar.gz.sig`；`REQUIRE_OTA_SIG=1` 时无钥则失败
- **前提：** 先有对应镜像（`make build-kernel` / `build-rootfs` / 可选 `build-oem`）；签名需 `make sign-keys`。
- **谁会用：** `make upgrade`（SSH）与 `make publish` 都依赖这份归档（+ `.sig`）。
- **参数：** `APP`、`OEM_ONLY`、`OEM_IMG`、`OTA_SIGNING_KEY`、`REQUIRE_OTA_SIG`

### `make pack-app`

- **怎么用：** `make pack-app`（通常先 `make build-app`）
- **做什么（不编译）：** 把 overlay APP 安装树打成 `output/app/<APP>/v{semver}.tar.gz`。
- **谁会用：** `make upgrade-app` / `make publish-app` 默认会先跑它；也可单独打包后用 `APP_PACKAGE=` 喂给升级/发布。
- **参数：** `APP`、`APP_PACKAGE=`（覆盖输出路径）

### `make upgrade`

- **怎么用：**
  - 全量 A/B（SSH）：`make upgrade`（先 `pack-ota`，host 临时 HTTP 托管 `tar.gz`+`.sig`，设备下载后验签写盘；需签名钥）
  - 现成包（SSH）：`UPGRADE_PACKAGE=/path/to/ota-package.tar.gz make upgrade`（同目录须有 `<path>.sig`；跳过重新打包）
  - 现成包（Loader）：`make reboot-loader` 后 `UPGRADE_TRANSPORT=rockusb UPGRADE_PACKAGE=/path/to/ota-package.tar.gz make upgrade`（host 解压成员后 `di`；**不**需要 `.sig`）
  - 全量（RockUSB Loader/Maskrom，树内镜像）：`make reboot-loader` 后 `make upgrade`，或 `UPGRADE_TRANSPORT=rockusb make upgrade`（`di` 写 boot + boot_b + 双 rootfs + 可选 oem；**不** `uf factory.img`）
  - 仅 OEM：`OEM_ONLY=1 make upgrade`（oem-only 归档也须显式 `OEM_ONLY=1`，不会从成员自动推断）
  - 跳过 oem：`OEM_IMG= make upgrade`
  - 强制传输：`UPGRADE_TRANSPORT=ssh|rockusb`（默认 `auto`）
  - HTTP 绑定：`OTA_HTTP_HOST=` / `OTA_HTTP_PORT=`（USB-SSH 默认 `192.168.55.2`）
- **何时用：** 板已具备 P2.4 GPT/helpers 后的日常 kernel/rootfs/oem 迭代（**不**传 `factory.img`）；板卡停在 Loader/Maskrom 时同一入口刷 OTA 等价松散镜像；或用同事/CI 已打好的 `ota-package.tar.gz`。
- **参数：** `APP`、`OEM_ONLY`、`OEM_IMG`、`FACTORY_SKU`/`OEM_ID`、`UPGRADE_TRANSPORT`、`UPGRADE_PACKAGE`（`.tar` / `.tar.gz` / `.tgz`）、`OTA_HTTP_HOST`、`OTA_HTTP_PORT`、设备选择、`WAIT_SEC`。
- **行为：** SSH 路径触发升级页 → 设备从 host HTTP 下载归档 → staged verify/apply → 请求重启后立即返回；RockUSB 路径 `di` 完成后 `rd`（`UPGRADE_PACKAGE` 时先解压）。与云 OTA 同源落盘与验签。与 `make flash`（factory `uf`）不同。若 macOS 防火墙拦截入站，允许 Python 接收连接。
- **归档成员：** 与 `make pack-ota` 一致：`boot.img` + `boot_b.img` + `rootfs.img`（可选 `oem.img`）；`OEM_ONLY=1` 时只要 `oem.img`。

### `make upgrade-app`

- **怎么用：** `make build-app` 后 `make upgrade-app`
- **何时用：** 签名后经主机临时 HTTP 下发 App（不刷 rootfs）；设备拉取 + Ed25519 验签后安装 `/opt/hmi` 并重启 `hmi.service`。
- **行为：** `pack-app` → `ota-sign.sh` → HTTP 提供 `v*.tar.gz`+`.sig` → SSH 写 `/run/hmi/upgrade-app.cmd` 为 `download <url>`。
- **参数：** `APP`、`APP_PACKAGE=`（可选已打包路径）、`OTA_SIGNING_KEY`、设备选择。
- **前提：** `OTA_SIGNING_KEY`；板端 HMI 含 `UpgradeAppCommandWatcher`。
- **Debug 热更：** 用 `make push-app`（无签名 SSH 推送；见 Debug 节）。

### `make upgrade-control-board`

- **怎么用：** `make upgrade-control-board`；指定包 `FIRMWARE_BIN=/path/to.bin make upgrade-control-board`
- **何时用：** 签名并经主机临时 HTTP 下发最新控制板固件，设备拉取 + Ed25519 验签后强制 Modbus 升级（无版本门禁 / 无 Home 确认）。
- **行为：** `ota-sign.sh` → `ota-http-serve.py` 提供 `.bin`+`.sig` → SSH 写 `/run/hmi/upgrade-control-board.cmd` 为 `download <url>`（不再 SSH 上传固件本体）。
- **前提：** `OTA_SIGNING_KEY`（或 `keys/ota/ed25519.pem`）；板端 HMI 含 watcher 且能访问主机 HTTP（`OTA_HTTP_HOST` / `OTA_HTTP_PORT` 可选）。

### `make upgrade-camera`

- **怎么用：** `make upgrade-camera`；指定包 `FIRMWARE_ZIP=/path/to.zip make upgrade-camera`
- **何时用：** 签名并经主机临时 HTTP 下发最新摄像头固件 ZIP，设备拉取 + 验签后强制 CGI 升级（无版本门禁；成功需相机重启并重新上线）。
- **行为：** 同控制板：HTTP + `download <url>` 写 `/run/hmi/upgrade-camera.cmd`。
- **前提：** `OTA_SIGNING_KEY`；板端 HMI 含 watcher；源包在 `app/lws_hmi/assets/firmware/camera/`。

### `make upgrade-process-library`

- **怎么用：** `make upgrade-process-library`；指定包目录 `PACKAGE_DIR=…`
- **何时用：** 按设备 Vendor Storage `model` 推工艺库并强制导入。
- **前提：** HMI watcher 在跑。
- **Debug 清库重导：** 用 `make reset-process-library`（见 Debug 节）。

### `make publish` / `make publish-only`

- **怎么用：**
  - 打包并发布：`make publish`（内部 `REQUIRE_OTA_SIG=1 make pack-ota` 再上传）
  - 仅上传已有包：`make publish-only`
  - 其它 HMI：`APP=cnc_hmi make publish`（R2 前缀 `cnc-hmi/`；需 `app/cnc_hmi`）
  - 测试 API：`CLOUD_API_BASE=https://api-test.lasercyber.workers.dev make publish`
- **何时用：** 把与 `make upgrade` **同一** 的签名 `ota-package.tar.gz` + `.sig` 发到应用 R2，并更新 **`release.json`**，供设备云端拉取 **整机 / OS** 通道。
- **上传路径：** 与 `lws-ui` / `make login` 同源——默认 **`CLOUD_API_BASE=https://api-prod.lasercyber.workers.dev`**，`GET /v1/storage/r2/presigned-url` 取凭证后 Python **直传 R2**（不走 `PUT /upload/…`）。
- **渠道：** **仅 release**（始终写 `release.json`；无 `staging.json`、无 `RELEASE=`、无 `-beta`/`-alpha`）。版本取自 **OS Version** SoT（`/etc/os-release` `VERSION=`），**不是** Flutter pubspec。
- **设备比较：** Settings System Upgrade 用运行中 **OS Version** 与 channel `version` 做 semver 比较；设备始终拉取 **`https://cdn.lasercyber.com/{artifact}/release.json`**（R2 CDN 直连，与云服务 / API pin 无关）。HMI app 通道见 `make publish-app`。
- **Manifest 字段：** `version`、`filename`、`published_at`、`url`（**无 `sha512`**；完整性靠旁路 `.sig`，设备侧 `url`/`package_url` + `".sig"`）。
- **鉴权：** `PUBLISH_API_TOKEN`（优先）→ `CLOUD_ACCESS_TOKEN` → `make login` 的 `output/cloud/credentials.json`。
- **产出对象（默认 APP）：** `lws-hmi/v{OS}.tar.gz`、同名 `.sig`、`lws-hmi/release.json`。
- **参数：** `APP`、`CLOUD_API_BASE`、`PUBLISH_API_TOKEN`、`CLOUD_ACCESS_TOKEN`、`PUBLISH_ARTIFACT`（覆盖 R2 前缀；非 `*_hmi` 须设此项）、`OTA_SIGNING_KEY`（`make publish` 打包时）
- **前提：** `make sign-keys` / `OTA_SIGNING_KEY`；`make login` 或静态 token。
- **注意：** 勿再设 `RELEASE=`（已移除；设置会报错退出）。App-only 发布用 `make publish-app`。

### `make publish-app` / `make publish-app-only`

- **怎么用：** `make publish-app`；仅上传已有包：`make publish-app-only`（需 `APP_PACKAGE=` 或默认 `output/app/<APP>/v*.tar.gz` + `.sig`）
- **何时用：** 把 HMI app `tar.gz` + `.sig` + **`release.json`** 发到 R2 **`lws-hmi/app/`**，供设备 HMI Upgrade 云端检查。
- **渠道版本：** Flutter pubspec SemVer，manifest `version` = `v{semver}`。
- **鉴权 / API 基址：** 与 `make publish` 相同。

### `make publish-control-board-firmware` / `make publish-camera-firmware`

- **怎么用：**
  - 控制板：`make publish-control-board-firmware`（默认选最新 `LSW01H*.bin`；`FIRMWARE_BIN=` 覆盖）
  - 摄像头：`make publish-camera-firmware`（默认选最新 ZIP；`FIRMWARE_ZIP=` 覆盖）
  - 仅上传已签名对：`make publish-control-board-firmware-only` / `make publish-camera-firmware-only`
- **何时用：** 把最新控制板 / 摄像头固件 + `.sig` + **`release.json`** 发到 R2，供设备云端检查（与系统 OTA 相同的 presign PUT；系统与外设均为 release-only）。
- **渠道：** **仅 release**（始终写 `release.json`，无 staging / `-beta`；与 `make publish` 一致）。
- **R2 前缀（默认 APP）：** `lws-hmi/control-board/`、`lws-hmi/camera/`（对象：固件文件、同名 `.sig`、`release.json`）。
- **鉴权 / API 基址：** 与 `make publish` 相同。
- **注意：** sibling api-server 可能需放行上述 R2 key 前缀。
- **参数：** `APP`、`FIRMWARE_BIN` / `FIRMWARE_ZIP`、`OTA_SIGNING_KEY`、`CLOUD_API_BASE`、`PUBLISH_API_TOKEN`、`PUBLISH_ARTIFACT`

---

---

## USB Flash

### `make reboot` / `make reboot-loader` / `make loader`

- **怎么用：** `SN=… make reboot`；进烧录：`make reboot-loader`；Maskrom 下发 loader：`make loader`
- **何时用：** 软重启；或进 RockUSB 准备 `flash`。
- **参数：** 设备选择、`BOOTLOADER_WAIT_SEC`、`LOADER_NORESET=1` 等（见 `flash-usb.sh`）。

### `make flash`

- **怎么用：** `make flash`；覆盖镜像 `IMAGE=/path/to.img make flash`；指定 SKU `FACTORY_SKU=… APP=… make flash`
- **何时用：** USB 烧 `factory.img`（或 Maskrom `ul` 路径）。
- **默认镜像：** `output/firmware/<APP>/<FACTORY_SKU>/factory.img`（或 `update.img` symlink）。
- **参数：** `IMAGE`/`UPDATE_IMG`、`APP`、`FACTORY_SKU`、`SN`、`UPGRADE_NORESET=1`。

### `make flash-android`

- **怎么用：** `make flash-android`；`ANDROID_IMG=/path make flash-android`
- **何时用：** 可选刷 Android 镜像（默认 `images/android/update.img`）。

### `make watch-maskrom`

- **怎么用：** `make watch-maskrom`
- **何时用：** 等待设备进入 Maskrom。

---

---

## Emulator（P3.2）

详见 [`docs/p32-emulator.md`](p32-emulator.md)。

### `make setup-emulator-qemu`

- **怎么用：** `make setup-emulator-qemu`
- **何时用：** macOS 首次；系统 QEMU 无 OpenGL 时安装 qemu-virgl。

### `make fetch-emulator-swgl`

- **怎么用：** `make fetch-emulator-swgl`；强制 `FORCE=1 make fetch-emulator-swgl`
- **何时用：** 首次拉 guest Mesa virtio_gpu → `prebuilt/`（经 9p，不进 rootfs）。

### `make build-emulator`

- **怎么用：** `make build-emulator`
- **何时用：** 已有 `Image` + `rootfs.img` 后组装模拟器目录。
- **参数：** `APP`（模拟器 rootfs 固定扩到 1536M，设备 OTA 仍为 ~600M）。
- **产物：** `output/firmware/emulator/`（含长大后的 rootfs 副本 + `sim_virt` oem）。

### `make emulator` / `make emulator-stop`

- **怎么用：** `make emulator`；停：`make emulator-stop`
- **何时用：** 无板调试；停后再启避免残留 QEMU。
- **常用参数：**

| 变量 | 默认 | 说明 |
|------|------|------|
| `EMULATOR_ETH0_BRIDGE` | `auto` | `off` = 无网桥（无 IP 相机时） |
| `EMULATOR_MEM` / `EMULATOR_CPU` | `2048` / `4` | 内存 MiB / vCPU 核数 |
| `EMULATOR_CPU_MODEL` | `cortex-a55` | QEMU `-cpu` 型号 |
| `EMULATOR_SSH_PORT` | `2222` | 主机 SSH 转发 |
| `EMULATOR_XRES` / `EMULATOR_YRES` | `1536` / `960` | 显示 |
| `EMULATOR_USB` | `auto` | USB 透传 |
| `QEMU` | 自动 | `qemu-system-aarch64` 路径 |

Guest 起来后可用 `SN=SIM-EMU make push-app` / `debug-app`。

---

---

## Misc

| 目标 | 用法 | 何时 | 参数 |
|------|------|------|------|
| `pull-display-params` | `make pull-display-params` | 从 Android 板拉 LCD/MIPI 表到 `board/` | adb 设备；会 `apply-overlay` |
| `migrate-buildroot-output` | `make migrate-buildroot-output` | 旧 `*_lws_hmi_p1` BR 树迁为 `lws_hmi` | — |
| `fix-buildroot-host-rpaths` | `make fix-buildroot-host-rpaths` | migrate 后修 host rpath | — |
| `clean-buildroot-output` | `make clean-buildroot-output` | 删当前 BR output（保留 `dl/`）后全量重编 rootfs；**macOS** 走 Docker volume（勿只清 host `linux-sdk/`） | 大版本 BR 升级（见 `BUILDROOT_VERSION`）必做；之后 `lunch` + `build-rootfs` |
| `export-buildroot-toolchain` | `make export-buildroot-toolchain` | 打 BR host+staging tar 供团队缓存 | 非运行时 prebuilt |
| `build-uboot` | **ynh960 勿用**（无 Innohi 指示） | 有砖机风险 | — |
| `fetch-uboot` | 内部/少用 | 拉 uboot | — |
| `build-reboot-rockusb-loader` | 内部工具构建 | — | `LWS_HMI_SKIP_OVERLAY=1` |
| `test-debug-app` | `make test-debug-app` | debug-app 脚本自测 | — |

---

## 常用场景速查

| 场景 | 命令（自上而下） |
|------|------------------|
| App 日更（Debug） | `make build-app` → `make push-app` |
| App 签名升级 | `make build-app` → `make upgrade-app` |
| Overlay / systemd | `make apply-overlay` → `make build-rootfs` → `make upgrade` |
| Kernel / DTS | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → `make build-kernel` → `make upgrade` |
| SELinux（permissive；见 [`docs/selinux.md`](selinux.md)） | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → `bash scripts/br-make-packages.sh selinux libselinux libsepol refpolicy policycoreutils libsemanage systemd` → `make build-kernel` → `make build-rootfs` → `make upgrade`（**勿** `build-uboot`） |
| 仅 OEM | `make build-oem` → `OEM_ONLY=1 make upgrade` |
| 出厂 USB | `make build-oem` → `make build-img` → `make reboot-loader` → `make flash` |
| 全量 | `make build` |
| 模拟器 | `make build-kernel` → `make build-rootfs` → `make build-emulator` → `make emulator` |
| BR 包选项变更 | `make apply-overlay` → `bash scripts/br-make-packages.sh …` → `make build-rootfs` → `make upgrade` |

---

## 相关文档

- [`README.md`](../README.md) — Quick start + 按改动类型的命令链
- [`AGENTS.md`](../AGENTS.md) — Agent 重建表（改完代码后该跑哪些 make）
- [`docs/build-optimization.md`](build-optimization.md)
- [`docs/p32-emulator.md`](p32-emulator.md)
- [`docs/selinux.md`](selinux.md) — SELinux permissive enablement（不改 U-Boot）
- [`docs/linux-sdk-vendor-import.md`](linux-sdk-vendor-import.md)
- [`docs/cache-mirror.md`](cache-mirror.md)
- [`.env.example`](../.env.example)
