# 嵌入器迁移计划（flutter-pi → flutter-embedded-linux / Weston · ynh960 基准）

## 状态（2026-07-25）

**完成：** 量产仅保留 Weston + `flutter-wayland-client`；`flutter-pi` 备选 rootfs / prebuilt / Buildroot 包 / `flutterpi_tool` 已移除；App 打包改为 `scripts/hmi-bundle-common.sh`（`flutter assemble` + `gen_snapshot`）。下文保留迁移诊断与决策史实。

目标：把量产 HMI 的 Flutter **嵌入器**从 **flutter-pi** 换成 **flutter-embedded-linux（Sony eLinux）+ Weston**，以解决在本机上无法达到面板刷新率的**动画帧调度 / vsync 卡顿**问题。本文给出诊断依据、候选方案对比、推荐路线、风险、分阶段计划与验收标准。

**当前量产（2026-07）：** `make build-rootfs` → Weston + eLinux（flutter-pi 备选已移除）。根文件系统固定 **600M**（`lws_hmi_rootfs.config`）。

配套阅读：主线规划 [`flutter-linux-hmi-plan.md`](flutter-linux-hmi-plan.md)（§5 显示栈、§3.2 模拟器、§6 应用打包、P5.1 引擎升级）；帧调度诊断脚本 [`scripts/debug-frame-pacing.sh`](../scripts/debug-frame-pacing.sh)、[`scripts/debug-jank-probe.sh`](../scripts/debug-jank-probe.sh)。

状态图例：✅ 完成 · 🔄 进行中 · 🔲 未开始

---

## 1. 背景与结论

### 1.1 现象

首页两个循环动画（`home_left_1m.webp` / `home_right_1m.webp`，200×200、~30fps）在设备上明显卡顿；同一素材在 macOS / Android 上流畅。

### 1.2 诊断依据（本轮 runtime 取证）

| 证据 | 数据 | 结论 |
| ---- | ---- | ---- |
| 面板刷新率 | ~56.3 Hz（VOP2 vblank 稳定） | 目标帧率 56Hz |
| CPU/GPU/DDR 频率 | CPU 1.8GHz、GPU 800MHz、DDR 1560MHz，全部 `performance` governor 锁最高频 | 非降频问题 |
| 深睡 | `cpu-sleep` 已 disable，仅 WFI | 非深度 idle 唤醒延迟 |
| 动画中各线程占用 | `io.flutter.ui`/`rast`/worker 均 ~1%，整机 84% idle | **非算力/GPU 瓶颈** |
| 引擎稳态出帧 | 即使常驻 `Ticker` 连续驱动，present 仍只有 ~26 帧/秒（间隔 ~38ms），其中 KMS commit 阻塞仅 ~9ms | **瓶颈在嵌入器/引擎帧调度** |
| 启动瞬间 | 前几百 ms 引擎因布局/首帧额外出帧，动画冲到 ~31–42fps，随后回落 ~20–26fps | 管线有余量,受限于稳态 vsync 请求节奏 |

在应用侧尝试过（均已回退）：非阻塞/三缓冲 KMS present、引擎 vsync 回调改造、预解码帧序列播放器、相邻帧 blend 补帧。预解码 blend 版可把速度改到"比原生更快"，进一步印证**算力充足、瓶颈在 flutter-pi 的帧交付节奏**。

### 1.3 结论

- **不是** 硬件性能不足，**不是** Flutter 应用/组件写法问题，**不是** 素材问题（素材 30fps 在 56Hz 上应可正常播放）。
- 根因是 **flutter-pi 在本平台的帧调度 / vsync 交付**：稳态每帧约需"等一个 vblank 周期 + 一次 build/raster/commit"≈ 2 个周期，使有效出帧率被压到 ~26fps，且节奏抖动。
- 应用侧 workaround 不能根治；决定**更换嵌入器**。

---

## 2. 目标与非目标

**目标**

