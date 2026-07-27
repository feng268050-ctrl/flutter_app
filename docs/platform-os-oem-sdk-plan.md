# 统一嵌入式 OS：OEM · 通用 boot/rootfs · 自有 linux-sdk · P3.2 虚拟机

目标：把 **lws-hmi** 从「ynh960 单机产品工程 + 供应商 SDK 补丁机」演进为 **统一的嵌入式 OS 平台**：

- **boot + rootfs** = 可 A/B 升级的轻量通用 OS；
- **oem** = 可组合的 **主板 × 屏幕** 硬件包（单槽，可独立刷写）；
- **`app/`** = 唯一产品 UI 轴（当前 `app/lws_hmi`；未来可并列其它产品 App）；
- **自有 `linux-sdk`** = 进仓、可裁剪的瑞芯微 platform 树；供应商包仅为蓝本；
- **工厂整包** = 按环境变量选择 **U-Boot 变体 + OEM 变体**，产出分目录的 **`factory.img`**（取代今日口语中的单一 `update.img`）；
- **P3.2 UTM 虚拟机** = 第二块「主板 + 屏幕」，验证多板多屏契约（**不是** Rockchip SoC 仿真）。

配套阅读：

| 文档 | 关系 |
|------|------|
| [`flutter-linux-hmi-plan.md`](flutter-linux-hmi-plan.md) | 主线阶段；本文件展开 P3.2 与平台化 |
| [`hal-portability.md`](hal-portability.md) | HAL / BoardProfile 合同 |
| [`storage-layout.md`](storage-layout.md) | GPT：`oem` / `boot*` / `rootfs_*` / `userdata` |
| [`embedder-migration-plan.md`](embedder-migration-plan.md) | Weston + eLinux（设备与模拟器同嵌入器） |
| [`factory-test-app-plan.md`](factory-test-app-plan.md) | **本计划范围外**；产测 App 另案推进 |

状态图例：✅ 已具备基础 · 🔲 本计划待做 · ⏸ 明确不做 / 另案

---

## 1. 背景与结论

### 1.1 现状（摘要）

| 层 | 现状 |
|----|------|
| HAL | P3.1 ✅：`BoardProfile` + `BoardBindings`；合同见 `hal-portability.md` |
| 板级 JSON | `app/lws_hmi/assets/hal/{board_profile,gpio,modbus}.json` 绑在 App assets |
| 屏参 | `board/*.txt` → rootfs → **private1** + Innohi `ParamUpdate` |
| 板脚本 | rootfs-overlay `/usr/libexec/...`，大量 `ynh960-*` |
| GPT `oem` | ~128 MiB，已挂载 `/oem`；`upgrade` 可选写 `oem.img`；**内容几乎空** |
| `linux-sdk/` | gitignore；~18 G 全能树（debian/ubuntu/yocto/全量 mali/toolkit…） |
| 定制方式 | `overlay/**` + `apply-overlay` 打进供应商 SDK |
| P3.2 | 🔲 未开始；规划 UTM + Weston + eLinux + HAL |

### 1.2 结论（本计划采纳）

1. **OEM 只承载硬件 SKU 组合（board × screen）**：profile 能力/网口/helpers、板端 bringup 脚本、屏参与旋转/splash 契约、OEM manifest；**v1 另含 `product.ini` 出厂种子**（长期归属另议）。  
2. **`gpio.json` / `modbus.json` 是产品 App 资产**，继续跟 `app/lws_hmi`（或未来产品 App）走，**不进 OEM**、也不以「主板目录」为权威源。同一主板可服务不同产品寄存器图。  
3. **boot/rootfs 趋向通用**：板/屏差异尽量退出 rootfs；内核仍按 SoC/板选 FIT（DT 不能完全进 OEM）。  
4. **自有 `linux-sdk/` 进仓**（保留此名）：只留 Buildroot + 必要 kernel/device/external/tools；debian/ubuntu/yocto 等删除；overlay 差异逐步内化；蓝本外置参考。  
5. **P3.2 = 第二个 board×screen pack**（`sim` + `virt` 屏），用 **Apple Silicon 上 aarch64 UTM** 验证组合与装配器；启动用 UEFI/QEMU virt，**不用** Rockchip `uboot.img`；**不做** x86_64 host 路径。  
6. **Factory Test App**：⏸ **本计划不做**（见另文）；产测若复用 OEM profile，届时再对齐加载路径。  
7. **工厂制品按变体分目录 + 环境变量选择**：不同供应商/板级的 `uboot.img`（及配套 loader）分库存放；`build-oem` / `build-img` / `flash` 用同一套 `FACTORY_SKU`（可覆盖 `UBOOT_ID` / `OEM_ID`）解析路径；整包输出改称 **`factory.img`**（见 §5.6）。

### 1.3 非目标

