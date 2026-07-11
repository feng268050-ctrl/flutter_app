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
| `make docker-volume-pull` | 是 | 仅 legacy：导出完整 `sdk/output/` |

Linux 原生构建：无 Docker volume，跳过 export；`output/firmware/` 直接在 host SDK 下。

---

## 3. 板端验收（每轮刷机后）

```bash
/usr/lib/lws-hmi/boot-verify.sh
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain hmi.service
/usr/lib/lws-hmi/env-verify.sh    # §3.4 平台栈（RKNPU2 / wifibt / prep 组件）
```

**`boot-verify` 期望**：`hmi` + `mainserver` + `lws-hmi-performance` + `lws-hmi-pwrkey-poweroff` enabled；`sshd`/`sshd.socket`/`mediamtx`/`bluetooth`/`wifibt-init`/`wpa_supplicant`/`network`/`log-guardian` 未链接；22 未监听；`network-generator` masked；pwrkey input 存在且服务 active；`flutter-pi` running；CPU/devfreq governor 为 `performance`（WARN 若否）。

**秒表**（填 §6 表格）：上电 → logo；上电 → multi-user；上电 → 首页首帧。

**首帧时间（`loglevel=4`）**：内核 `Freeing drm_logo memory` 不在串口显示；刷机后用 `dmesg | grep -E 'drm_logo|Freeing'` 查看时间戳，或物理秒表看屏。

---

## 4. 优化阶段与状态

状态：`done` | `repo`（仓库已改，待刷机验证） | `pending` | `skip`（P1 不做）

### P0 — 对齐方案 A / 单一镜像（先做）

| ID | 项 | 状态 | 仓库 / 操作 |
|----|-----|------|-------------|
| P0-1 | 移除 `lws-hmi-debug-boot`、内核 `ip=` | **done** | 已删 service/script；`lws-hmi-ynh960-linux-root.dtsi` |
| P0-2 | post-hook 禁用 `sshd`+`sshd.socket`+`mediamtx`+`bluetooth`（扫全部 `*.wants`） | **done** | `06-lws-hmi-systemd.sh` + `lws-hmi-post-fakeroot.sh` |
| P0-3 | mask `systemd-network-generator` | **done** | post-hook + post-fakeroot |
| P0-4 | `boot-verify.sh` 进 rootfs + post-hook 安装 helper 脚本 | **done** | overlay + post-hook |
| P0-5 | `verify-rootfs-overlay` 正确路径 `output/<profile>/target` | **done** | `scripts/verify-rootfs-overlay.sh` |
| P0-6 | `build-img` / `build-kernel` 后自动 export firmware → host | **done** | `docker-export-artifacts.sh` |
| P0-7 | 刷机后 `boot-verify` 全 PASS | **done** | 板端已验证（sshd/mediamtx/debug-boot 已清除） |
| P0-8 | 稳定断电（避免 DRM/Mali teardown oops） | **done** | 不 stop `hmi`；`systemctl` wrapper + `shutdown.sh` 先 sync/remount-ro，再 SysRq poweroff |

### A — 内核 / U-Boot（通常 −1～3 s）

| ID | 项 | 状态 | 说明 |
|----|-----|------|------|
| A-1 | U-Boot `bootdelay=0` | **skip** | 决定不再自编译 U-Boot；沿用 Innohi/SDK 预编译链 |
| A-2 | 内核 `loglevel=7` → `4` 或 `3` | **done** | `loglevel=4`；板端串口日志已减少 |
| A-3 | 裁内核无用驱动 | **repo** | `lws-hmi-kernel-trim.config`：裁 CAN/PCIe/NVMe/SATA/UFS、本地 CSI/RKISP/CIF/HDMIRX/DVB/tuner、DP/LVDS/RGB/TVE、heavy debug/test；保留 HDMI/USB/音频/文件系统/BT/Wi‑Fi/eth0/RKNPU/MPP/debugfs；**DTS** `lws-hmi-ynh960-evb-trim.dtsi` 关 EVB 残留节点 — 见 [`docs/kernel-evb-dts-deferred.md`](kernel-evb-dts-deferred.md) |
| A-4 | RKNPU / Wi‑Fi / BT 延迟至首屏后 | **done** | disable `wifibt-init`/`wpa_supplicant`/`network.service`；板端已验证 |
| A-5 | 确认无 `After=systemd-udev-settle`（尤其 `hmi`） | **done** | `hmi.service` 设计已禁止；板端 `critical-chain` 已验证 |
| A-6 | eMMC `noatime` / HS200/HS400 | **done** | fstab + display-init；**勿**用 `rootflags=noatime`；HS400 沿用 SDK DTS |
| A-7 | 默认去掉 `lws-hmi-debug-usb.config` | **done** | `ynh960_defconfig` |

### D0 — Boot splash（P1 必需，与 KPI 分开测）

| ID | 项 | 状态 |
|----|-----|------|
| D0-1 | 上电 <1～2 s logo | **done** 板端秒表约 2 s，基本无优化空间 |
| D0-2 | logo 保持至 flutter-pi 首帧接替 | **done** 板端确认：`Started flutter-pi` 后屏上仍为 boot logo，至 `Freeing drm_logo` |

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
| B-8 | `lws-hmi-performance.service`：CPU + DMC/GPU devfreq `performance` | **done** | governors 已生效；首帧 ~1s 未缩短（见 §5 注） |
| B-9 | disable `log-guardian.service` @ boot | **done** | 刷机验证通过；`08-lws-hmi-systemd-finalize.sh` 防止 SDK `07-log-guardian.sh` 重新 enable |

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