1. 量产设备（ynh960 基准）Flutter HMI 的动画/滚动**稳定跑到面板刷新率（~56fps）**，观感对齐 macOS/Android。
2. 保持现有产品能力不回退：输入（USB/BT 键鼠、Goodix 触摸、电源键）、光标、旋转、文本输入、A/B 升级、启动 KPI。
3. 尽量**复用现有 arm64 `libflutter_engine.so`（3.24.4）**，避免引擎重编。
4. 与主线 **P3.2 模拟器**（已规划 Weston + flutter-embedded-linux）**收敛为同一嵌入器**，降低长期维护成本。

**非目标**

- 不在本计划内升级 Flutter Engine（引擎升级见主线 P5.1，可与本迁移合并评估）。
- 不改动 CyberUI/业务 UI 结构;不引入 X11/Chromium。
- 不追求"56 张不同帧/秒"的素材级流畅（素材只有 ~30fps，属另一议题）。

---

## 3. 候选方案对比

三种终态（Weston 本身不是 Flutter 运行时，需搭配 eLinux 的 Wayland backend 作为 Wayland 客户端）：

| 维度 | A. flutter-pi（现状） | B. eLinux · DRM-GBM backend | C. eLinux · Wayland backend + Weston |
| ---- | ---- | ---- | ---- |
| 显示路径 | 直接 KMS/GBM scanout | 直接 KMS/GBM scanout | Weston 合成器持有 KMS，Flutter 提交 Wayland buffer |
| 帧调度/vsync | **有问题(本文根因)** | 独立实现，需实测是否更好 | **交给成熟合成器**，pacing 最稳 |
| 相对现状改动量 | — | 小(近似替换) | 大(引入合成器 + Wayland 栈) |
| libmali 变体 | `gbm` | `gbm` | 需 `wayland-gbm` 变体 |
| 引擎复用 | 是 | 是(同 embedder API) | 是(同 embedder API) |
| 输入 | libinput + 10 个定制补丁 | libinput(eLinux 自有处理) | Weston(libinput) → Wayland 传给客户端 |
| 光标/旋转/多平面 | flutter-pi 补丁处理 | 需在 eLinux 侧重建 | Weston 原生处理 |
| 启动 KPI(≤10s) | 基线 | 近似 | **增加合成器启动开销**,需实测 |
| 内存/复杂度 | 低 | 低 | 较高(多一个进程 + 协议栈) |
| 与 P3.2 模拟器一致性 | 不一致 | 部分一致(同嵌入器不同 backend) | **完全一致(同嵌入器 + 同 Weston)** |

---

## 4. 推荐路线

**统一采用 flutter-embedded-linux（eLinux）作为嵌入器**；backend 通过"先廉价验证再定"的方式确定:

1. **首选终态 = 方案 C（eLinux · Wayland + Weston）**，理由:
   - 根因是嵌入器帧调度;Weston 是 Rockchip DRM 上最成熟、最稳的 vsync/atomic pacer,最可能直接达成 56fps 观感。
   - 与主线 **P3.2 模拟器已规划的 Weston + eLinux 栈收敛**,设备与模拟器**共用一套嵌入器**,长期维护收益大。
   - 光标、旋转、多平面、DPMS/背光协调由 Weston 原生处理,减少自研补丁面。
2. **保留方案 B（eLinux · DRM-GBM）作为更轻的备选**:若 Phase 0 spike 证明 DRM-GBM **单独就能**稳定到面板刷新率,则优先取 B(更省内存、启动更快、无需 `wayland-gbm` libmali 变体)。

> 决策门(见 §6 Phase 0):以"同一首页动画在设备上的 present 稳态帧率"为唯一硬指标。B 达标则取 B;B 不达标、C 达标则取 C;两者都不达标则回到引擎层(见 §8 风险 R6)。

---

## 5. 风险与依赖