- 不在 UTM 内仿真 RK356x SoC / Mali / MIPI / AIC 模组。  
- 不强制第一天自编译量产 U-Boot（默认继续已验证的瑞芯微/板级 `uboot.img`；源码用 `rockchip-linux/u-boot` 备查）。  
- 不把 `/opt/hmi` 迁入 OEM（App 仍走 rootfs A/B + `push-app`）。  
- 不在本计划实现 `app/factory_test`。  
- 不一次合入完整 18 G 供应商树进 git。  
- 不做 x86_64 host 模拟器路径（开发机均为 Apple Silicon；P3.2 仅 aarch64 UTM）。

---

## 2. 目标架构

```text
┌─────────────────────────────────────────────────────────────────┐
│  app/lws_hmi  (+ 未来 app/<product>)                            │
│  UI · CyberUI · CyberIME                                        │
│  assets/hal/gpio.json · modbus.json   ← 产品专属，不进 OEM      │
│  加载：OEM board_profile + App gpio/modbus                      │
├─────────────────────────────────────────────────────────────────┤
│  packages/cyber_hal · cyber_ui · cyber_ime                      │
├─────────────────────────────────────────────────────────────────┤
│  /oem  （PARTLABEL=oem，单槽 ~128 MiB）                          │
│  manifest · boards/<id>/ · screens/<id>/ · helpers              │
├─────────────────────────────────────────────────────────────────┤
│  rootfs_a|b  通用 OS：systemd · networkd · Weston · eLinux ·    │
│              HAL 运行时 · /opt/hmi · 装配器（读 /oem）            │
│  boot|boot_b  SoC 族内核 FIT + 该板 DT（A/B）                    │
├─────────────────────────────────────────────────────────────────┤
│  userdata    偏好 / 模型 / OTA 暂存（非 SKU 定义）                │
├─────────────────────────────────────────────────────────────────┤
│  自有 linux-sdk（进仓）← 蓝本 import；差异直接改树               │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 两根轴

| 轴 | 变化物 | 不变物 |
|----|--------|--------|
| **硬件 SKU** | OEM：`board_id` × `screen_id` | 同一 OS 版本（boot+rootfs）尽量共用 |
| **产品 App** | `app/<name>` + gpio/modbus | 同一 HAL 合同 + 同一 OEM profile |

### 2.2 分区职责（强化）

| 分区 | 职责 | A/B | 升级 |
|------|------|-----|------|
| `boot` / `boot_b` | 内核 FIT + DT | 是 | `make upgrade` 写非活动字母 |
| `rootfs_a` / `rootfs_b` | 通用 userspace + App bundle | 是 | 同上 |
| **`oem`** | board×screen 组合 | **否** | 可选 `oem.img`；工厂常刷；字段慎更 |
| `userdata` | 运行时状态 | 否 | **禁止**被 upgrade 擦除 |
| `private1` | 过渡期屏参；长期由 screen pack 替代 | 否 | 迁完后可读降级/废弃 |

---

## 3. OEM 设计

### 3.1 设计原则

1. **编译期/工厂选定组合**，不做任意主板运行时自动探测（与既有 `board-screen-pack` 规格一致）。  
2. **OEM 无 A/B**：坏包或刷错 SKU → 装配器失败进入安全策略（见 §3.6），不静默加载错板 profile。  
3. **Profile 在 OEM；产品目录在 App**：`BoardProfile.configs.gpio/modbus` 继续指向 App assets（如 `assets/hal/gpio.json`），或由 App 在构造 HAL 时显式注入路径——**权威源永不在 `/oem`**。  
4. **Helpers 脚本可住在 OEM**，由 profile 用绝对路径引用（如 `/oem/boards/ynh960/helpers/wifibt-bringup.sh`）；rootfs 只保留**可移植默认**（`hal-portability.md`）。

### 3.2 仓库布局（源码）

```text
oem/                              # 新建：OEM 包源（打进 oem.img）
  manifest.schema.json            # 可选：JSON Schema
  packs/
    ynh960+panel-800x1280/        # 一种出厂组合（或由组装脚本生成）
      manifest.json
    sim+virt/                     # P3.2
      manifest.json
  boards/
    ynh960/
      board_profile.json          # 无 configs.gpio/modbus，或仅占位说明
      helpers/                    # bringup、OTG 策略等
      usb-otg.ini                 # 可选
      product.ini                 # v1：出厂身份/调参种子（见 §3.5）；未来归属另议
    sim/
      board_profile.json
      helpers/                    # 可空
      product.ini                 # 可选；模拟器可用占位
  screens/
    panel-ynh960-800x1280/
      screen.json                 # 旋转默认、分辨率契约、splash
      lcd/                        # 替代/迁移 private1 参数表
    virt/
      screen.json                 # UTM 虚拟显示
