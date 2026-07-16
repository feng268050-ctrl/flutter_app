# ynh960 I/O · 串口 / GPIO / pinmux 台账（P2.1）

基准板：**ynh960（RK3566）**。同产品线 ynh961/962 拓扑相近；跨 SKU 改板时先对照本表与原理图，再改 DTS。

契约真相源：**DTS 标签 + Linux 节点路径**（`/dev/ttyS5`、`/sys/class/gpio_innohi/GPIO_N`）。**不要**用 YNHAPI 0-based 下标当 Linux 主键（见 [`flutter-pi-hmi-plan.md` §11.0](flutter-pi-hmi-plan.md)）。

EVB 杂讯与尚未阻塞产品的项：[`kernel-evb-dts-deferred.md`](kernel-evb-dts-deferred.md)。

---

## 1. 串口（UART）

| Linux | Mux / 引脚 | 产品用途 | 状态 |
|-------|------------|----------|------|
| **`/dev/ttyS5`**（`uart5m1`） | gpio3 **PC2/PC3** | **Modbus RTU**（App 写死此路径） | OK；曾被 EVB gmac PHY reset 占用 PC2 — 已修 |
| `ttyS4` / uart4 | gpio3 PB1/PB2 | **disabled**；丝印 COM4 → 侧栏黄/红 LED | 故意留给 `own-gpio` |
| `ttyS1` / uart1 | BT HCI | 蓝牙 | OK |
| `ttyS3` / uart3m1 | gpio3 PB7/PC0 | 板级调试 UART | 与 Modbus/LED 无重叠 |
| `ttyS7` / uart7m1 | gpio3 PC4/PC5 | **disabled** | 让出给 LED `pwm14`/`pwm15` |
| `ttyFIQ0` | FIQ console | 工程串口（`console=ttyFIQ0`） | **保持 enabled**；关节点则 earlycon 后无串口输出 |

**踩坑（Modbus）：** EVB `&gmac1` 曾设 `snps,reset-gpio = gpio3 RK_PC2`（= UART5_TX）。现象：TX 计数↑、**无 RX**（Android 正常）。修复：[`lws-hmi-ynh960-uart5-gmac.dtsi`](../overlay/kernel/rockchip/lws-hmi-ynh960-uart5-gmac.dtsi) — PHY reset 改 `gpio4 PB3`，`phy-mode=rmii`，MDIO `reg=<1>`。

**踩坑（LED PWM）：** EVB `&uart7` 占 gpio3 PC4/PC5 → `pwm14` 无法 probe。修复：[`lws-hmi-ynh960-uart7-pwm.dtsi`](../overlay/kernel/rockchip/lws-hmi-ynh960-uart7-pwm.dtsi) 禁用 uart7。面板背光是 **pwm4**，不受影响。

---

## 2. 三色指示灯（`gpio_innohi`）

| 颜色 | DTS / sysfs 标签 | SoC pad | Linux GPIO#（兜底） | YNHAPI 入参（仅 Android 降级） |
|------|------------------|---------|---------------------|--------------------------------|
| 红 | **`GPIO_5`** | gpio3 RK_PB1 | 105 | `YNHAPI.GPIO_5` → **4** |
| 黄 | **`GPIO_4`** | gpio3 RK_PB2 | 106 | `YNHAPI.GPIO_4` → **3** |
| 绿 | **`GPIO_7`** | gpio4 RK_PC5 | 149 | `YNHAPI.GPIO_7` → **6** |

- 路径：`/sys/class/gpio_innohi/GPIO_N/value`（写 `0`/`1`）。
- App：`app/hmi/lib/gpio/gpio_led_config.dart` — 红/黄/绿 = **5/4/7**（勿改成 4/3/6）。
- 开机默认：**关**（overlay 将 `GPIO_4/5/7` 的 `default-value` 设为 `"0"`）。

经典 `/sys/class/gpio/export` 仅作工程兜底；`gpio_innohi` 已占用同脚时 export 失败是预期行为。

---

## 3. `own-gpio` ↔ gmac1 冲突

| 现象 | 原因 | 修复 |
|------|------|------|
| 整组 `own-gpio` probe 失败 → 侧栏灯卡死（常全亮） | EVB gmac1 **RGMII** 占用 gpio4 A0/A1/A2、gpio3 D7；与 Innohi `USB_HOST_PWREN*` / `Relay-CTL` 同 pad | [`lws-hmi-ynh960-own-gpio.dtsi`](../overlay/kernel/rockchip/lws-hmi-ynh960-own-gpio.dtsi) 从 `own-gpio-pins` 删除冲突脚与对应节点 |
| eth0 无 carrier / DMA reset 超时 | EVB **RGMII** + 错误 PHY reset/地址 | 同上 `uart5-gmac` overlay：**RMII** + `gpio4 PB3` + MDIO addr 1 |

