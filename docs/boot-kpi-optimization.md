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
```

**`boot-verify` 期望**：`hmi` + `mainserver` enabled；`sshd`/`sshd.socket`/`mediamtx`/`bluetooth` 未链接；22 未监听；`network-generator` masked；`flutter-pi` running。

**秒表**（填 §6 表格）：上电 → logo；上电 → multi-user；上电 → 首页首帧。

---

## 4. 优化阶段与状态

状态：`done` | `repo`（仓库已改，待刷机验证） | `pending` | `skip`（P1 不做）

### P0 — 对齐方案 A / 单一镜像（先做）

| ID | 项 | 状态 | 仓库 / 操作 |
|----|-----|------|-------------|
| P0-1 | 移除 `lws-hmi-debug-boot`、内核 `ip=` | **done** | 已删 service/script；`lws-hmi-ynh960-linux-root.dtsi` |
| P0-2 | post-hook 禁用 `sshd`+`sshd.socket`+`mediamtx`+`bluetooth`（扫全部 `*.wants`） | **repo** | `06-lws-hmi-systemd.sh` |
| P0-3 | mask `systemd-network-generator` | **repo** | post-hook |
| P0-4 | `boot-verify.sh` 进 rootfs + post-hook 安装 helper 脚本 | **repo** | overlay + post-hook |
| P0-5 | `verify-rootfs-overlay` 正确路径 `output/<profile>/target` | **repo** | `scripts/verify-rootfs-overlay.sh` |
| P0-6 | `build-img` / `build-kernel` 后自动 export firmware → host | **repo** | `docker-export-artifacts.sh` |
| P0-7 | 刷机后 `boot-verify` 全 PASS | **pending** | 板端验证 |
| P0-8 | 正常 `poweroff`（避免 EXT4 recovery） | **pending** | 运维 |

### A — 内核 / U-Boot（通常 −1～3 s）

| ID | 项 | 状态 | 说明 |
|----|-----|------|------|
| A-1 | U-Boot `bootdelay=0` | **pending** | 预编译 uboot 需确认能否改 env；**不编译 uboot** 除非 Innohi 同意 |
| A-2 | 内核 `loglevel=7` → `4` 或 `3` | **pending** | 保留 `console=ttyFIQ0`；一次只改一项并秒表对比 |
| A-3 | 裁内核无用驱动 | **pending** | 回归风险中；末阶段 |
| A-4 | RKNPU / Wi‑Fi / BT 延迟 modprobe | **pending** | 末阶段 |
| A-5 | 确认无 `After=systemd-udev-settle`（尤其 `hmi`） | **repo** | 设计已禁止；板端 `critical-chain` 验证 |
| A-6 | eMMC `noatime` / HS200/HS400 | **pending** | fstab / DTS |
| A-7 | 默认去掉 `lws-hmi-debug-usb.config` | **done** | `ynh960_defconfig` |

### D0 — Boot splash（P1 必需，与 KPI 分开测）

| ID | 项 | 状态 |
|----|-----|------|
| D0-1 | 上电 <1～2 s logo | **pending** 板端 |
| D0-2 | logo 保持至 flutter-pi 首帧接替 | **pending** 板端 |

### B — systemd 方案 A 瘦身（通常 −1～2 s）

| ID | 项 | 状态 |
|----|-----|------|
| B-1 | `lws_hmi_systemd.config` 关 desktop daemon | **done** |
| B-2 | journald `Storage=volatile` | **done** overlay |
| B-3 | `lws_hmi_base` 关 adbd / 虚拟 getty | **done** |
| B-4 | `lws_hmi_network` 关 dhcpcd/dropbear 等 | **done** |
| B-5 | 仅 enable `hmi` + `mainserver`；disable mediamtx/sshd/bt | **repo** post-hook |
| B-6 | `hmi.service` `Nice=-5` | **skip** 待 P0 通过后实测 |
| B-7 | sysinit 仅 `param-update`（显示） | **done** |

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
P0（刷机 + boot-verify PASS）
  → 记录 baseline 秒表（§6）
  → A-2（仅 loglevel，刷机对比）
  → D0 验收 splash
  → B-6 等可选项（实测）
  → C / A-3/A-4（产品阶段）
```

**一次只改一类**，避免分不清收益来源。

---

## 6. KPI 记录表（每轮刷机填写）

| 日期 | git 简述 | 上电→logo | 上电→multi-user | 上电→首帧 | boot-verify | 备注 |
|------|----------|-----------|-----------------|-----------|-------------|------|
| | baseline（优化前日志） | | ~8.7s | | FAIL sshd/mtx | |
| | P0 重刷 | | | | | |
| | +A-2 loglevel | | | | | |

---

## 7. 相关文件索引

| 路径 | 作用 |
|------|------|
| `overlay/.../06-lws-hmi-systemd.sh` | enable/disable unit、mask、安装 helper 脚本 |
| `overlay/.../lws-hmi-fs-overlay/usr/lib/lws-hmi/boot-verify.sh` | 板端验收 |
| `scripts/verify-rootfs-overlay.sh` | 构建后 staging 检查 |
| `scripts/docker-export-artifacts.sh` | macOS：volume → host firmware |
| `docs/flutter-pi-hmi-plan.md` §3.6 / §14 | 设计详述 |
| `docs/build-optimization.md` | 日常构建命令 |

---

*最后更新：与 P1 boot 优化讨论同步；改优化项时请更新 §4 状态列。*
