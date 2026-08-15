# ek3562 I/O · 丝印 ↔ Linux / gpiod（2026-08-15）

来源：板载系统映射 + lab 核对。契约：**gpiod `chip` + `offset`**（或 `linux_gpio` 兜底）。丝印名仅文档。

## 换算（lab 枚举）

| gpiochip | sysfs base | 硬件 |
|----------|------------|------|
| `gpiochip0` | 0 | SoC `gpio0` |
| `gpiochip1` | 32 | SoC `gpio1` |
| `gpiochip2` | 64 | SoC `gpio2` |
| `gpiochip3` | 96 | SoC `gpio3` |
| `gpiochip4` | 128 | SoC `gpio4` |
| `gpiochip6` | **495** | **PCA9535** `i2c-1` `@0x20`（label `1-0020`） |

`offset = linux_gpio - base`。Rockchip 银行内：0–7=A*，8–15=B*，16–23=C*，24–31=D*。

若以后多了一颗 chip，**PCA 的 `gpiochipN` 可能不是 6** —— 用 `gpiodetect` / label `1-0020` 核对后再改 JSON。

## 端子映射

| 丝印 | linux# | gpiod chip / offset | 物理节点 |
|------|--------|---------------------|----------|
| **OUT0** | 495 | `gpiochip6` / **0** | PCA9535 P0 (`&pca9535 0`) |
| **OUT1** | 496 | `gpiochip6` / **1** | PCA9535 P1 |
| **OUT2** | 497 | `gpiochip6` / **2** | PCA9535 P2 |
| **OUT3** | 498 | `gpiochip6` / **3** | PCA9535 P3 |
| **IN0** | 113 | `gpiochip3` / **17** | SoC **GPIO3_PC1** |
| **IN1** | 110 | `gpiochip3` / **14** | SoC **GPIO3_PB6** |
| **IN2** | 50 | `gpiochip1` / **18** | SoC **GPIO1_PC2** |
| **IN3** | 51 | `gpiochip1` / **19** | SoC **GPIO1_PC3** |

- OUT* 在扩展器；IN* 在 SoC，**不是** PCA 的 4–15 脚。  
- 丝印上未必印出 IN3/OUT3，但系统已占用对应线。

## HAL / App

| 用途 | 配置 |
|------|------|
| Status LED 红/黄/绿 | `OUT0/1/2` → `assets/hal/gpio.ek3562.json` `chassis_rgb` |
| 第 4 路输出 | `OUT3` → 同文件 `aux_out3` |
| 数字输入 | `IN0`–`IN3` → `type: button`（读电平；极性待产品确认） |
| 选型 | `board_id=ek3562` → `HmiHalAssets.gpioForBoard` |
| Modbus RTU | `/dev/ttyS4`（`uart4`）via App `modbus.json` → `transport.device_by_board.ek3562` |

JSON 片段形状：

```json
"gpiod": { "chip": "gpiochip6", "offset": 0 },
"linux_gpio": 495,
"label": "OUT0"
```

## DT

`overlay/kernel/rockchip/ek3562-io.dtsi`：`&pca9535` / `&gpio1` / `&gpio3` 的 `gpio-line-names`。  
**不要**对上述脚 `gpio-hog` / `gpio-leds`（会 EBUSY）。

## 手工烟测

```sh
# OUT0
gpioset -m time -s 500ms gpiochip6 0=1
# IN0
gpioget gpiochip3 17
```

无 libgpiod 时：sysfs `export` linux#（OUT 495…，IN 113…）。
