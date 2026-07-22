# IP Camera RTSP 收流码率：Mac vs Android 板 vs Linux 板

记录同相机、同硅片路径上的 inbound RTSP 码率对比，以及 **2026-07-22 已确认的根因与修复**。  
换主板 / 换 GMAC·PHY 布线时，用本文的方法与脚本做验收。

相关：[`network-stack.md`](network-stack.md)（eth0 / networkd）、[`ynh960-uart5-gmac.dtsi`](../overlay/kernel/rockchip/ynh960-uart5-gmac.dtsi)、产品 IPC（`app/hmi/.../ip_camera_*` + MediaMTX）。

---

## 1. 结论（先读）

| 结论 | 含义 |
|------|------|
| **相机本身是低码流** | Mac 直连 PR1 UDP ≈ **3.4 Mbps**（1080p 量级） |
| **Android ≈ Mac** | 同相机插板 eth0，PR1 UDP remux ≈ **3.3–3.5 Mbps**，`mmc_rx_crc` 增量 **0** |
| **Linux 曾落后** | `clock_in_out=output` 时 remux ≈ **1.5–2.3 Mbps**，伴 **`mmc_rx_crc_error` 上千** + RTP missed |
| **根因（已修）** | RMII 参考时钟方向错误：SoC 出 50 MHz（`output`）与板级「PHY 出时钟」不符 → MAC 层 CRC 丢帧 |
| **修复** | 完整对齐 Android / `rk3568-evb2` RMII input：`clock_in_out=input` + `SCLK_GMAC1` parent=`gmac1_clkin@50M`，并删除 SoC `assigned-clock-rates` |
| **修复后 Linux** | PR1/PR0 remux ≈ **3.3–3.6 Mbps**，wire ≈ **3.8–4.1**，MMC CRC Δ **0**，RTP missed **0**（停 hmi/mediamtx 单消费者） |

**一句话：** 差距不在相机、也不在 ffmpeg；在 **Linux DTS 的 RMII 时钟布线**。只改 `clock_in_out` 字符串不够，必须连同 `assigned-clock-parents` / `gmac1_clkin` 一起改。

---

## 2. 测量方法（保留，换板必用）

跨端对比时一律用 **同构 remux**：板/机上的 `ffmpeg -c copy → mpegts`，用文件字节 ÷ 墙钟秒算 Mbps；并同时看 **wire**（`eth0` `rx_bytes`）和 **`ethtool -S` MMC CRC**。

### 2.1 脚本

| 脚本 | 端 | 作用 |
|------|----|------|
| [`scripts/measure-ip-camera-rtsp.sh`](../scripts/measure-ip-camera-rtsp.sh) | Mac / 任意主机 | 相机直连主机时的 remux 基线 |
| [`scripts/measure-ip-camera-rtsp-adb.sh`](../scripts/measure-ip-camera-rtsp-adb.sh) | Android（adb） | 推静态 aarch64 ffmpeg，测板 eth0 收流 |
| [`scripts/measure-ip-camera-rtsp-ssh.sh`](../scripts/measure-ip-camera-rtsp-ssh.sh) | Linux HMI（USB-SSH） | 同上 + **MMC CRC / RTP missed / softnet** |

示例：

```bash
# Mac：相机 RJ45 直连 Mac，NIC 配 192.168.1.234/24
scripts/measure-ip-camera-rtsp.sh 12

# Android 板（注意：adb serial 可能 ≠ 产品 SN）
SERIAL=<adb-serial> STREAMS="PR1 PR0" TRANSPORTS="udp tcp" \
  scripts/measure-ip-camera-rtsp-adb.sh 12

# Linux 板（默认停 hmi+mediamtx，单消费者）
SN=<product-sn> STREAMS="PR1 PR0" TRANSPORTS="udp" \
  scripts/measure-ip-camera-rtsp-ssh.sh 12

# 多轮抽查（推荐换板验收）
SN=<product-sn> STREAMS="PR1 PR1 PR1 PR0" \
  scripts/measure-ip-camera-rtsp-ssh.sh 12
```

### 2.2 通过标准（建议）

在 **停 `hmi`/`mediamtx`**、相机 `192.168.1.100`、板 eth0 `192.168.1.234/24`、100 M 全双工、ping &lt;1 ms 0% loss 前提下：

| 指标 | 健康 | 异常（本坑典型） |
|------|------|------------------|
| PR1 UDP remux | **≥ ~3.3 Mbps** | ~1.5–2.3 |
| wire（`rx_bytes`） | **~3.8–4.2 Mbps** | ~2.4 |
| `mmc_rx_crc_error` 拉流窗口增量 | **0**（或个位数） | **~1500–2000 / 12 s** |
| ffmpeg 日志 `RTP: missed` | **0** | 成百上千行 |
| sysfs `rx_crc_errors` | 常为 0 | **不可信** — 必须以 `ethtool -S eth0` 的 `mmc_rx_*` 为准 |

