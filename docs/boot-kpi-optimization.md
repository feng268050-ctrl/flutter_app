# Boot KPI 优化追踪（ynh960 / Plan A）

**KPI 终点**：上电 → Flutter **首页首帧** ≤ **10 s**（eMMC）。  
**单独验收**：Boot splash 上电 **<1～2 s** 出 logo（§5.2 `docs/flutter-pi-hmi-plan.md`），不计入 KPI 终点。

**前提**：单一镜像（§3.6.0）、方案 A systemd、`hmi.service` 仅 `After=local-fs.target`；网络/eth0 首屏后异步（§7.0）。

---

## 1. 架构约束（改优化时勿违背）

| 主题 | 约定 |
|------|------|
| **镜像** | 开发与量产 **同一份** `update.img`；无 `LWS_HMI_DEV`、无 sysinit 早期配网 |
| **systemd** | **保留 systemd 作 PID 1**；flutter-pi 只链接 **`libsystemd.so`**（`sd_event`），与 init 解耦（§3.6） |
| **工程调试** | 串口 `ttyFIQ0` + `make serial-console`；远程 SSH 仅 §7.7 按需 |
| **禁止** | `debug-boot`、内核 `ip=` bootargs、默认 enable `sshd`/`mediamtx`/`bluetoothd` |
| **`multi-user.target`** | 仅表示「应用可启」，非多用户登录；HMI 可 root 运行 |

---

## 2. 构建与刷机（macOS Docker）

**原则**：host 输入 → Docker volume 构建 → **构建结束自动 export 产物到 host**（不用刷机时再 pull）。

```bash
make apply-overlay
make build-rootfs          # 结束：verify-rootfs-overlay: PASS
make build-img             # 结束：docker-export + output/firmware/update.img
make flash                 # 使用 host 上 output/firmware/update.img
```

| 命令 | 产物在 host？ | 说明 |
|------|----------------|------|
| `make build-rootfs` | 否（仅在 volume staging） | 改 rootfs 后必须 `build-img` |
| `make build-img` | **是** | 自动 `docker-export-artifacts` |
| `make build-kernel` | **是**（firmware 片段） | 自动 export；改 kernel 后通常还要 `build-img` |
| `make build` | **是** | 全流水线含 `build-img` |
| `make docker-volume-pull` | 是 | 仅 legacy：导出完整 `linux-sdk/output/` |

Linux 原生构建：无 Docker volume，跳过 export；`output/firmware/` 直接在 host SDK 下。

---

## 3. 板端验收（每轮刷机后）

```bash
verify-boot
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain hmi.service
verify-env                         # §3.4 平台栈（RKNPU2 / wifibt / prep 组件）
```

**`verify-boot` 期望**：`hmi` + `mainserver` + `lws-hmi-performance` + `lws-hmi-pwrkey-poweroff` enabled；`sshd`/`sshd.socket`/`mediamtx`/`bluetooth`/`wifibt-init`/`wpa_supplicant`/`network`/`log-guardian` 未链接；22 未监听；`network-generator` masked；pwrkey input 存在且服务 active；`flutter-pi` running；CPU/devfreq governor 为 `performance`（WARN 若否）。

**秒表**（填 §6 表格）：上电 → logo；上电 → multi-user；上电 → 首页首帧。

**首帧时间（`loglevel=4`）**：内核 `Freeing drm_logo memory` 不在串口显示；刷机后用 `dmesg | grep -E 'drm_logo|Freeing'` 查看时间戳，或物理秒表看屏。

---

## 4. 优化阶段与状态

状态：`done` | `repo`（仓库已改，待刷机验证） | `pending` | `skip`（P1 不做）

### P0 — 对齐方案 A / 单一镜像（先做）