**P0-8 注意**：继续保持 `systemd-logind` disabled。板端确认 `systemctl stop hmi.service` 本身也会偶发触发 Mali/DRM `drm_gem_object_release_handle` oops，因此不能依赖“先停 HMI”。当前策略是避开 systemd 的用户服务 teardown：`systemctl` wrapper / pwrkey 均进入 `shutdown.sh`，执行 `sync` + SysRq `s/u/o`（sync、remount readonly、poweroff），失败时才 fallback 到 `systemctl.real --force --force poweroff`。

**当前状态**：P0-8 已按 SysRq poweroff 路径完成；B-9 / D0-1 已完成；A-1 不再自编译 U-Boot；A-3 已接入 kernel trim fragment。首次刷机发现 `CONFIG_DEBUG_FS` 不可裁（systemd `sys-kernel-debug.mount` 会阻断 `local-fs.target`），已恢复 debugfs，待重新 build-kernel/build-img/flash 验证。

---

## 6. KPI 记录表（每轮刷机填写）

| 日期 | git 简述 | 上电→logo | 上电→multi-user | 上电→首帧 | boot-verify | 备注 |
|------|----------|-----------|-----------------|-----------|-------------|------|
| 2026-07 | baseline（优化前日志） | | ~8.7s | ~9.7s | FAIL sshd/mtx | `Started flutter-pi` 后 ~1s 仍见 logo |
| 2026-07 | P0 重刷 | | | | PASS | sshd/mediamtx/debug-boot 已清除 |
| 2026-07 | +B-6/B-8 performance | | ~8.6s | ~8.6s | PASS | governors OK；首帧仍 ~1s logo→UI |
| 2026-07 | +A-2 loglevel=4 | | | | PASS | 串口日志减少 |
| 2026-07 | +A-6 noatime | | | | PASS | mount 含 noatime；勿用 rootflags |
| 2026-07 | +A-4 defer wifibt | | | | PASS | 无 wpa/network @ boot |
| 2026-07 | +B-9 log-guardian | ~2s | ~8.4s | ~8.4s | PASS | `log-guardian` 未自启；D0-1 splash 约 2s |
| 2026-07 | +A-3 kernel trim | | | | | 待重刷；保留 HDMI/USB/音频/文件系统/蓝牙/debugfs |
| 2026-07 | +P0-8 pwrkey poweroff | | | | PASS | 板端：stop hmi 仍会 DRM oops；改为 sync + SysRq remount-ro/poweroff |

---

## 7. 相关文件索引

| 路径 | 作用 |
|------|------|
| `overlay/.../06-lws-hmi-systemd.sh` | enable/disable unit、mask、fstab noatime |
| `overlay/.../08-lws-hmi-systemd-finalize.sh` | 收尾清理 SDK post-hook 重新 enable 的 unit（如 `log-guardian`）和退役脚本 |
| `overlay/.../99-lws-hmi.preset` | preset-all 后保持 Plan A disable 列表 |
| `overlay/.../lws-hmi-performance.service` | 首帧前拉满 CPU/DMC/GPU 频率 |
| `overlay/.../set-performance-mode.sh` | 写 cpufreq + devfreq governor |
| `overlay/.../lws-hmi-pwrkey-poweroff.service` | 板载 pwrkey 触发关机 |
| `overlay/.../pwrkey-poweroff.sh` | 监听 `KEY_POWER` → `shutdown.sh poweroff` |
| `overlay/.../shutdown.sh` | `pre-poweroff.sh` → SysRq `s/u/o`，fallback `systemctl.real --force --force poweroff` |
| `overlay/.../systemctl-poweroff-wrapper.sh` | 拦截 `systemctl poweroff/halt/reboot` |
| `overlay/.../pre-poweroff.sh` | 不停 HMI；仅 `sync`，避免触发 DRM teardown |
| `overlay/.../hmi.service` | flutter-pi；`Nice=-5` |
| `overlay/.../boot-verify.sh` | 板端 Plan A / 启动 KPI 验收 |
| `overlay/.../env-verify.sh` | 板端 §3.4 平台栈验收（不含 flutter-pi） |
| `overlay/.../lws-hmi-post-fakeroot.sh` | preset-all 后重链 Plan A wants |
| `scripts/verify-rootfs-overlay.sh` | 构建后 staging 检查 |
| `overlay/kernel/rockchip/lws-hmi-ynh960-linux-root.dtsi` | 内核 cmdline（`loglevel=4`） |
| `overlay/kernel/rockchip/lws-hmi-kernel-trim.config` | A-3 内核裁剪 fragment（保留 HDMI/USB/音频/文件系统/蓝牙/debugfs） |
| `docs/flutter-pi-hmi-plan.md` §3.6 / §14 | 设计详述 |
| `docs/build-optimization.md` | 日常构建命令 |

---

*最后更新：P0-8 done（pwrkey / systemctl poweroff 走 SysRq 稳定断电）；A-3 repo（恢复 debugfs，待重刷验证）；B-9 / D0-1 done；A-1 skip。*