| 编号 | 风险 | 影响 | 缓解 |
| ---- | ---- | ---- | ---- |
| R1 | **libmali 变体**:Wayland backend 需 `wayland-gbm` 变体,当前量产用 `gbm` 变体 | C 方案阻塞项 | Phase 0 先确认 Rockchip 提供的 libmali 变体清单与切换代价;必要时并存两套 |
| R2 | **输入/光标补丁丢失**:flutter-pi 的 10 个补丁(文本光标、键盘 LED/重复、鼠标偏好、BT 轴交换、光标尺寸、Rockchip 光标 stride/move 回退)在新嵌入器不存在 | 输入能力回退 | 逐项归类:Weston/eLinux 原生已覆盖的删除;仍需的在 eLinux 侧或 `cyber_hal` 重建;建输入平权 checklist(见 §7.2) |
| R3 | **启动 KPI**:Weston 增加合成器启动时间,可能触碰 ≤10s | 用户体验/验收 | Phase 3 实测 boot KPI;必要时 Weston 精简配置/并行启动 |
| R4 | **Buildroot 打包**:需新增 eLinux(+ 可能 Weston/wayland/wayland-protocols)包与 prebuilt 流程 | 工作量 | 复用现有 prebuilt 模式(`flutter-engine.mk` / `flutter-embedded-linux.mk`);eLinux 走 CMake |
| R5 | **引擎 embedder API 兼容**:eLinux 需与 3.24.4 `libflutter_engine.so` 的 embedder API 对齐 | 编译/运行 | 选用与 3.24.4 匹配的 eLinux tag;先用现有引擎 .so 验证,不行再评估引擎重编 |
| R6 | **换嵌入器仍不达标**:若 DRM-GBM 与 Weston 都到不了 56fps | 计划失败 | 说明瓶颈在引擎(Animator/vsync waiter)层,转入引擎升级(P5.1)或引擎侧调查;Phase 0 的低成本正是为尽早暴露此风险 |
| R7 | `cyber_hal` 鼠标偏好(`/var/lib/hmi/mouse.conf`)当前由 flutter-pi 补丁 0005 消费 | 鼠标设置失效 | Wayland 下改由 Weston/libinput 配置或 `cyber_hal` 适配 |

---

## 6. 分阶段计划

### E0 — 可行性 Spike（决策门）🔄

**目标**:用最小代价确定 backend,尽早暴露 R1/R5/R6。

- E0.1 调研 eLinux 与 3.24.4 匹配的 tag、CMake 依赖、backend 编译开关。✅ → tag `db49896cf2` 精确匹配引擎。
- E0.2 主机/设备上最小构建 eLinux(DRM-GBM),链接现有 `libflutter_engine.so`,跑当前 `/opt/hmi` bundle。✅ → [`scripts/spike-elinux-drm-gbm.sh`](../scripts/spike-elinux-drm-gbm.sh)。
- E0.3 用 [`debug-frame-pacing.sh`](../scripts/debug-frame-pacing.sh) 测**同一首页动画**的 present 稳态帧率(对照 flutter-pi)。✅ → 公平 A/B：flutter-pi ~38–40fps，eLinux DRM-GBM+`ENABLE_VSYNC=ON` ~40fps；**均 <50fps**。`ENABLE_VSYNC=OFF` 不可用。
- E0.4 确认 Rockchip libmali 变体清单(`gbm` / `wayland-gbm`),评估 Weston 路径可行性。✅ → `wayland-gbm`（bifrost-g52-g24p0）现成；SDK 已有 weston 包。
- E0.5(条件)若 E0.3 未达标,最小引入 Weston + eLinux Wayland backend,复测帧率。✅ 基础设施 + present 探针完成；**C≈41fps vs pi≈24fps，硬门控 ≥50 未过**（见 spike 报告 §5）。
- **产出**: [`embedder-migration-spike-e0.md`](embedder-migration-spike-e0.md) — **否决 B；方向锁定 C**；≥50fps 留待 E3/调优或 P5.1。

### E1 — Buildroot 打包 ✅（量产：Weston 镜像）

- E1.1 新增 `overlay/buildroot/package/flutter-embedded-linux/`(prebuilt `.mk`；交叉编译见 `scripts/build-flutter-embedded-linux.sh`)。✅
- E1.2(仅 C)新增/启用 `weston`、`wayland`、`wayland-protocols`,并切换 libmali 到 `wayland-gbm` 变体;新增 `chips/lws_hmi_wayland.config`。✅ — **默认 defconfig include**；`make build-rootfs` 注入 Weston 栈（flutter-pi 备选已移除）。
- E1.3 prebuilt 导出流程 + `make check-prebuilt` 纳入新包。✅（仅 wayland fragment 启用时校验）。
- E1.4 版本文件 `overlay/buildroot/flutter-embedded-linux.version`。✅ (`db49896cf2`)

