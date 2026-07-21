## Context

CyberIME（`packages/cyber_ime`）已提供应用内 overlay 键盘；物理布局经 `cyber_hal` `Keyboard` + XKB（目前仅 `us`/`ru`）。Settings Keyboard 页仍嵌入 Demo。产品需要四规格（ANSI US / DE QWERTZ / FR AZERTY / JIS）统一选择：虚拟预览 + 物理 XKB。参考：ANSI/ISO 打字区示意（无 F 键、无右侧 9 键小键盘）；AZERTY / JIS 键位图。

Constraints: flutter-pi + libxkbcommon；v1 layout apply 仍重启 HMI；CyberIME 不依赖 OEM IME；不在 Dart 侧重映射物理 HID scancode。

## Goals / Non-Goals

**Goals:**

- 产品枚举四规格；Settings 用 `CyberSegmentedControl` 切换并预览打字区。
- 同一偏好驱动 CyberIME Keyboard A 布局与物理 XKB `setLayout`。
- 文案提示：外接键盘必须选对规格，否则部分键无效。
- HAL 列表至少覆盖 `us` / `de` / `fr` / `jp`（含合适 model/variant）。

**Non-Goals:**

- 虚拟键盘做 80%/100%（F 键、导航块、数字小键盘）。
- 日文输入法候选栏 / 罗马字引擎完整化（JIS 虚拟层可先英数+符号；物理 XKB 负责日文键）。
- XKB 无重启热切换。
- 自动检测插入键盘的国别并改布局（可后续增强）。

## Decisions

1. **单一产品枚举 `ProductKeyboardProfile`**  
   值：`ansiUs` / `isoDe` / `isoFr` / `jisJp`。映射：
   | Profile | CyberIME layout set | XKB id | model (typical) |
   |---------|---------------------|--------|-----------------|
   | ansiUs  | ANSI QWERTY A       | `us`   | `pc105` |
   | isoDe   | QWERTZ ISO A        | `de`   | `pc105` |
   | isoFr   | AZERTY ISO A        | `fr`   | `pc105` |
   | jisJp   | JIS typewriter A    | `jp`   | `jp106` |

2. **虚拟键盘 = 现有 CyberIME UI + 布局数据 / KeyCode 字符映射层**  
   仅引入 regional layout 数据与统一 `CyberImeKeyCode` → 字符映射（base / shift / altGr）；不新增 F1–F12、导航块、右侧 NumPad（这些由 flutter-pi / XKB / cyber_hal 硬件输入层处理）。  
   Soft Keyboard A 仍基于现有 CyberIME panel（字母层 + `123` / `#+=`）；键帽与 commit 字符一律经 KeyMap 解析。物理键入继续走 XKB（同 profile 的 XKB id）；产品保证四规格下虚拟 KeyMap 与 xkeyboard-config 打字区字符对齐，**禁止**在 Dart 侧重映射 HID scancode。AZERTY AltGr / JIS 日文专用键在虚拟侧用 long-press / 符号层近似。

3. **Segment + 预览 + 独立 Apply / Restart**  
   Settings Keyboard：顶栏 `CyberSegmentedControl`（四段短标签：US / DE / FR / JP）。下方只读打字区预览随 Segment 切换（即时，不写盘）。默认选中当前已应用偏好。  
   - **Apply**：将所选 profile 持久化到 `keyboard.conf`（+ 同步 etc），并更新 CyberIME regional provider（软键盘立即跟布局）；**不**自动重启 HMI。  
   - **Restart**：写入恢复路由后重启 `hmi.service`，使物理 XKB 在 flutter-pi 初始化时生效；App 启动后恢复到 Keyboard 设置页。

4. **默认输入路径**  
   屏上输入默认 CyberIME。物理键盘事件仍走 flutter-pi/XKB；与 CyberIME 并存时，有物理键入可不强制关 overlay（保持现状除非已有冲突处理）。

5. **偏好存储**  
   物理侧继续 `keyboard.conf`。App 可用同一 `layout=` id 推导 profile；或额外 `/var/lib/hmi/keyboard-profile` — **优先单一 `keyboard.conf` layout id**，避免双源。

6. **与 cyber-ime ChineseGlobal**  
   本变更的「多规格」是物理/区域键位图，不是中英输入法语言。中文输入法仍由 `CyberImeLanguageProvider` 管；JIS/ANSI 是键帽排列。可同时存在。

## Risks / Trade-offs

- **[规格键帽不全]** AZERTY AltGr / JIS 假名键虚拟预览简化 → Mitigation：预览标注「打字区示意」；物理依赖 XKB 完整图。  
- **[选错布局]** 操作员混用德规键盘却选 US → Mitigation：Settings 固定提示文案。  
- **[重启闪烁]** XKB apply 重启 HMI → 沿用 dart-hal 恢复路由；确认对话框。  
- **[ru 退场]** Demo RU 不进产品 Segment → HAL 可保留 `ru` 供 Demo。

## Migration Plan

1. HAL 扩展 layouts + 单测。  
2. cyber_ime 四布局数据 + 按 profile 选 Keyboard A。  
3. Settings Keyboard 产品页（Segment + 预览 + 应用物理布局）。  
4. 板端：四规格切换预览；插 US/DE 实体键盘验证符号键。  
5. Rollback：HAL 列表回退；Settings 回 Demo section。

## Open Questions

1. Segment 标签用「US / DE / FR / JP」还是「美规 / 德规 / 法规 / 日规」？→ **已定：Segment 短码 + 下方完整名称。**  
2. 切换 Segment 是否立即 `setLayout`+重启？→ **已定：预览即时；独立 Apply（持久化 + 软键盘）与 Restart（物理 XKB）按钮。**  
3. JIS 虚拟层 v1 是否只做英数键帽、日文专用键仅物理？→ **已定：是。**