当前 `own-gpio` **保留**的标签含：GPIO-1…8、Bell-CTL、LED_RED/BLUE 等（见该 dtsi）。**已删除**：`USB_HOST_PWREN{1,2,3}_H`、`Relay_CTL`（与以太网 pad 冲突；量产若需要这些功能，须改原理图或改 gmac 引脚方案，勿简单地加回 EVB 冲突脚）。

用户态网口名：`10-lws-hmi-gmac.link` → **`eth0`**。

---

## 4. 触控

| 项 | 值 |
|----|-----|
| IC | **Goodix GT9xx** @ `i2c1` **0x5d** |
| 分辨率 | 800×1280（Innohi `goodix,cfg-group`） |
| IRQ / RST | GPIO0_PB5 / GPIO0_PB6（与其它触摸节点共享 — **只允许一个 okay**） |
| Overlay | [`lws-hmi-ynh960-touch.dtsi`](../overlay/kernel/rockchip/lws-hmi-ynh960-touch.dtsi)：启用 Goodix；禁用 Focaltech / Sitronix |
| 验收（P2.1） | libinput 点击/滑动稳定；与屏旋转坐标一致 |

用户态：flutter-pi + libinput。旋转偏好：`/var/lib/lws-hmi/display-orientation` → `hmi-launch.sh` `-o`。

---

## 4.1 USB 物理口（ynh960）

| 路径 | 板载形态 | DT / 用途 |
|------|----------|-----------|
| **Micro-USB OTG** | 板子集成插座 | `usbdrd_dwc3` + `u2phy0_otg`，`dr_mode=otg`：**ID 接地** → host（键盘）；**ID 浮空** + PC VBUS → peripheral（**plug-ssh**） |
| **其它 USB** | **1 mm pin → 转接** | `usbhost_dwc3` + `u2phy0_host`（+ `combphy1` HS）→ **USB host / 键盘·鼠标**（与 OTG 角色独立） |
| VBUS（扩展） | `USB_HOST_PWREN{1,2,3}` | gpio4 PA0/PA1/PA2，RMII 后已从 own-gpio 恢复（默认开） |
| VBUS（OTG host） | PHY `USB_VBUS_EN`（extcon0） | 随 OTG host 角色由 `usb2phy0` 驱动 |

Overlays：`lws-hmi-ynh960-usb-gadget.dtsi`（OTG dual-role）、`lws-hmi-ynh960-usb-host.dtsi`（扩展 host）。

**外接 USB 键盘（HID）**：1 mm host，或 Micro-USB 在 **USB Debug OFF**（Demo Debug 组）时用 OTG 转接头。板上 Micro-USB **不依赖 ID 自动切角色**（转接头常不接地 ID）。**USB Debug ON**（默认，`/var/lib/lws-hmi/usb-debug`）→ plug-ssh；OFF → host/键盘。LAN Debug 默认关、不持久化。

用户态依赖（缺一 flutter-pi 会禁用按键或行为异常）见下表。

### 4.1.1 用户态踩坑（2026-07-15 真机）

内核 HID 枚举与 libinput seat 正常 ≠ Flutter 能打字。问题均在 **flutter-pi / XKB**，换键盘或换 1 mm host 口一般仍有效；**不要**靠 `kbdrate` / usbhid quirks。

| 现象 | 根因 | 固化位置 |
|------|------|----------|
| 完全打不出字 | 仅有 `libxkbcommon`，缺 `/usr/share/X11/xkb` 与 Compose | `BR2_PACKAGE_XKEYBOARD_CONFIG`；fs-overlay `usr/share/X11/locale/*` + `/etc/default/keyboard` |
| 方向键不动光标 | `text_input` 把 Left/Right 让给 Flutter，但 `on_key_event==NULL` | `flutter-pi` `0001-text-input-arrow-keys.patch` |
| 小键盘 NumLock「反了」 | 硬件 LED 亮着但 xkb Mod2 默认关（或不同步） | `0002-sync-keyboard-leds.patch`；`hmi-launch.sh` 启动前清 `input*::{num,caps,scroll}lock` |
| 长按不连发 | libinput 不合成 repeat；flutter-pi 原无定时器 | `0003-key-repeat.patch`（660 ms 后约 25 Hz，只重发 utf8/keysym） |
| `make rebuild-flutter-pi` 补丁未进包 | `SITE_METHOD=local` 跳过 Buildroot Patching | `flutter-pi.compile.mk` → `FLUTTER_PI_APPLY_PACKAGE_PATCHES` |
| USB 鼠标能动/滚但不能见指针 | Rockchip GBM cursor stride 常 pad；原逻辑要求 `stride == width*4` 直接放弃 HW cursor | `0004-cursor-stride-padded-gbm.patch` |
| 鼠标滚轮速度 / 自然滚动等 OS 设置 | flutter-pi 硬编码 wheel scale；未调 libinput config | `0005-mouse-settings-prefs.patch` + `/var/lib/lws-hmi/mouse.conf`；Demo「USB mouse」；**mtime 轮询**重载（禁止 `kill -HUP`，会直接停掉 `hmi.service`） |

