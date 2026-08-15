# U-Boot / SPL loader（rkbin + rockchip-linux/u-boot）

## 策略（纠正旧说法）

**U-Boot 可以、也应该能自行编译。** 旧文档「ynh960 勿 `make build-uboot` / 不要自建」把因果倒置了：

- **因：** 没有可用的板级设备树 / 错误 defconfig / 未配对的 DDR+SPL，刷上去会进不了 Maskrom 友好状态。  
- **果：** 某次踩坑后写成「禁止自编」。  
- **正解：** 有匹配的 **DTS + rkbin 固件包 + 正确 defconfig** 后，从 Rockchip 公开树自建 `uboot.img` 与 SPL loader，是正规路径；产物再落到 `prebuilt/bootloader/<uboot_id>/` 供 `build-img` / `flash` 使用。

量产机仍应刷 **已在该 SKU 验收过的一对** `uboot.img` + `rk*_spl_loader_*.bin`。禁止的是「未验收就替换现场量产包」，不是「禁止编译」。

### 权威文件名 = rkbin `boot_merger` OUTPUT

| SoC / 包 | 权威 early loader 文件名 | 说明 |
|----------|--------------------------|------|
| ynh960 / RK3566 | **`rk356x_spl_loader_v*.bin`** | 与 `RK3566MINIALL.ini` `[OUTPUT] PATH=` 一致 |
| ek3562 / RK3562 | **`rk3562_spl_loader_v*.bin`** | 与 `RK3562MINIALL*.ini` OUTPUT 一致 |

**不要**发明 `loader.bin` / `bootloader.bin` 作为权威名。`MiniLoaderAll.bin` 仅作 **过渡 symlink**（指向上述 SPL 文件），因为 `package-file` / 部分 `upgrade_tool` 路径仍用该 basename。

Rockchip rkbin 里 **FlashBoot** 可以是：

| FlashBoot 组件 | 典型平台 | 合并产物名 |
|----------------|----------|------------|
| `*_spl_*.bin` | **RK3566/3568 eMMC（现行）**、RK3562、RK3588… | `rk356x_spl_loader_*.bin` / `rk3562_spl_loader_*.bin` |
| `*_miniloader_*.bin` | 老平台 / 部分 SPI NAND | 历史 `MiniLoader*` 语义 |