| ID | 项 | 状态 | 仓库 / 操作 |
|----|-----|------|-------------|
| P0-1 | 移除 `lws-hmi-debug-boot`、内核 `ip=` | **done** | 已删 service/script；`ynh960-linux-root.dtsi` |
| P0-2 | post-hook 禁用 `sshd`+`sshd.socket`+`mediamtx`+`bluetooth`（扫全部 `*.wants`） | **done** | `06-systemd.sh` + `post-fakeroot.sh` |
| P0-3 | mask `systemd-network-generator` | **done** | post-hook + post-fakeroot |
| P0-4 | `verify-boot` 命令（`boot-verify.sh` 实现）进 rootfs | **done** | overlay + post-hook |
| P0-5 | `verify-rootfs-overlay` 正确路径 `output/<profile>/target` | **done** | `scripts/verify-rootfs-overlay.sh` |
| P0-6 | `build-img` / `build-kernel` 后自动 export firmware → host | **done** | `docker-export-artifacts.sh` |
| P0-7 | 刷机后 `verify-boot` 全 PASS | **done** | 板端已验证（sshd/mediamtx/debug-boot 已清除） |
| P0-8 | 稳定断电（避免 DRM/Mali teardown oops） | **done** | poweroff 跳过 HMI teardown，使用 sync + SysRq；GEM teardown 另行加固 |

### A — 内核 / U-Boot（通常 −1～3 s）

| ID | 项 | 状态 | 说明 |
|----|-----|------|------|
| A-1 | U-Boot `bootdelay=0` | **skip** | 决定不再自编译 U-Boot；沿用 Innohi/SDK 预编译链 |
| A-2 | 内核 `loglevel=7` → `4` 或 `3` | **done** | `loglevel=4`；板端串口日志已减少 |
| A-3 | 裁内核无用驱动 | **repo** | `ynh960-kernel-trim.config`：裁 CAN/PCIe/NVMe/SATA/UFS、本地 CSI/RKISP/CIF/HDMIRX/DVB/tuner、DP/LVDS/RGB/TVE、heavy debug/test；保留 HDMI/USB/音频/文件系统/BT/Wi‑Fi/eth0/RKNPU/MPP/debugfs；**DTS** `ynh960-evb-trim.dtsi` 关 EVB 残留节点 — 见 [`docs/kernel-evb-dts-deferred.md`](kernel-evb-dts-deferred.md) |
| A-4 | RKNPU / Wi‑Fi / BT 延迟至首屏后 | **done** | disable `wifibt-init`/`wpa_supplicant`/`network.service`；板端已验证 |
| A-5 | 确认无 `After=systemd-udev-settle`（尤其 `hmi`） | **done** | `hmi.service` 设计已禁止；板端 `critical-chain` 已验证 |
| A-6 | eMMC `noatime` / HS200/HS400 | **done** | fstab + display-init；**勿**用 `rootflags=noatime`；HS400 沿用 SDK DTS |
| A-7 | 默认去掉 `ynh960-usb-gadget.config` | **done** | `ynh960_defconfig` |

### D0 — Boot splash（P1 必需，与 KPI 分开测）

| ID | 项 | 状态 |
|----|-----|------|
| D0-1 | 上电 <1～2 s logo | **done** 板端秒表约 2 s，基本无优化空间 |
| D0-2 | logo 保持至 flutter-pi 首帧接替 | **done** 板端确认：`Started flutter-pi` 后屏上仍为 boot logo，至 `Freeing drm_logo` |
| D0-3 | Weston 备选：DRM 接手后 logo 桥接 | **repo** desktop-shell + `boot-splash.png`（见 `embedder-migration-plan.md` E3.2）；冷启验收待补 |

### B — systemd 方案 A 瘦身（通常 −1～2 s）

| ID | 项 | 状态 |
|----|-----|------|
| B-1 | `lws_hmi_systemd.config` 关 desktop daemon | **done** |
| B-2 | journald `Storage=volatile` | **done** overlay |
| B-3 | `lws_hmi_base` 关 adbd / 虚拟 getty | **done** |
| B-4 | `lws_hmi_network` 关 dhcpcd/dropbear 等 | **done** |
| B-5 | 仅 enable `hmi` + `mainserver`；disable mediamtx/sshd/bt | **done** | post-hook + post-fakeroot |
| B-6 | `hmi.service` `Nice=-5` | **done** | 板端已验证；首帧 ~1s 未缩短（见 §5 注） |
| B-7 | sysinit 仅 `param-update`（显示） | **done** |
| B-8 | `cpu-performance.service`：CPU + DMC/GPU devfreq `performance` | **done** | governors 已生效；首帧 ~1s 未缩短（见 §5 注） |
| B-9 | disable `log-guardian.service` @ boot | **done** | 刷机验证通过；`08-systemd-finalize.sh` 防止 SDK `07-log-guardian.sh` 重新 enable |
| B-10 | `lws-hmi-settings-restore` **`After=hmi`**（非并行）；Nice/idle；Demo 对 `*-wanted` 显示 starting | **repo** | UI 绝对优先；网/BT 在首帧后恢复 |