Smoke（含连发 / 方向键）：

```bash
lsusb
ls -l /dev/input/by-id/*kbd* 2>/dev/null
dmesg | grep -iE 'hid|usbhost|dwc3'
test -f /usr/share/X11/xkb/rules/evdev && test -f /usr/share/X11/locale/C/Compose
# Demo「USB keyboard」：打字、←→、长按连发；有小键盘再验 NumLock 灯与数字/导航
# flutter-pi 启动日志不得出现: Could not initialize keyboard configuration
```

### 4.1.2 USB 鼠标（指针 + 设置）

与键盘同 host 路径。枚举后应有**可见指针**；偏好写入 `mouse.conf`（`natural_scroll` / `scroll_speed` / `pointer_speed` / `pointer_size` / `primary_button`），flutter-pi 启动时加载并每秒检查文件 mtime 后应用。`pointer_size` 控制光标图标密度（默认 **20**；手型/文本缺密度档时 ceil + 放大以对齐箭头）。HW 光标位置按 **display_size** 钳制（`0008`），与 `-o landscape_*` 下面板分辨率一致。**不要**对 flutter-pi 发 `SIGHUP`。

```bash
ls -l /dev/input/by-id/*mouse* 2>/dev/null
# Demo「USB mouse」：指针跟随；自然滚动 / 滚轮速度 / 指针速度 / 主按钮
# journal / flutter-pi 日志不应再刷 "unsupported framebuffer stride" 后无 cursor
cat /var/lib/lws-hmi/mouse.conf 2>/dev/null || true
```

重新编译 flutter-pi 补丁后还须进 rootfs（见 AGENTS / README Make）：`make rebuild-flutter-pi` → `apply-overlay` → `build-rootfs` → `build-img` → `flash`。

---
## 5. Overlay 索引（改引脚时先看这些）

| 文件 | 职责 |
|------|------|
| `lws-hmi-ynh960-own-gpio.dtsi` | own-gpio；恢复 USB_HOST_PWREN*（RMII 后）；三色灯默认关 |
| `lws-hmi-ynh960-usb-gadget.dtsi` | Micro-USB OTG dual-role（ID → host/peripheral；plug-ssh 仅 peripheral） |
| `lws-hmi-ynh960-usb-host.dtsi` | 1 mm USB host expansion（键盘 / 鼠标） |
| `lws-hmi-ynh960-uart5-gmac.dtsi` | eth RMII/PHY；释放 UART5 |
| `lws-hmi-ynh960-uart7-pwm.dtsi` | 禁用 uart7 → pwm14/15 |
| `lws-hmi-ynh960-touch.dtsi` | Goodix only |
| `lws-hmi-ynh960-display.dtsi` | MIPI 面板 |
| `lws-hmi-ynh960-evb-trim.dtsi` | 关掉板无件的 EVB 节点（**勿**关 fiq-debugger） |

路径均在 `overlay/kernel/rockchip/`。

---

## 6. 板端快速核对

```bash
# Modbus
ls -l /dev/ttyS5

# 三色灯节点
ls /sys/class/gpio_innohi/GPIO_{4,5,7}/value

# eth0 + PHY
ip link show eth0
dmesg | grep -E 'stmmac|own-gpio|uart5|pwm14|goodix|focal'

# 触控（应有 Goodix；不应反复 Unregister focal）
dmesg | grep -iE 'goodix|focal|sitronix'
```

期望：`own-gpio` 无 “pin already requested by …ethernet”；无 “UART5 vs gmac reset”；`pwm14`/`pwm15` 可 claim；触控为 Goodix。

---

## Changelog

| Date | Change |
|------|--------|
| 2026-07-16 | P2.1 USB 鼠标：光标可移动区按 display_size clamp（`0008`；landscape 下对齐面板分辨率） |
| 2026-07-15 | P2.1 USB 鼠标：可见指针（cursor stride pad）+ `mouse.conf` / Demo 设置；台账 §4.1.2 |
| 2026-07-15 | P2.1：Micro-USB OTG ID dual-role（`dr_mode=otg`；plug-ssh 门控 `USB-HOST=0`） |
| 2026-07-15 | P2.1 USB 键盘用户态踩坑表 §4.1.1（XKB/Compose、方向键、NumLock LED、长按连发、local-site 补丁钩子） |
| 2026-07-15 | P2.1：USB — Micro-USB OTG vs 1 mm host；恢复 PWREN；`usb-host` overlay |
| 2026-07-15 | P2.1：从联调结论固化本台账（串口 / gpio_innohi / own-gpio↔gmac / 触控） |