公开 [RK3566MINIALL.ini](https://github.com/rockchip-linux/rkbin/blob/master/RKBOOT/RK3566MINIALL.ini) 已是：

`FlashBoot=bin/rk35/rk356x_spl_v1.14.bin` → `PATH=rk356x_spl_loader_v….bin`

本仓库 **ynh960** 交付物：`prebuilt/bootloader/rockchip-ynh960/rk356x_spl_loader_v1.23.114.bin`（`boot_merger` + SDK `RK3566MINIALL.ini`，DDR **v1.23** / 1056 MHz）。`MiniLoaderAll.bin` → 该文件的 symlink。详见包内 `README.md` 与备份目录 `backup/<stamp>/`。

rkbin 的 `bin/rk35/` 对 RK3566/356x **几乎只有 SPL**；残留 `rk3568_miniloader_spinand_*` 仅 SPI NAND 特例，与 ynh960 eMMC 无关。

### SPL loader vs OP-TEE（BL31/BL32）— 勿混换

Rockchip 早期链大致是：

```text
BootROM → [DDR + SPL] loader（权威名 rk*_spl_loader_*.bin）
        → uboot.img（FIT：BL31 ATF + BL32 OP-TEE + U-Boot …）
        → Linux (boot_fit)
```

| 组件 | ynh960 钉死 | 本机 `linux-sdk/rkbin` `RK3568TRUST.ini` | GitHub `rkbin` master（勿默默跟） |
|------|-------------|------------------------------------------|-----------------------------------|
| **BL31** | **v1.44**（`bl31-v1.44`） | `rk3568_bl31_v1.44.elf` | `rk3568_bl31_v1.46.elf` |
| **BL32 / OP-TEE** | **v2.15**（`bl32-v2.15`） | `rk3568_bl32_v2.15.bin` | `rk3568_bl32_v2.16.bin` |
| **Loader DDR** | `ddr-v1.23`（`RK3566MINIALL.ini`） | （与 TRUST 无关） | master 可能默认 DDR **v1.25** 等 |

说明：

- **没有单独的 `RK3566TRUST.ini`**——3566/3568 共用 `RK3568TRUST.ini` / `rk3568_bl3*`。
- **只换 SPL**（`boot_merger` 的 DDR+SPL）不会改 BL31/BL32，一般**不影响**现网 OP-TEE、seal TA、HUK/VS KEK。
- **会影响 OP-TEE 的**是重打 **`uboot.img` FIT** 并换上 master 的 BL32 **v2.16**：须重新验收 TA 签名、`tee-supplicant`、secrets-seal。
- 自建 uboot 时应用 **与现网一致的 TRUST**（SDK 树里的 v1.44 / v2.15），或把 BL32+TA 密钥**整包升级并验收**，不要 silent 跟到 master v2.16。

| 角色 | 路径 |
|------|------|
| 源码 | [github.com/rockchip-linux/u-boot](https://github.com/rockchip-linux/u-boot)（默认分支见 `overlay/third-party/uboot.version`） |
| 闭源 bin / merger | [github.com/rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin)（本仓库以 `linux-sdk/rkbin` 钉死的 DDR/TRUST 为准） |
| 仓库交付物 | `prebuilt/bootloader/<uboot_id>/{rk*_spl_loader_*.bin,uboot.img}` + 可选 `MiniLoaderAll.bin` symlink + `board/factory-skus.tsv` |
| 板级 DT（Linux FIT） | `overlay/kernel/rockchip/<board_id>.dts`（与 U-Boot 板级 DT **同源对照**，启动 DTB 仍由 FIT 提供） |

`make fetch-uboot` 把 `rockchip-linux/u-boot` 装进 `linux-sdk/u-boot/`，并跑 `patch-uboot-bootcmd.sh`（Linux-first：`boot_fit`，**无** `boot_android` 抢先）。`make build-uboot` 走 SDK `./build.sh uboot`（现 lunch / ynh960）；编完拷进 `prebuilt/bootloader/<uboot_id>/`。

---

## 1. SPL loader（rkbin + `boot_merger`）

在 Linux 构建机（或 Docker amd64）上：

```bash
# 已有 SDK 时直接用 lunch 树里的 rkbin（推荐：TRUST/DDR 已钉死）
cd linux-sdk/rkbin
./tools/boot_merger RKBOOT/RK3566MINIALL.ini   # ynh960 → rk356x_spl_loader_v1.23.114.bin
# ek3562 示例：
# ./tools/boot_merger RKBOOT/RK3562MINIALL.ini

cp -f rk356x_spl_loader_v1.23.114.bin \
  ../../prebuilt/bootloader/rockchip-ynh960/
cd ../../prebuilt/bootloader/rockchip-ynh960
ln -sfn rk356x_spl_loader_v1.23.114.bin MiniLoaderAll.bin
```

- 工具名是 **`boot_merger`**（不是 boot_meger）。  
- **安装 OUTPUT 文件名原样**，不要改名为 `loader.bin`。  
- 包 README 须记录：ini、OUTPUT basename、DDR/SPL、所用 rkbin 树身份。

`scripts/factory-sku.sh` 解析顺序：`FACTORY_SPL_LOADER=` 钉死 basename → 目录内恰好一个 `rk356x_spl_loader_*.bin` / `rk3562_spl_loader_*.bin` → 否则 `MiniLoaderAll.bin`。

---

## 2. `uboot.img`（u-boot 源码 + Linux-first bootcmd）

```bash
make fetch-uboot    # 应用 patch-uboot-bootcmd.sh
make build-uboot    # SDK ./build.sh uboot；TRUST 来自 SDK RK3568TRUST.ini

# 验收字符串
strings output/firmware/uboot.img | grep -E 'bl31-v1.44|bl32-v2.15'
strings output/firmware/uboot.img | grep '^bootcmd='
# 期望：无 boot_android 在 boot_fit 之前

cp -f output/firmware/uboot.img prebuilt/bootloader/rockchip-ynh960/uboot.img
```

新 SoC / EVB 若 lunch 配置不同，可按 Rockchip 标准流程选 defconfig 后编，再拷入对应 `prebuilt/bootloader/<uboot_id>/`。

要点：

- **设备树：** U-Boot 树内板级 DTS 须与硬件一致。  
- **FIT 多 conf：** U-Boot 需能 `bootm <addr>#<board_id>`；与 `board/rk356x-fit-boards.txt` 对齐。  
- **禁止**对已打包 `uboot.img` 做二进制 env 补丁（CRC → 变砖风险）。

---

## 3. 接入 factory / 回滚

1. `board/factory-skus.tsv` 映射 `FACTORY_SKU` → `uboot_id` / `oem_id`。  
2. `FACTORY_SKU=ynh960-p800 make build-oem` / `make build-img` / `make flash`。  
3. 串口确认 Linux-first（无 Android FIT 尝试）+ HMI + `/dev/tee0` / seal。

**回滚（ynh960）：**

```bash
# 从备份恢复（示例 stamp）
cp -f prebuilt/bootloader/rockchip-ynh960/backup/<stamp>/MiniLoaderAll.bin \
  prebuilt/bootloader/rockchip-ynh960/rk356x_spl_loader_v1.23.114.bin
# 或恢复旧命名布局后重建 symlink — 见 backup README
cp -f prebuilt/bootloader/rockchip-ynh960/backup/<stamp>/uboot.img \
  prebuilt/bootloader/rockchip-ynh960/uboot.img
FACTORY_SKU=ynh960-p800 make build-img
make reboot-loader
FACTORY_SKU=ynh960-p800 make flash
```

ynh960 现网包目录：`prebuilt/bootloader/rockchip-ynh960/`。**不要**用 RK3562 产物刷 ynh960。

---

## 相关

- ek3562 清单：[`overlay/kernel/rockchip/ek3562.md`](../overlay/kernel/rockchip/ek3562.md)  
- SKU 表：[`board/factory-skus.tsv`](../board/factory-skus.tsv)  
- Make 构建模型：[`docs/make-commands.md`](make-commands.md)  
- OpenSpec：`openspec/changes/ynh960-spl-linux-uboot`