### C — flutter-pi / App（通常 −1～3 s）

| ID | 项 | 状态 |
|----|-----|------|
| C-1 | Release AOT only | **done** P1 |
| C-2 | `main()` 首帧零重插件 | **done** P1 spec |
| C-3 | 懒加载 asset / 浅 widget 树 | **pending** P4/P5 |
| C-4 | 减小 `app.so` | **pending** 持续 |

### D — 存储（通常 −0.5～1 s）

| ID | 项 | 状态 |
|----|-----|------|
| D-1 | `/opt/hmi` 与 rootfs 同分区 | **done** overlay |
| D-2 | rootfs 精简 / strip | **done** Buildroot 默认 |

---

## 5. 推荐实施顺序

```
P0（done）
  → B-6 + B-8（done；首帧 EGL 瓶颈确认，不再深挖）
  → A-2（done；loglevel=4）
  → A-4（done；延迟 Wi‑Fi/BT/network）
  → B-9（done；disable log-guardian，刷机验证通过）
  → D0-1（done；splash 约 2 s，基本无优化空间）
  → A-1（skip；不再自编译 U-Boot）
  → C / A-3（产品阶段）
```

**一次只改一类**，避免分不清收益来源。

**首帧 ~1s 结论（B-6/B-8 板端）**：`lws-hmi-performance` 已 `Finished`，`Freeing drm_logo` 仍在 `Started flutter-pi` 后约 **1 s**（8.58 s vs 基线 8.67 s，收益可忽略）。屏上为 boot logo 保持，非黑屏。瓶颈在 **flutter-pi 进程内**（Mali EGL 初始化 + AOT 引擎 + 首帧 commit），**不强求**再压；KPI 余量充足（~9.7 s < 10 s）。

**A-6 注意**：`rootflags=noatime` 会致内核 panic（`ext4: Unknown parameter 'noatime'`）。`noatime` 须写在 fstab 第 4 列，由 `systemd-remount-fs` 生效。

**P0-8 注意**：继续保持 `systemd-logind` disabled。板端在 `systemctl stop hmi.service` 时先后捕获 `drm_gem_object_release_handle` 的空 funcs、损坏 funcs 指针，以及 GEM object 中变成非内核地址的 `obj->dev`。`overlay/kernel/patches/0001-drm-gem-handle-objects-without-funcs-on-release.patch` 会在访问 funcs/VMA/refcount 前验证 object 与 `obj->dev`，并为单一 GEM 类型驱动增加 canonical funcs table；Rockchip 对象在 release/free 前会恢复该不可变指针。pwrkey 等 `KEY_POWER` release 后再关机；同时必须禁用 Rockchip `input-event-daemon`，否则其 short-press release handler 会并发执行 `systemctl suspend`，抢在 SysRq poweroff 前进入 WFI。

**当前状态**：P0-8 使用 sync + SysRq 避免关机触发 HMI teardown；B-9 / D0-1 已完成；A-1 不再自编译 U-Boot；A-3 已接入 kernel trim fragment。首次刷机发现 `CONFIG_DEBUG_FS` 不可裁（systemd `sys-kernel-debug.mount` 会阻断 `local-fs.target`），已恢复 debugfs。

---

## 6. KPI 记录表（每轮刷机填写）

