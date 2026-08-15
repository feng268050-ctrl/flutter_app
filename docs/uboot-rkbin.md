# U-Boot / MiniLoader（rkbin + rockchip-linux/u-boot）

## 策略（纠正旧说法）

**U-Boot 可以、也应该能自行编译。** 旧文档「ynh960 勿 `make build-uboot` / 不要自建」把因果倒置了：

- **因：** 没有可用的板级设备树 / 错误 defconfig / 未配对的 DDR+SPL，刷上去会进不了 Maskrom 友好状态。  
- **果：** 某次踩坑后写成「禁止自编」。  
- **正解：** 有匹配的 **DTS + rkbin 固件包 + 正确 defconfig** 后，从 Rockchip 公开树自建 `uboot.img` 与 loader，是新板（如 **ek3562**）的正规路径；产物再落到 `prebuilt/bootloader/<uboot_id>/` 供 `build-img` / `flash` 使用。

量产机仍应刷 **已在该 SKU 验收过的一对** `uboot.img` + `MiniLoaderAll.bin`（或 `*_loader_*.bin` 改名约定）。禁止的是「未验收就替换现场量产包」，不是「禁止编译」。

### 命名澄清：`MiniLoaderAll.bin` ≠ 旧 miniloader 架构

Rockchip rkbin 里 **FlashBoot** 可以是：

| FlashBoot 组件 | 典型平台 | 合并产物名 |
|----------------|----------|------------|
| `*_spl_*.bin` | **RK3566/3568 eMMC（现行）**、RK3562、RK3588… | `rk356x_spl_loader_*.bin` / `rk3562_spl_loader_*.bin` |
| `*_miniloader_*.bin` | 老平台 / 部分 SPI NAND | 历史 `MiniLoader*` 语义 |