```

真机当前组合可由构建选择：

```bash
OEM_PACK=ynh960+panel-800x1280 make build-oem
```

### 3.3 `manifest.json`（组合声明）

```json
{
  "schema_version": 1,
  "pack_id": "ynh960+panel-800x1280",
  "board_id": "ynh960",
  "screen_id": "panel-ynh960-800x1280",
  "board_path": "boards/ynh960",
  "screen_path": "screens/panel-ynh960-800x1280",
  "compat": {
    "os_min": "1.0.0",
    "soc_family": "rk356x"
  }
}
```

设备上权威路径建议：

```text
/oem/manifest.json                 # 当前激活组合（或 /oem/active → packs/...）
/oem/boards/<board_id>/...
/oem/screens/<screen_id>/...
```

### 3.4 `board_profile.json`（OEM）与 App 的分工

| 字段 | 所有者 | 说明 |
|------|--------|------|
| `board_id` / `capabilities` / `net_roles` / `route_metrics` / `helpers` / `storage_mounts` | **OEM board** | 硬件能力与接线 |
| `configs.gpio` / `configs.modbus` | **产品 App** | 不写进 OEM profile；App 加载 OEM profile 后**合并**自身 asset 路径 |
| 屏相关默认（旋转、逻辑分辨率） | **OEM screen** | `screen.json`；`hmi-launch` / Weston 变换消费 |
| `product.ini`（brand/model/sn/camera_ip…） | **OEM board（v1）** | 先按现状把出厂身份/调参放进 OEM；运行时仍可由 compose 落到 HAL 既有路径（见 §3.5）。**未来归属另有打算，本计划不锁死长期模型** |

App 启动伪代码：

```text
profile = BoardProfile.loadFile("/oem/boards/<id>/board_profile.json")
     或  经装配器导出的 /run/hmi/board_profile.json
profile = profile.withProductConfigs(
  gpio: "assets/hal/gpio.json",
  modbus: "assets/hal/modbus.json",
)
AppServices(boardProfile: profile) …
```

需在 `cyber_hal` 补齐：`loadFile`、相对 OEM 根解析 helpers、以及 **withProductConfigs / 合并** API（若尚无）。`loadAsset` 保留给单测与无 OEM 的 host。

### 3.5 `product.ini`（v1 进 OEM）

**拍板：** v1 将 `product.ini`（及与之同类的出厂键，如 `camera_ip`）**放入 OEM board 包**，不再以「仅 userdata」为唯一种子源；与今日「profile helpers / 出厂写入」的现状对齐，便于随 SKU 刷 OEM 带出默认值。

建议行为（实施时可微调，不阻塞）：

```text
/oem/boards/<board_id>/product.ini     # 出厂种子（随 oem.img）
        │
        ▼  oem-compose / 首启
/var/lib/hal/product.ini               # HAL 既有读取路径（→ userdata 绑定若仍需要）
        │
        ▼  字段升级 OEM 时