| 日期 | git 简述 | 上电→logo | 上电→multi-user | 上电→首帧 | verify-boot | 备注 |
|------|----------|-----------|-----------------|-----------|-------------|------|
| 2026-07 | baseline（优化前日志） | | ~8.7s | ~9.7s | FAIL sshd/mtx | `Started flutter-pi` 后 ~1s 仍见 logo |
| 2026-07 | P0 重刷 | | | | PASS | sshd/mediamtx/debug-boot 已清除 |
| 2026-07 | +B-6/B-8 performance | | ~8.6s | ~8.6s | PASS | governors OK；首帧仍 ~1s logo→UI |
| 2026-07 | +A-2 loglevel=4 | | | | PASS | 串口日志减少 |
| 2026-07 | +A-6 noatime | | | | PASS | mount 含 noatime；勿用 rootflags |
| 2026-07 | +A-4 defer wifibt | | | | PASS | 无 wpa/network @ boot |
| 2026-07 | +B-9 log-guardian | ~2s | ~8.4s | ~8.4s | PASS | `log-guardian` 未自启；D0-1 splash 约 2s |
| 2026-07 | +A-3 kernel trim | | | | PASS | 随 P1 sign-off 重刷验证（保留 debugfs） |
| 2026-07 | +P0-8 pwrkey poweroff | | | | PASS | 板端：stop hmi 仍会 DRM oops；改为 sync + SysRq remount-ro/poweroff |
| **2026-07-11** | **P1 sign-off** `4c2b6dc` | ~2s | ~8.4s | ~8.4s | **PASS** | **P1 封板**：GPT 1GiB rootfs + userdata grow、`root=/dev/mmcblk0p6`、fstab/userdata 修复、evb-trim DTS、USB plug-ssh §7 硬件验收全 PASS；Hello World + HMI 自启；OpenSpec P1 + plug-ssh 归档 |

---

## 7. 相关文件索引

| 路径 | 作用 |
|------|------|
| `overlay/.../06-systemd.sh` | enable/disable unit、mask、fstab noatime |
| `overlay/.../08-systemd-finalize.sh` | 收尾清理 SDK post-hook 重新 enable 的 unit（如 `log-guardian`）和退役脚本 |
| `overlay/.../99-appliance.preset` | preset-all 后保持 Plan A disable 列表 |
| `overlay/.../cpu-performance.service` | 首帧前拉满 CPU/DMC/GPU 频率 |
| `overlay/.../set-performance-mode.sh` | 写 cpufreq + devfreq governor |
| `overlay/.../pwrkey-poweroff.service` | 板载 pwrkey 触发关机 |
| `overlay/.../pwrkey-poweroff.sh` | 监听 `KEY_POWER` → `shutdown.sh poweroff` |
| `overlay/.../shutdown.sh` | 跳过 HMI teardown；sync 后使用 SysRq `s/u/o` 或 `s/u/b` |
| `overlay/.../systemctl-poweroff-wrapper.sh` | 拦截 `systemctl poweroff/halt/reboot` |
| `overlay/.../pre-poweroff.sh` | 不停止 HMI；在 SysRq 关机前执行 storage sync |
| `overlay/.../hmi.service` | flutter-pi；`Nice=-5` |
| `overlay/.../boot-verify.sh` | 板端 Plan A / 启动 KPI 验收 |
| `overlay/.../env-verify.sh` | 板端 §3.4 平台栈验收（不含 flutter-pi） |
| `overlay/.../post-fakeroot.sh` | preset-all 后重链 Plan A wants |
| `scripts/verify-rootfs-overlay.sh` | 构建后 staging 检查 |
| `overlay/kernel/rockchip/ynh960-linux-root.dtsi` | 内核 cmdline（`root=/dev/mmcblk0p6`、`loglevel=4`） |
| `overlay/kernel/rockchip/ynh960-evb-trim.dtsi` | EVB 节点 disable（FAN53555/SFC；保留 fiq-debugger 串口） |
| `overlay/kernel/rockchip/ynh960-kernel-trim.config` | A-3 内核裁剪 fragment（保留 HDMI/USB/音频/文件系统/蓝牙/debugfs） |
| `docs/storage-layout.md` | GPT 分区（1GiB rootfs + grow userdata） |
| `docs/kernel-evb-dts-deferred.md` | 内核 dmesg 残留项追踪（P2/P3+） |
| `docs/flutter-pi-hmi-plan.md` §3.6 / §14 | 设计详述 |
| `docs/build-optimization.md` | 日常构建命令 |

---

*最后更新：**P1 封板** 2026-07-11（`4c2b6dc`）；§6 KPI 表已记 sign-off 行；P0-8 / B-9 / D0-1 / A-3 done；A-1 skip。*
