# E0 Spike 报告：flutter-embedded-linux backend 决策

日期：2026-07-20 · 板卡：ynh960 · 引擎：Flutter 3.24.4 / `db49896cf25ceabc44096d5f088d86414e05a7aa`

配套脚本：[`scripts/spike-elinux-drm-gbm.sh`](../scripts/spike-elinux-drm-gbm.sh) · 测量：[`scripts/debug-frame-pacing.sh`](../scripts/debug-frame-pacing.sh)

---

## 1. E0.1 — 版本与依赖

| 项 | 结论 |
| ---- | ---- |
| 本仓库引擎 | `prebuilt/flutter-engine/3.24.4` → engine rev **`db49896cf2…`** |
| eLinux 匹配 tag | Sony [`flutter-embedded-linux@db49896cf2`](https://github.com/sony/flutter-embedded-linux/releases/tag/db49896cf2)（与官方 Flutter 3.24.4 同引擎） |
| 源码检出 | tag → commit `9d0ff07b5e1c…` |
| CMake backends | `WAYLAND` / `DRM-GBM` / `DRM-EGLSTREAM` / `X11` |
| 关键选项 | **`ENABLE_VSYNC`（CMake，默认 OFF）** —— 打开后走 `FlutterEngineOnVsync`；运行时另有 `--async-vblank`（eglSwapInterval 0） |
| 交叉编译 | Buildroot staging sysroot + `aarch64-none-linux-gnu-g++`（Docker volume）；**无需 clang**（提供 `CMAKE_TOOLCHAIN_FILE` 即可） |
| 引擎复用 | ✅ 直接链接现有 `libflutter_engine.so`；bundle 复用 `/opt/hmi`（需把真实 `icudtl.dat` 放到 `/opt/hmi/data/`） |

开放问题 Q1（引擎兼容 tag）→ **已关闭：精确匹配，无需为 spike 升引擎。**

---

## 2. E0.4 — libmali 变体

SDK `linux-sdk/external/libmali/lib/aarch64-linux-gnu/`（RK3566 Bifrost G52 / g24p0）现成变体包括：

- `libmali-bifrost-g52-g24p0-gbm.so` ← **量产当前**（设备 `/usr/lib/libmali-*.so`）
- `libmali-bifrost-g52-g24p0-wayland-gbm.so` ← **Weston / Wayland 路径可用**
- 另有 `x11-gbm` / `x11-wayland-gbm` / `dummy-*` 等

Buildroot `rockchip-mali`：启用 `BR2_PACKAGE_WAYLAND` 且 `HAS_GBM` 时，platform 自动拼成 `wayland-gbm`。Weston 包已在 SDK（`buildroot/package/weston`）。

开放问题 Q2 → **已关闭：`wayland-gbm` 现成，切换代价 = 改 Mali platform + 引入 wayland/weston 依赖并重建用户态。**

---

## 3. E0.2 / E0.3 — DRM-GBM 实测（方案 B）

### 方法

1. 交叉编译 `examples/flutter-drm-gbm-backend` → `/userdata/elinux-spike/flutter-drm-gbm-backend`
2. `systemctl stop hmi`；`FLUTTER_DRM_DEVICE=/dev/dri/card0 ./flutter-drm-gbm-backend --bundle=/opt/hmi --rotation=90`
3. `debug-frame-pacing.sh` 采 present fps（DRM `buf[0]` 地址变化 / 秒），对照 VOP2 vblank ≈ **56 Hz**

### 公平 A/B（同会话、同首页动画，连续三轮）

| 轮次 | present avg | min–max |
| ---- | ----------: | ------- |
| flutter-pi（1） | 38.4 | 34–43 |
| **eLinux DRM-GBM + `ENABLE_VSYNC=ON`** | **39.6** | 35–47 |
| flutter-pi（2） | 40.2 | 28–47 |

辅助观察：

- `ENABLE_VSYNC=OFF`（Sony 默认）：不稳定，曾见 22–28 后掉到 0（不可用）
- `ENABLE_VSYNC=ON`：稳态可跑，与 flutter-pi **持平量级**，**未拉开差距**
- 两端均 **远低于硬指标 ≥50fps / 贴近 56fps**

### 结论（方案 B）

- ✅ 技术可行：现有引擎 + 现有 `/opt/hmi` AOT bundle 可跑
- ❌ **未过决策门**：未稳定 ≥50fps；相对 flutter-pi 无实质帧率收益
- 量产若取 B，仍须 `ENABLE_VSYNC=ON`（OFF 不可用）

---

## 4. 决策

| 选项 | 结果 |
| ---- | ---- |
| **B · eLinux DRM-GBM** | **不达标**（~40fps ≈ flutter-pi） |
| **C · eLinux Wayland + Weston** | **基础设施已打通**；帧率门控测量未完成（见 §5） |
| R6 引擎层 | 仅当 C 证实不达标时升级（可与 P5.1 合并） |

**Spike 决策：放弃单独以 B 作为终态；量产方向锁定方案 C**（与 P3.2 模拟器收敛）。E0.5 实测 C present ≈ **41fps**（flutter-pi ≈ **24fps**）；**≥50fps 硬门控未过**，进入 E1/E3 时继续调优。

---

## 5. E0.5 — Weston + Wayland（部分完成）

### 已完成

| 项 | 状态 |
| ---- | ---- |
| `chips/lws_hmi_wayland.config` | ✅ wayland / weston(DRM+desktop-shell) / wayland-protocols |
| `rockchip-mali` → `wayland-gbm` | ✅ `br-make-packages` 重建 |
| `make build-rootfs` + `make upgrade` | ✅ 板端有 weston 与 wayland-gbm |
| eLinux Wayland runner | ✅ `scripts/spike-elinux-wayland.sh`（`ENABLE_VSYNC=ON`） |
| Weston 启动 | ✅ DRM atomic + GL(Mali-G52)；spike 曾用 kiosk；**量产路径改为 desktop-shell** + `boot-splash.png` |
| Flutter Wayland 客户端 | ✅ 跑通 `/opt/hmi` bundle |

### 帧率盖章（2026-07-20，同首页 `/opt/hmi`，15s）

测量方法：

| 栈 | 指标 |
| ---- | ---- |
| flutter-pi | DRM primary-plane `buf[0]` 翻转（`debug-frame-pacing.sh`） |
| eLinux Wayland | 嵌入器 `eglSwapBuffers*` 成功次数 → `ELINUX_PRESENT_FPS`（[`spike-elinux-present-fps.patch`](../scripts/spike-elinux-present-fps.patch)） |

| 轮次 | present avg | min–max | ≥50fps 门控 |
| ---- | ----------: | ------- | :---: |
| **A flutter-pi** | **24.1** | 17–28 | FAIL |
| **C Weston + eLinux Wayland** | **40.6** | 39–41 | FAIL |
| B DRM-GBM | — | — | SKIP（`wayland-gbm` Mali 下 `EGL_BAD_DISPLAY`；B 已否决） |

脚本：[`scripts/spike-seal-frame-pacing.sh`](../scripts/spike-seal-frame-pacing.sh)

### 盖章结论

1. **方案 C 相对 flutter-pi 有实质收益**（~41 vs ~24 present fps，稳态无掉零）。
2. **硬门控 ≥50fps 仍未过**（贴近面板 56Hz 差 ~15fps）→ 不阻塞「方向锁定 C」，但 E3/验收前需继续调 Weston 合成 / vsync / 引擎（或与 P5.1 合并评估）。
3. 切换 Mali → `wayland-gbm` 后 flutter-pi DRM 路径变慢（此前同探针曾 ~38–40）；**回退 flutter-pi 时需恢复 `gbm` 变体**，不能只靠进程切换。

**E0.5 状态：基础设施 ✅ · 帧率门控 ❌（C 领先但 <50）· 方向仍锁定 C。**

### 板端备忘

```bash
systemctl stop hmi
pkill -9 -x flutter-pi weston flutter-wayland-client || true
mkdir -p /run/user/0; chmod 700 /run/user/0
XDG_RUNTIME_DIR=/run/user/0 weston --backend=drm-backend.so --shell=desktop-shell.so --idle-time=0 &
XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0 \
  /userdata/elinux-spike/flutter-wayland-client --bundle=/opt/hmi --fullscreen --rotation=90 &
# 恢复：pkill weston/client；systemctl start hmi
```

Weston ini：`scripts/spike-weston.ini`（量产同款：`desktop-shell` + `boot-splash.png`；`transform=rotate-270` 对齐 `landscape_left`，不要写裸 `90`）。

---

## 6. DRM-GBM spike 操作说明

```bash
# 重建 DRM-GBM spike（默认 ENABLE_VSYNC=ON）
bash scripts/spike-elinux-drm-gbm.sh build
bash scripts/spike-elinux-drm-gbm.sh push
bash scripts/spike-elinux-drm-gbm.sh run 90
bash scripts/debug-frame-pacing.sh my-run 15
bash scripts/spike-elinux-drm-gbm.sh restore   # 回到 flutter-pi
```

注意：`run` 前须杀掉残留的 `flutter-drm-gbm-backend`（勿与 `flutter-pi` 同时占 `/dev/dri/card0`）。