策略：不覆盖操作员已改的非空键（或整文件仅在缺失时拷贝）— 细节实现时定
```

- `make set-prop` / 运行时修改：仍写 HAL 运行时路径（userdata），**不**要求回写 OEM。  
- 长期：产品方另有打算；届时再拆「SKU 默认 vs 单机身份」，本文不预先设计第二套模型。  
- OEM profile 里的 `helpers.camera_ip` 等：迁移期可与 `product.ini` 双读；收敛后以 `product.ini` 为准。

### 3.6 `screen.json`（屏幕包）

最低字段（可演进）：

| 键 | 用途 |
|----|------|
| `display_name` | 人读 |
| `width` / `height` | 逻辑像素契约（UI/文档） |
| `default_orientation` | `landscape_left` 等 → `hmi-launch` / Weston |
| `lcd_param_files` | 相对 screen 目录的参数表（迁移期） |
| `splash` | 尺寸/路径约定（与 `board/logo` 策略对齐） |
| `touch_notes` | 文档性；驱动仍在 DT/kernel |

**Headless / sim**：可无 LCD 文件；`capabilities` 可不含 backlight。

### 3.7 装配器（rootfs 内）

早启（在 HMI 前）服务，例如 `oem-compose.service`：

1. 确保 `PARTLABEL=oem` → `/oem`（已有 display-init 可拆出通用 mount）。  
2. 读 `/oem/manifest.json`；校验 `board_path` / `screen_path` 存在。  
3. 导出环境或生成：  
   - `/run/hmi/oem.env`（`BOARD_ID` `SCREEN_ID` `OEM_BOARD_ROOT` …）  
   - `/run/hmi/board_profile.json`（可选：已解析的副本）  
   - `/run/hmi/screen.env`（旋转等）  
   - 按 §3.5 处理 `product.ini` 种子 → HAL 运行时路径  
4. 失败策略（v1）：记 journal + 不启动完整 HMI，或启动最小错误页；**禁止**回落到另一块板的 profile。

过渡期允许：OEM 缺失时 fallback 到 rootfs 内嵌的 ynh960 默认（仅迁移窗口；有明确 deprecation）。

### 3.8 构建与刷写

| 产物 | 命令（拟） | 说明 |
|------|------------|------|
| `oem.img`（**ext4**） | `FACTORY_SKU=… make build-oem` | 输出到该 SKU 目录（与 U-Boot 同套解析逻辑，见 §5.6） |
| `factory.img` | `FACTORY_SKU=… make build-img` | 打包时按 SKU **导入对应 uboot + oem**；取代单一 `update.img` 心智 |
| 工厂刷写 | `FACTORY_SKU=… make flash` | 刷入该 SKU 目录下的 `factory.img`（可用 `IMAGE=` 覆盖） |
| 字段升级 | `make upgrade`；OEM 调试用 `make upgrade OEM_ONLY=1`；`OEM_IMG=` 可选覆盖路径 | A/B 流式（OEM_ONLY 仅写 oem）；**不**等同 `flash` |

`scripts/verify-rootfs-overlay.sh` 增加：装配器单元存在；可选校验 staging 的 oem 内容（若 build 流水线生成）。

### 3.9 从现状迁移（OEM）

| 步骤 | 内容 |
|------|------|
| O1 | 定义 manifest / screen.json schema；`oem/boards/ynh960` 从现 App `board_profile.json` **剥掉** gpio/modbus 指针后迁入；**迁入 `product.ini` 种子**（含今日 `camera_ip` 等） |
| O2 | App 改为「OEM profile + 本地 gpio/modbus」；单测用 fixture |
| O3 | 板脚本：modem / OTG 等从 rootfs 迁到 `oem/boards/.../helpers`，profile helpers 改路径 |
| O4 | 屏参：双读（private1 **或** screen pack）→ 仅 screen pack |
| O5 | `make build-oem`（ext4）+ flash/upgrade 路径打通；清空迁移 fallback |

---

## 4. 通用 kernel（boot）与 rootfs

### 4.1 原则

```text
boot FIT     = SoC 族内核 + 该主板 DT（或 DTBO 列表）
rootfs       = 与具体屏/WiFi 模组脚本无关的 userspace
oem          = 模组 bringup、屏参、HAL profile、v1 product.ini
```

**DT/内核不能完全塞进 OEM**：U-Boot 先于 OEM 挂载；错 DT 可能无法亮屏。OEM 只选「哪份已进 FIT 的板配置」在运行时声明身份。

### 4.2 Kernel / boot 优化方向

| 项 | 做法 |
|----|------|
| 一族多板 | 同一 kernel config；每板一份 DTS/DTSI（现 `overlay/kernel/rockchip/ynh960-*.dtsi` → 迁入自有 SDK `device`/`kernel` 树） |
| 换屏 | 优先 screen pack + 用户态 ParamUpdate/替代方案；若必须改 panel-timing DT，则 **新 FIT**（属 OS 版本），不是只刷 OEM |
| 裁剪 | 保持现有 `ynh960-kernel-trim` 思路；按 SoC 族维护一份 trim，避免 EVB 驱动膨胀 |
| U-Boot | 量产继续预编译瑞芯微/板级 `uboot.img`；源码树 `rockchip-linux/u-boot` 进自有 SDK 备查；**非** Innohi 源码依赖 |
| 模拟器 | 不使用板级 FIT；见 §6 |

### 4.3 Rootfs 优化方向

| 迁出 rootfs | 留在 rootfs |
|-------------|-------------|
| 板专属 bringup 脚本（→ OEM helpers） | systemd、networkd、wpa `-u`、BlueZ、Weston、eLinux |
| 板专属 `board_profile` | `/usr/libexec/hmi/oem-compose.sh`、通用 `hmi-launch.sh`（读 `/run/hmi`） |
| 屏参种子（→ screen pack） | Flutter engine、共享库、Mali **运行时**（SoC 族）、`/opt/hmi` |
| Innohi 演示 / 无用 unit | `cyber_hal` 可移植默认路径 |

瘦身验收：

- 同一 `rootfs.img` + 两份不同 `oem.img`（ynh960 vs 未来板）在能力声明上可区分；  
- 或：同一 rootfs 在 UTM（sim OEM）与真机（ynh960 OEM）上都能过「装配器 + HMI 启动」契约（硬件缺失则 capability 关闭，不崩溃）。

### 4.4 与 A/B 的关系

- **OS 版本** = 一对 `boot_*` + `rootfs_*`。  
- **SKU** = `oem`。  
- 日常 UI 迭代：仍 `make build-app` + `make push-app`。  
- 换屏工厂线：主要刷 OEM（若 DT 不变）；DT 变则走 OS upgrade。

---

## 5. 自有 linux-sdk

### 5.1 定位

| 旧 | 新 |
|----|----|
| 不可变供应商树 + git 内 overlay | **我们维护的 platform 源码树**（进仓） |
| `apply-overlay` 每次打补丁 | 差异**直接改树**；蓝本仅 import 原料 |
| ~18 G 全能 SDK | 白名单裁剪后约 **~3 G 源码**（+ 可选 `dl`/工具链缓存） |

供应商（Innohi/Rockchip）原包 → 移到仓库外 **`vendor-blueprints/`**（或独立制品库）仅供 diff/import，**不参与日常构建**。

### 5.2 建议进仓内容（白名单）

```text
linux-sdk/                    # 保留此名（进仓后的自有 platform 树仍叫 linux-sdk）
  buildroot/                  # 源码；dl/ → gitignore
  kernel/                     # rk356x 所用 6.1 树（可 submodule）
  u-boot/                     # rockchip-linux 源码（编译可选）
  rkbin/
  device/rockchip/rk3566_rk3568/ + 瘦身 common/
  external/                   # 白名单，见下
  tools/linux/                # upgrade_tool、pack 等必要项
  build.sh / 精简后的编排脚本