### 2.3 工具缓存（主机）

| 路径 | 用途 |
|------|------|
| `.cache/ffmpeg-android/ffmpeg` | johnvansickle **arm64-static** ffmpeg；Android/Linux 板共用（SSH/adb 推到 `/tmp/ffmpeg` 或 `/data/local/tmp/ffmpeg`） |
| `.cache/android-ethtool/ethtool-static` | 静态 aarch64 `ethtool`（Android 上读 `mmc_rx_crc_error`；可推到 `/data/local/tmp/ethtool`） |

缺 ffmpeg 时自行下载 arm64 static 放到上述路径；脚本通过 `FFMPEG_HOST=` 可覆盖。

### 2.4 环境（共通）

| 项 | 值 |
|----|-----|
| 相机 | `192.168.1.100`，`rtsp://192.168.1.100/PR{0,1}` |
| 板 eth0 | `192.168.1.234/24`，**100 Mbps**，`rk_gmac-dwmac`，**RMII** |
| PHY | ICPlus **IP101G**（Linux 有关 APS 的补丁，见锚点表） |
| Linux USB-SSH | 典型 `root@192.168.55.1`，主机 `en12` → `192.168.55.2`（`BindInterface=en12`） |
| Android | 同产品线样机；**adb serial 与产品 ChipID/SN 可能不同**，以 `adb devices` 为准 |

### 2.5 板上快速核对（无脚本时）

```bash
# 时钟方向（期望 input + dmesg “clock input from PHY”）
cat /proc/device-tree/ethernet@fe010000/clock_in_out; echo
dmesg | grep -iE 'clock input|RMII' | head

# 拉流窗口 MMC（勿只看 sysfs rx_crc_errors）
ethtool -S eth0 | grep -E 'mmc_rx_crc_error|mmc_rx_udp_err'
```

---

## 3. 结果表

### 3.1 基线（修复前 / 对照端）

| 接收端 | PR1 UDP remux | 备注 |
|--------|---------------|------|
| **Mac** | ~**3.4** | 相机插 Mac |
| **Android** | ~**3.3–3.5**；wire ~**4.1**；MMC CRC Δ **0** | 同相机插板 |
| **Linux（旧，`output`）** | ~**1.5–2.3**；wire ~**2.4**；MMC CRC Δ **~1900/12s** | 用户态 RTP 大量 missed |

### 3.2 Linux 修复后（2026-07-22，完整 `input` + `gmac1_clkin`）

连续 4 次（停 hmi/mediamtx，ffmpeg `-t 12`）：

| 轮次 | 流 | remux | wire | MMC CRC Δ | RTP missed |
|------|----|-------|------|-----------|------------|
| r1 | PR1 | **3.60** | 4.10 | **0** | **0** |
| r2 | PR1 | **~3.3–3.6**（ffmpeg ≈3611 kbps） | 3.79 | **0** | **0** |
| r3 | PR1 | **3.63** | 4.10 | **0** | **0** |
| r4 | PR0 | **3.65** | 3.80 | **0** | **0** |

用户全量 `build-kernel` + `build-rootfs` + upgrade 后再测，结论不变。

---

## 4. 根因与踩坑（必读）

### 4.1 真正根因

板级 RMII：**PHY 提供 50 MHz REF_CLK** → SoC GMAC 应配置为 **`clock_in_out = "input"`**，并把 `SCLK_GMAC1` 的 parent 设为 **`&gmac1_clkin`（50 MHz fixed-clock）**。

错误配置（SoC `output` + `assigned-clock-rates = <0>, <50000000>`）下链路仍可 UP、ping 正常，但高吞吐 UDP 时 MAC 校验失败 → **`mmc_rx_crc_error` 飙升** → wire 掉到 ~2.4 → remux/RTP 更差。

参考 DTS：SDK `rk3568-evb2-lp4x-v10.dtsi` 的 `&gmac1` RMII input 块；产品落地见 [`ynh960-uart5-gmac.dtsi`](../overlay/kernel/rockchip/ynh960-uart5-gmac.dtsi)。

### 4.2 踩坑清单