**Product rootfs:**

| 目标 | 嵌入器 | Mali |
| ---- | ------ | ---- |
| `make build-rootfs` | Weston + `flutter-wayland-client` | `wayland-gbm` |

`post-build` 校验 Weston/client 存在，并清除遗留的 `flutter-pi` / `display-stack` stamp。`hmi-launch.sh` 固定走 Weston 路径。鼠标偏好：`apply-mouse-settings` 写 conf；Weston 下会重启 `hmi` 使 ini 生效。视觉 DPR 对齐在 Dart（`LwsHmiApp` FittedBox≈1.358）。

**产品决策（2026-07）：** 板端验证 Weston 在实时高斯模糊等场景下帧率更高更稳 → **Weston 为唯一量产栈**（flutter-pi / display-stack 分支已移除）。

### E2 — 输入 / 光标平权 🔲

- E2.1 按 §7.2 checklist 逐项验证并补齐(文本光标、键盘 LED/重复、鼠标加速/滚动/尺寸、BT 轴交换、触摸、电源键)。🔲
- E2.2 `cyber_hal` 鼠标偏好在新栈下的落地(R7)。✅ — `board_profile` 声明 `apply_mouse_settings`；helper 写 conf + Weston `weston.ini`/`[libinput]`；`scroll_speed`/`pointer_axes` 不映射（Weston 忽略）。
- E2.3 旋转(`landscape_left` / `lcd0_rotation=90`)在新栈下对齐。🔲 — Weston 路径已用 compositor transform。

### E3 — 运行时集成 🔄

- E3.1 改造 `hmi-launch.sh` / `hmi.service`:以 eLinux 命令行(或 Weston + 客户端)启动;保留 orientation、SSL_CERT、ALSA、LED 清理逻辑。✅（分支启动；unit 名仍为 `hmi.service`）。
- E3.2 (仅 C)Weston 配置(单客户端全屏、禁用 shell 装饰、splash handoff、背光/DPMS)。✅ → **`desktop-shell.so`**（非 kiosk）：`panel-position=none` + `background-image=/usr/share/hmi/boot-splash.png`（**横屏直立** 1280×800，`make build-boot-logo` 单独生成，非 portrait `logo.bmp`）。kiosk-shell **无** `background-image`，仅纯色 → DRM 接手后黑/白空档。运行时 ini：`weston-hmi-config.sh` → `/run/user/0/weston.ini`；静态/post-hook：`etc/xdg/weston/weston.ini` + `91-weston-ini.sh`。Flutter：`flutter-wayland-client --fullscreen`。
- E3.3 boot KPI 实测与优化(R3);对齐 [`boot-verify.sh`](../overlay/board/rockchip/common/rootfs-overlay/usr/libexec/board/boot-verify.sh)。🔲 — **已知**：Weston 在 `Output enabled` 时即清掉内核 `drm_logo`（约早于 Flutter 首 present ~1.6–2.2s）；靠 desktop-shell 背景图桥接，不等同 flutter-pi「logo 留到首帧」机制。

### E4 — 验收与切换 🔲

- E4.1 §9 验收全过。🔲
- E4.2 灰度: flutter-pi 包与备选 rootfs **已移除**（2026-07-25）；仅 Weston 量产镜像。✅
- E4.3 更新主线规划(§5 显示栈、P3.2 收敛、P5.1)、README、AGENTS.md 重建表、`env-verify.sh`。✅（README/AGENTS/`make build-rootfs` 默认 Weston；env-verify 待补）。
- E4.4 归档本迁移(OpenSpec/文档)。🔲

---

## 7. 能力平权

### 7.1 复用（低风险）