```

**external 白名单（示例）**：

- Mali：仅 aarch64 所需 `*-wayland-gbm` 变体（约数十 M，而非全量 1.8 G）  
- `rkwifibt`（或迁 `prebuilt/`）  
- `mpp` / `linux-rga` / `gstreamer-rockchip` / `alsa-config`  
- `rknpu2/runtime`（**不要** examples/doc/toolkit2）  

**明确删除**：`debian/` `ubuntu/` `yocto/`、臃肿 `docs/`、`app/` 演示、`tools/windows`、PinDebug、全量 libmali、rknn-toolkit2、camera_engine（若产品不用）等。

体积预期见会话评估：源码约 **2.5–3.5 G**；加 `buildroot/dl` + 可选 `prebuilts/gcc` 约 **5–6 G** 开发机占用。

### 5.3 Import 纪律

1. 记录蓝本版本（commit / 包名 / 日期）于 `linux-sdk/VENDOR_IMPORT.md`。  
2. 新蓝本合入：`import` 分支 → 审 diff → 合入主树；禁止「整包覆盖后无法审」。  
3. 日常功能改动：**只改自有树**，不再往 `overlay/kernel` 无限加补丁（迁移期：旧 overlay **只删不增**）。  
4. 大二进制（Mali so、firmware）：优先 **Git LFS** 或 `prebuilt/` + 校验和，避免涨爆主历史。

### 5.4 与现有 `overlay/` 的过渡

```text
阶段 S0  文档 + 白名单清单 + 体积门禁脚本（du / 禁止目录）
阶段 S1  生成「裁剪 SDK」可构建（仍可出 ynh960 rootfs）
阶段 S2  将 overlay 中已稳定补丁 squash 进 linux-sdk；CI 用自有树
阶段 S3  overlay 仅留「产品/OEM 注入」或清空；apply-overlay 缩成薄封装
阶段 S4  gitignore 调整：linux-sdk 源码可提交；output/dl 仍忽略
```

### 5.5 U-Boot 策略（写入 SDK 规范）

- **默认**：刷写已验证的板级/供应商预编译 `uboot.img`（与现网一致）。  
- **源码**：`rockchip-linux/u-boot`（如 `next-dev`）进自有 SDK，供查阅与未来自建。  
- **多供应商**：预编译二进制 **分目录存放**，由环境变量选中（§5.6）；**不要**互相覆盖同一个 `output/firmware/uboot.img` 后靠记忆区分。  
- **禁止**：未经验收用自建 U-Boot 替换量产；改 GPT/`boot` 名等须单独项目。  

### 5.6 工厂变体：U-Boot · OEM · `factory.img`（环境变量选择）

**拍板方向：** 不同供应商/板级的 bootloader、不同 OEM 组合，都按 **变体 ID 分目录** 存放；`build-oem` / `build-img` / `flash` 用 **同一套环境变量解析逻辑** 选输入、写输出。工厂整包文件名定为 **`factory.img`**（今日 `update.img` 在迁移期可保留兼容名或 symlink）。

这与「一 SKU 一 oem.img」（模型 1）天然一致；若将来做「一份大 oem + 写 hw_sku」（模型 2），仍可用同一 `FACTORY_SKU` 只是 `OEM_PACK` 指向多 pack 镜像。

#### 5.6.1 目录约定（示意）

```text
prebuilt/bootloader/<uboot_id>/
  uboot.img
  MiniLoaderAll.bin          # 若该变体需要；与 uboot 成对
  README.md                  # 供应商、用途、验收记录

oem/out/<oem_id>/            # 或 output/oem/<oem_id>/
  oem.img                    # make build-oem 产物（ext4）

output/firmware/<factory_sku>/
  factory.img                # make build-img 产物（整包）
  oem.img                    # 可选：打进整包时的副本，便于单刷 OEM
  uboot.img / MiniLoader…    # 可选：打进整包时用的副本（审计用）
  manifest.txt               # 记录本次解析到的 uboot_id / oem_id / git rev