| 坑 | 现象 | 正确做法 |
|----|------|----------|
| **只改 `clock_in_out="input"`，仍保留 SoC `assigned-clock-rates` 50 MHz** | remux 崩到 ~**0.5 Mbps**、RTP 丢失极高 | 必须同时：`assigned-clock-parents` 含 `gmac1_clkin`，**删除** SoC 对 `SCLK_GMAC1` 的 rate 赋值，并设 `&gmac1_clkin { clock-frequency = <50000000>; }` |
| **相信 sysfs `rx_crc_errors`** | 一直为 0，误判「无 CRC」 | 看 **`ethtool -S eth0` → `mmc_rx_crc_error` / `mmc_rx_udp_err`** |
| **用 gst/`rx_bytes` 与 Mac remux 横比** | 数字不可比 | 三端都用同一 ffmpeg remux 脚本 |
| **`ethtool -G` / C 版 `eth0-tune` 改 ring** | eth0 反复 Link Up/Down，RTSP 全滅 | `eth0-tune.sh` **只做 sysfs/sysctl + pause off**，禁止热路径 ring resize |
| **`networkctl reconfigure eth0` 无谓触发** | carrier flap | App / apply 路径避免；见 `ip_camera_eth0_path.dart` |
| **多消费者同时拉相机** | 放大 UDP 丢包 | 测量时 `STOP_SERVICES=1`；产品经 MediaMTX 单上游 |
| **Android adb serial ≠ 产品 SN** | 连错设备 | `adb devices -l`；Linux 用 `make devices` / `SN=` |

### 4.3 曾有帮助但非根因的调参

| 项 | 作用 |
|----|------|
| stmmac `flow_ctrl=0` / `watchdog=0`（`eth0-tune.sh` + bootargs） | 在 **错误时钟** 下曾把线速从 ~2.5 抬到 ~3.1，**仍无法**清零 MMC CRC、无法稳定对齐 Android |
| pause off、RPS、`rmem_*` | 卫生项；单独不够 |
| IP101G 关 APS（`0005-icplus-…patch`） | 链路更稳；**不是**码率银弹 |

时钟修好后，这些仍可保留作 RMII IPC 链路卫生配置。

---

## 5. 换主板 / 新 SKU 验收清单

1. **确认 PHY 接口**：RMII vs RGMII；复位 GPIO；MDIO 地址；REF_CLK 由谁驱动（问硬件或对照 Android/原厂 DTB）。
2. **写 DTS**：若 PHY 出时钟，照抄「完整 input」模式（§4.1），勿只改一个字符串。
3. **`make apply-overlay` → `make build-kernel` → `make upgrade`**（DTS 在 FIT 内；全量 rootfs 按需）。
4. **开机核对**：`clock_in_out=input`（或硬件要求的方向）；`dmesg` 含预期 clock 文案；`ping` 相机。
5. **跑** `measure-ip-camera-rtsp-ssh.sh`（及可选 Android/Mac 对照）：满足 §2.2。
6. **若 remux 低但 MMC CRC≈0**：再查用户态（MediaMTX/多消费者/缓冲）；**若 MMC CRC 高**：先查时钟/时序/延时，再查 pause/ring。

---

## 6. 仓库锚点

| 路径 | 角色 |
|------|------|
| `scripts/measure-ip-camera-rtsp.sh` | Mac/主机 remux |
| `scripts/measure-ip-camera-rtsp-adb.sh` | Android remux |
| `scripts/measure-ip-camera-rtsp-ssh.sh` | Linux remux + MMC/RTP/softnet |
| `.cache/ffmpeg-android/ffmpeg` | 板端静态 ffmpeg（gitignore；需自备） |
| `.cache/android-ethtool/ethtool-static` | Android 静态 ethtool（可选） |
| `overlay/kernel/rockchip/ynh960-uart5-gmac.dtsi` | RMII + **完整 `clock_in_out=input`** |
| `overlay/.../eth0-tune.sh` | stmmac/sysctl/RPS/pause；**禁止 ring resize** |
| `overlay/.../90-eth0-ipc-tune.rules` | eth0 出现时触发 tune |
| `overlay/kernel/patches/0005-icplus-ip101a-disable-aps-ynh960.patch` | IP101G 关 APS |
| `overlay/.../render-mediamtx-config.sh` | 上游 RTSP transport 策略 |
| `app/hmi/.../ip_camera_eth0_path.dart` | 避免无谓 reconfigure |
| `app/hmi/.../ip_camera_product_session.dart` | 忽略自有 apply 期间 flap |

---

## 7. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-21 | 初版：Mac / Android / Linux 对比与假说 |
| 2026-07-22 | stmmac `flow_ctrl`/`watchdog` 与测量脚本；发现 **MMC CRC** 与 sysfs 误导 |
| 2026-07-22 | **根因确认并修复：** 完整 RMII `clock_in_out=input` + `gmac1_clkin`；Linux 对齐 Android；文档改为验收手册 + 踩坑记录 |