- **引擎**:现有 `prebuilt/flutter-engine/3.24.4/arm64-release/libflutter_engine.so` + `icudtl.dat`(embedder API 共用)。
- **应用 bundle**:`/opt/hmi/lib/libapp.so` + `data/flutter_assets/`(meta-flutter 布局不变);`make build-app` / `make push-app` 迭代方式保留。
- **触摸/输入底层**:libinput 栈保留(DRM backend 直用;Weston 亦用 libinput)。

### 7.2 输入/光标补丁平权 checklist（对应 flutter-pi 0001–0010）

| 现补丁 | 能力 | 新栈落点(待 E2 确认) |
| ---- | ---- | ---- |
| 0001 | 文本框方向键移动光标 | eLinux text input plugin 是否已覆盖 |
| 0002 | 键盘 Num/Caps LED 同步 | Weston/libinput 或 eLinux |
| 0003 | 软件按键自动重复(660/40ms) | Weston 键盘 repeat 或 eLinux |
| 0004 | Rockchip GBM 光标 stride 补齐 | Weston 光标 or eLinux GBM |
| 0005 | 鼠标偏好(加速/滚动/尺寸/轴)+ mtime 轮询 | `cyber_hal` + Weston/libinput(R7) |
| 0006/0007 | 光标图标密度/上采样 | Weston 光标主题 or eLinux |
| 0008 | 光标 clamp 到 display_size(旋转) | Weston 原生 |
| 0009 | BLE HOGP 键鼠轴 auto/swap | `cyber_hal` + libinput 配置 |
| 0010 | Rockchip drmModeMoveCursor 失败回退 | Weston 合成路径规避 / eLinux DRM |

---

## 8. 验证与验收标准

1. **帧率(硬指标)**:首页动画 present 稳态 ≥ 50fps(目标贴近 56fps),用 `debug-frame-pacing.sh` 连续 ≥10s 无明显回落;观感对齐 macOS/Android。
2. **输入平权**:§7.2 全部项通过;USB/BT 键鼠、Goodix 触摸、电源键、文本输入、旋转、鼠标偏好全部正常。
3. **启动 KPI**:`boot-verify.sh` 通过(Plan A 目标;若 Weston 触碰阈值需专项优化)。
4. **平台栈**:`env-verify.sh`(引擎路径、xkb、libmali/libdrm/libgbm;C 方案需补 Wayland 相关校验)。
5. **A/B 升级**:`make upgrade` 全流程不回退。
6. **资源**:内存占用在设备可接受范围(记录基线对比)。

---

## 9. 回退方案

- flutter-pi 包与备选 rootfs **已移除**（2026-07-25）。

---

## 10. 与主线规划的关系

- 本迁移把主线 [`flutter-linux-hmi-plan.md`](flutter-linux-hmi-plan.md) §5「显示栈(DRM,非 Wayland)」与 §1.1「量产显示栈仍为设备侧 flutter-pi + DRM」**调整为 eLinux(+可能 Weston)**;需在迁移落地后同步更新该文档。
- 与 **P3.2 模拟器**（**QEMU** + Weston + flutter-embedded-linux；原计划 UTM 已弃用）**收敛为同一嵌入器**；设备与模拟器共用 Weston + eLinux。
- 可与 **P5.1(引擎 3.24→3.41)** 合并评估:换嵌入器与升引擎都涉及 embedder API,一并规划可减少一次大改。

---

## 11. 开放问题

1. ~~eLinux 与 3.24.4 引擎的确切兼容 tag?是否必须升级引擎(牵动 P5.1)?~~ → **E0 已关闭**：tag `db49896cf2`；spike 无需升引擎。
2. ~~Rockchip 为本 SoC 提供哪些 libmali 变体?`wayland-gbm` 是否现成?~~ → **E0 已关闭**：`gbm` / `wayland-gbm`（及 x11 组合）均在 `external/libmali`。
3. 方案 C 下 Weston 的启动开销能否压进 boot KPI?
4. 触摸在 DRM-GBM(无 Weston)下 eLinux 的多点/坐标旋转是否与现状一致?（B 已否决为终态，降为次要）
5. 是否需要保留 GStreamer 视频插件路径(当前默认关闭,RTSP 可选)在新嵌入器下的等价能力?