```

`<uboot_id>` 例：`rockchip-ynh960`、`vendorB-rk3568-evb`。  
`<oem_id>` 例：`ynh960+panel-800x1280`、`sim+virt`（与 §3 pack_id 对齐）。  
`<factory_sku>` 例：`ynh960-p800`——工厂扫码/料号用的短名，可映射到一对 `(uboot_id, oem_id)`。

#### 5.6.2 环境变量（同一解析器）

推荐 **一个主键 + 可覆盖细项**（名称实施时可微调，语义固定）：

| 变量 | 作用 |
|------|------|
| `FACTORY_SKU` | 主键。查表得到默认 `UBOOT_ID`、`OEM_ID`、输出子目录名 |
| `UBOOT_ID` | 覆盖 bootloader 目录（`prebuilt/bootloader/$UBOOT_ID/`） |
| `OEM_ID` | 覆盖 OEM 包 / `build-oem` 输出键（与 pack_id 一致） |
| `IMAGE` | 仅 `flash`：显式指定 `factory.img` 路径（已有习惯，保留） |

SKU 表（仓库内，例 `board/factory-skus.tsv` 或 `board/skus/*.env`）：

```text
# sku              uboot_id              oem_id
ynh960-p800        rockchip-ynh960       ynh960+panel-800x1280
ynh960-p1024       rockchip-ynh960       ynh960+panel-1024x600
vendorB-panelA     vendorB-rk3568        boardB+panelA
```

解析伪代码（`build-oem` / `build-img` / `flash` **共用**）：

```text
sku = FACTORY_SKU or default(ynh960-p800)
(uboot_id, oem_id) = lookup(sku)
uboot_id = UBOOT_ID or uboot_id
oem_id   = OEM_ID or oem_id
uboot_dir = prebuilt/bootloader/$uboot_id
oem_img   = oem/out/$oem_id/oem.img          # build-oem 写入处
out_dir   = output/firmware/$sku
factory   = $out_dir/factory.img
```

缺目录或缺文件 → **失败**，禁止静默回落到「上一次构建留下的 uboot」。

#### 5.6.3 各 target 行为

```text
FACTORY_SKU=ynh960-p800 make build-oem
  → 按 OEM_ID 组装 oem/packs/… → 写 oem/out/ynh960+panel-800x1280/oem.img

FACTORY_SKU=ynh960-p800 make build-img
  → 读 uboot_dir 的 uboot.img (+ loader)
  → 读对应 oem.img（若尚未 build-oem 则报错或依赖顺序）
  → 与现有 boot.img / rootfs.img 打包
  → 写 output/firmware/ynh960-p800/factory.img
  → 写 manifest.txt（uboot_id、oem_id、校验和）

FACTORY_SKU=ynh960-p800 make flash
  → 默认 IMAGE=output/firmware/ynh960-p800/factory.img
  → RockUSB uf 该文件（loader 行为与现 flash 一致）
```

`make upgrade`（A/B）**不**走 `factory.img`；继续流式 `boot_*` + `rootfs_*`（+ 可选单独 `oem.img`）。工厂 MaskROM / 整盘与日常 OTA 心智分离。

#### 5.6.4 与「要不要多个 oem.img」的关系

- **要**：至少按 `OEM_ID` 产出到 **不同目录**（你提的加载逻辑）。  
- 是否「一 SKU 一份 oem」：由 SKU 表决定——一 SKU 映射一个 `oem_id` 即模型 1；多个 SKU 可共用同一 `uboot_id`、不同 `oem_id`（同 U-Boot、不同屏包）。  
- 不同供应商 U-Boot：只加 `prebuilt/bootloader/<uboot_id>/`，SKU 表改一行，不必改打包脚本分支。

#### 5.6.5 迁移注意

| 今日 | 目标 |
|------|------|
| `output/firmware/update.img` | `output/firmware/<sku>/factory.img` |
| 隐式 SDK/`rockdev` 里的单个 `uboot.img` | `prebuilt/bootloader/<uboot_id>/uboot.img` |
| `IMAGE=` 指 update.img | `IMAGE=` 指 factory.img；或只设 `FACTORY_SKU` |
| 文档 / AGENTS / `make help` | 全面改称 factory；过渡期 `update.img` → symlink 到默认 sku 的 factory.img |

---

## 6. P3.2 虚拟机 = 第二块主板 + 屏幕

### 6.1 定位

| 是 | 不是 |
|----|------|
| **Apple Silicon 上 aarch64 UTM** 通用 Linux 访客 | Rockchip SoC 仿真 |
| 与量产相同的 **Weston + flutter-embedded-linux + cyber_hal** | 真机 FIT + Rockchip U-Boot |
| OEM pack：`board_id=sim` + `screen_id=virt` | ynh960 DT / Mali / AIC |
| | **x86_64 host 路径**（无此需求；开发机均为 Apple Silicon） |

Apple Silicon 上 UTM：HVF 虚拟化 + 通常 **EDK2 UEFI** 启动（或 QEMU `virt` U-Boot）；与板级 `uboot.img` 无关。P3.2 **只做 aarch64**。

### 6.2 架构对照

```text
真机 ynh960                         P3.2 UTM
─────────────────────               ─────────────────────
Rockchip uboot.img                  EDK2 / virt 启动
kernel FIT + RK DT                  virt 内核 + virtio
/oem boards/ynh960 + screen         /oem boards/sim + screens/virt
                                    （或 host 目录 bind 模拟 /oem）
BoardBindings Linux*                Stub* 与/或有限 Linux（virtio 网）
gpio/modbus = App assets            同 App；无 UART 则 capability 关闭
                                    可选：USB/串口透传真 Modbus
```

### 6.3 sim board pack

基于现有 `packages/cyber_hal/boards/sim.json` 升级为正式 OEM board：

- capabilities：按迭代逐步增加（初期 backlight/volume/sysInfo/datetime；网/BT 可后加或 Stub）。  
- **无** gpio/modbus capability **或** 有 capability 但仅当 App 配置且设备存在时启用。  
- helpers：空或指向 no-op；遵守「缺省不碰 ynh960 libexec」。

App：`resolveHalBackend(boardId: sim)` → Stub；并支持 `HAL_BACKEND=stub`。  
`AppServices` 需按 backend 接线（今日默认 Linux，属本阶段缺口）。

### 6.4 virt screen pack

- `screen.json`：逻辑分辨率（如 1280×800）、默认 landscape、无 lcd_param。  
- Weston 输出：virtio-gpu / 帧缓冲；与真机同样 `desktop-shell` + splash 策略可简化。

### 6.5 镜像与开发路径（建议分两级）

**路径 A — 快迭代（优先）**

- **aarch64 UTM** 内跑：Debian/Ubuntu aarch64（或等价）+ 手装 Weston + 推送 Flutter bundle。  
- `/oem` 用目录树或 loop 挂载 **ext4** `oem.img`。  
- 验证：装配器、profile 合并、UI、Stub HAL、可选 Modbus 透传。  
- 不在 macOS host 本机直接当「模拟器验收」（无 x86_64 路径；Apple Silicon 上以 UTM aarch64 为准）。

**路径 B — 契约对齐（随后）**

- 用**裁剪后的自有 Buildroot** 打一份 `virt` / `qemu_aarch64` 根文件系统（或复用大量 lws_hmi 包、换 machine）。  
- 目标：与真机同一套 package 集合与单元名，差异仅在 OEM + 内核机型。

### 6.6 下位机通讯

- 默认：无 Modbus capability → 产品页降级。  
- 增强：UTM 转发 USB-serial / 命名管道 → 真控制板；App 仍用 **同一** `assets/hal/modbus.json`。

### 6.7 验收（P3.2）

1. 文档化：`make` 或脚本一键说明如何启动 UTM / 挂载 OEM。  
2. 同一 `app/lws_hmi` 在真机（ynh960 OEM）与模拟器（sim OEM）可构建；启动不因缺硬件崩溃。  
3. 装配器对两套 manifest 均成功；错 manifest 失败可见。  
4. UI 主路径可点；Modbus 在透传配置下可读（可选门禁）。  
5. **不**要求模拟器帧率或 GPU 与真机一致。

### 6.8 与主线阶段关系

本文件将 **P3.2** 从「仅有模拟器」扩展为 **「模拟器 + OEM 组合验证」**。实施顺序建议：§7 中 **W1 → W2 与 W4 可部分并行**；完整自有 SDK（W3）可与 P3.2 重叠，但 P3.2 验收不阻塞在 SDK 全量进仓完成之后。

---

## 7. 工作包与建议顺序

```text
W0  契约冻结（本文 + 必要时 OpenSpec）
    ├─ OEM manifest / screen schema
    ├─ gpio/modbus 归属 App（否决进 OEM）
    └─ UTM ≠ SoC 仿真

W1  OEM 垂直切片（真机 ynh960）
    ├─ oem/ 源码树 + board_profile 迁出 App（保留 gpio/modbus 在 App）
    ├─ HAL loadFile + 产品 configs 合并
    ├─ oem-compose + /run/hmi
    ├─ make build-oem；upgrade/flash 带 oem.img
    └─ 迁移期 fallback

W2  Rootfs/脚本瘦身
    ├─ helpers → OEM
    ├─ hmi-launch 只读 /run/hmi
    └─ private1 双读 → screen pack

W3  自有 linux-sdk
    ├─ 裁剪构建可复现 ynh960 镜像
    ├─ 白名单门禁；VENDOR_IMPORT.md
    ├─ overlay 冻结/内化
    └─ git 策略（源码进仓 / LFS / dl ignore）

W4  P3.2 虚拟机（第二主板+屏）
    ├─ oem pack sim+virt
    ├─ AppServices Stub 接线
    ├─ 路径 A 文档 + 脚本
    └─ 可选路径 B Buildroot virt

W5  （另案）Factory Test App
    └─ 复用 OEM profile；gpio/modbus 仍按产测需求另定
```

依赖关系：

```text
W0 → W1 → W2
       ↘ W4（可用 W1 的 compose 契约；先路径 A）
W0 → W3（可与 W1/W4 并行，但 W3 完成前仍可用现 linux-sdk）
```

---

## 8. 对既有文档的影响

| 文档 | 影响 |
|------|------|
| `flutter-linux-hmi-plan.md` | P3.2 条目指向本文；强调 OEM 第二 pack |
| `hal-portability.md` | 补充：profile 来自 OEM；gpio/modbus 来自 App |
| `storage-layout.md` | `/oem` 从「optional drop-ins」升级为 SKU 权威 |
| `factory-test-app-plan.md` | **暂不实施**；其中「三份 JSON 进 rootfs `/usr/share/cyber_hal`」与本文冲突——产测启动时改为：**OEM profile + 各自 App 目录**；勿再把 gpio/modbus 塞进主板 pack |
| `openspec/.../board-screen-pack` | 运行时落点改为 OEM；产品 catalogs 归属与本文一致 |

---

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| OEM 单槽刷坏 | compose 失败可见；工厂校验 manifest；关键升级默认不写 OEM |
| 错 uboot / 错 oem 打进整包 | §5.6：分目录 + SKU 表 + 缺文件失败；`factory` 旁写 `manifest.txt` |
| 早启亮屏仍依赖 private1/Innohi | 迁移期双读；换屏 DT 变更走 boot 升级 |
| SDK 进仓历史膨胀 | 白名单 + LFS/prebuilt；禁 commit `output/`/`dl/` |
| 模拟器与真机差过大 | 契约对齐（单元名、路径、Weston）；不追求 GPU 奇偶 |
| App 合并 profile 出错 | 单测：OEM fixture + App gpio/modbus；错 board_id 拒绝启动 |
| 与 factory-test 旧设计漂移 | 本文为平台权威；产测另案必须 rebase 到 OEM |
| `update.img` 改名摩擦 | 过渡期 symlink；README/AGENTS/`make help` 同步改 `factory.img` |

---

## 10. 成功标准（平台化第一里程碑）

1. **真机**：`oem.img`（ynh960+屏）+ 通用 rootfs 启动；HMI 使用 OEM profile + **App 内** gpio/modbus。  
2. **模拟器**：sim+virt OEM 启动同一 HMI；缺硬件不崩；可作为「第二主板+屏」演示组合切换。  
3. **构建**：裁剪 linux-sdk 可出与现网等价的 ynh960 镜像（或明确差距清单）。  
4. **工厂变体**：`FACTORY_SKU=… make build-oem` / `build-img` / `flash` 解析同一套路径；产出 `output/firmware/<sku>/factory.img`；uboot 来自 `prebuilt/bootloader/<uboot_id>/`。  
5. **文档**：`make help` / README / AGENTS 重建表含 `build-oem`、`factory.img`、模拟器步骤；**无** factory-test 强依赖。

---

## 11. 已拍板决策

| # | 决策 | 说明 |
|---|------|------|
| 1 | **保留目录名 `linux-sdk/`** | 进仓后仍用此名；不改名为 `platform/` |
| 2 | **OEM 镜像 = ext4** | `make build-oem` 产 ext4 `oem.img`；v1 不做 squashfs |
| 3 | **P3.2 仅 aarch64 UTM** | 开发机均为 Apple Silicon；不做 x86_64 host 模拟器路径 |
| 4 | **`product.ini` v1 进 OEM** | 按现状把出厂身份/调参（含 `camera_ip` 等）放入 OEM board 包；运行时仍衔接 HAL 既有路径；**长期归属未来另议** |
| 5 | **整包改称 `factory.img`** | 取代以单一 `update.img` 为工厂产物的心智；过渡期可 symlink |
| 6 | **U-Boot / OEM 分目录 + 环境变量选择** | `prebuilt/bootloader/<uboot_id>/` 与 `oem/out/<oem_id>/`；`FACTORY_SKU`（可覆盖 `UBOOT_ID`/`OEM_ID`）驱动 `build-oem` / `build-img` / `flash`；缺文件失败，禁止静默混用 |

---

**总结**：用 **OEM 组合硬件（含 v1 `product.ini`）、App 持有产品寄存器图、boot/rootfs 做通用 OS、自有 `linux-sdk` 替换补丁机、环境变量选择 uboot/oem 打出分 SKU 的 `factory.img`、aarch64 UTM 当第二块板+屏**，即可在不仿真瑞芯微 SoC 的前提下，把多主板/多屏幕做成可验证的工程框架。Factory Test 不阻塞本路径。