公开 [RK3566MINIALL.ini](https://github.com/rockchip-linux/rkbin/blob/master/RKBOOT/RK3566MINIALL.ini) 已是：

`FlashBoot=bin/rk35/rk356x_spl_v1.14.bin` → `PATH=rk356x_spl_loader_v1.25.114.bin`

本仓库 **ynh960** 的 `prebuilt/.../MiniLoaderAll.bin` 在 `scripts/build-img.sh` 里会 staged 成 **`rk356x_spl_loader_v1.23.114.bin`**，blob 内嵌 `ddr-v1.23` —— 即 **已经是 SPL+DDR 的 merger 产物**，只是工厂/`upgrade_tool` 习惯文件名仍叫 `MiniLoaderAll.bin`。  
因此 ynh960 **不必**「抛弃旧 miniloader、改走 SPL」——架构上已是 SPL；要做的是用匹配 DDR 频率的 `RK3566MINIALL*.ini` **自建/升级**同一类 `*_spl_loader_*`，验收后替换 prebuilt。

rkbin 的 `bin/rk35/` 对 RK3566/356x **几乎只有 SPL**；残留 `rk3568_miniloader_spinand_*` 仅 SPI NAND 特例，与 ynh960 eMMC 无关。

### SPL loader vs OP-TEE（BL31/BL32）— 勿混换

Rockchip 早期链大致是：

```text
BootROM → [DDR + SPL] loader（本仓库文件名常叫 MiniLoaderAll.bin）
        → uboot.img（FIT：BL31 ATF + BL32 OP-TEE + U-Boot …）
        → Linux
```

| 组件 | ynh960 现网（`prebuilt/sdk-uboot/uboot.img` 内嵌） | 本机 `linux-sdk/rkbin` `RK3568TRUST.ini` | GitHub `rkbin` master `RK3568TRUST.ini` |
|------|-----------------------------------------------------|------------------------------------------|----------------------------------------|
| **BL31** | **v1.44**（`bl31-v1.44`） | `rk3568_bl31_v1.44.elf` | `rk3568_bl31_v1.46.elf` |
| **BL32 / OP-TEE** | **v2.15**（`bl32-v2.15`；TEEOS 串含 `fwver: v2.15`） | `rk3568_bl32_v2.15.bin` | `rk3568_bl32_v2.16.bin` |
| **Loader DDR** | MiniLoader 内 `ddr-v1.23` | （与 TRUST 无关） | `RK3566MINIALL` 现默认 DDR **v1.25** 等 |

说明：

- **没有单独的 `RK3566TRUST.ini`**——3566/3568 共用 `RK3568TRUST.ini` / `rk3568_bl3*`。
- **只换 SPL/`MiniLoaderAll.bin`（`boot_merger` 的 DDR+SPL）不会改 BL31/BL32**，一般**不影响**现网 OP-TEE、seal TA（`keys/oem/vendor_ta.pem` 对 **BL32 v2.15**）、HUK/VS KEK。
- **会影响 OP-TEE 的**是重打 **`uboot.img` FIT** 并换上 master 的 BL32 **v2.16**（或任意新 BL32）：须重新验收 TA 签名、`tee-supplicant`、secrets-seal；文档见 `docs/hal-secrets-kek.md`（产品路径锚定 `rk3568_bl32_v2.15`）。
- 自建 uboot 时应用 **与现网一致的 TRUST**（SDK 树里的 v1.44 / v2.15），或把 BL32+TA 密钥**整包升级并验收**，不要 silent 跟到 master v2.16。

| 角色 | 路径 |
|------|------|
| 源码 | [github.com/rockchip-linux/u-boot](https://github.com/rockchip-linux/u-boot)（默认分支见 `overlay/third-party/uboot.version`，现为 `next-dev`） |
| 闭源 bin / merger | [github.com/rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin) |
| 仓库交付物 | `prebuilt/bootloader/<uboot_id>/{uboot.img,MiniLoaderAll.bin}` + `board/factory-skus.tsv` |
| 板级 DT（Linux FIT） | `overlay/kernel/rockchip/<board_id>.dts`（与 U-Boot 板级 DT **同源对照**，但启动 DTB 仍由 FIT 提供） |

`make fetch-uboot` 已会把 `rockchip-linux/u-boot` 装进 `linux-sdk/u-boot/`。`make build-uboot` 当前走 SDK `./build.sh uboot`（面向现 lunch / ynh960 配置）；**新 SoC / EVB 请按下文 Rockchip 标准流程编**，编完拷进对应 `prebuilt/bootloader/<uboot_id>/`。

---

## 1. MiniLoader / loader（rkbin + `boot_merger`）

在 Linux 构建机（或 Docker amd64）上：

```bash
git clone https://github.com/rockchip-linux/rkbin.git
cd rkbin

# 选与 SoC / DDR 匹配的 ini（RK3562 EVB2 DDR4 常见为 RK3562MINIALL*.ini；
# 以板厂文档或现板 DDR 频率为准，对照 RKBOOT/ 与 bin/rk35/rk3562_ddr_*）
./tools/boot_merger RKBOOT/RK3562MINIALL.ini
```

- 工具名是 **`boot_merger`**（不是 boot_meger）。  
- 输出一般为 `rk3562_spl_loader_v*.bin`（或 ini 里 `[OUTPUT] PATH=`）。  
- 交付到本仓库时，按 SKU 约定复制为：

```text
prebuilt/bootloader/vendor-ek3562/MiniLoaderAll.bin
```

（文件名与 `scripts` / `build-img` 期望一致即可；保留一份 README 记录所用 ini、ddr/spl 版本与 git rev。）

---

## 2. `uboot.img`（u-boot 源码 + 板级 DT）

```bash
# 已有 SDK 时可：
make fetch-uboot
# 或手动：
# git clone -b next-dev --depth 1 https://github.com/rockchip-linux/u-boot.git

cd linux-sdk/u-boot   # 或你的 clone
# 选用与板子匹配的 defconfig（RK3562 EVB2 在上游 configs/ 中查找
# rk3562_evb* / 板厂文档指定的 *_defconfig）
make CROSS_COMPILE=aarch64-linux-gnu- <board>_defconfig
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
# Rockchip 流程通常再打包 uboot.img（./make.sh 或 SDK 包装脚本；
# 以所用分支 README / 板级文档为准）
```

要点：

- **设备树：** U-Boot 树内板级 DTS 须与硬件一致；本仓库 Linux 侧 `ek3562.dts`（EVB2 DDR4 V10）作对照，勿混用 ynh960 / RK3566 DT。  
- **FIT 多 conf：** U-Boot 需能 `bootm <addr>#ek3562`（或 factory env 选 conf）；与 `board/rk356x-fit-boards.txt` 的 `board_id` 对齐。  
- 产出拷到：

```text
prebuilt/bootloader/vendor-ek3562/uboot.img
```

---

## 3. 接入 factory

1. `board/factory-skus.tsv` 已有 `ek3562-dev` → `vendor-ek3562`。  
2. `FACTORY_SKU=ek3562-dev make build-oem` / `make build-img` / `make flash`。  
3. 串口验收（ek3562 Debug @ 115200）：`PORT=/dev/cu.usbserial* make serial-console`。

ynh960 现网包：`prebuilt/bootloader/rockchip-ynh960/`。自建替换前必须在同 SKU 硬件上验收；**不要**用 RK3562 产物刷 ynh960。

---

## 相关

- ek3562 清单：[`overlay/kernel/rockchip/ek3562.md`](../overlay/kernel/rockchip/ek3562.md)  
- SKU 表：[`board/factory-skus.tsv`](../board/factory-skus.tsv)  
- Make 构建模型：[`docs/make-commands.md`](make-commands.md)
