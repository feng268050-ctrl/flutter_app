# FrostUI Dialog + Keyboard 毛玻璃背景

Dialog 与自定义 Keyboard 各自按**当前 screen bounds** 从底层业务页面采样并高斯模糊。采样源不得包含 Dialog、Keyboard、Scrim、Mask、Blur Layer 等浮层。

详细排障与历史审计见 [`frostui-dialog-backdrop-fix-guide.md`](frostui-dialog-backdrop-fix-guide.md)。

---

## 核心规则

| 规则 | 说明 |
|------|------|
| 双 surface 独立采样 | `DIALOG_CARD` 与 `IME_KEYBOARD` 各持一份 bitmap，互不复用 |
| 全键盘种类共用面板 blur | QWERTY、123 / #+= 符号层、专用数字键盘 B 均走 `ImeKeyboardBackdropHost`，不只全局 QWERTY |
| 按 anchor 采样 | 以卡片/键盘当前屏幕区域为 anchor，不用全屏旧图硬贴 |
| IME 后必须重采 | 键盘弹出、隐藏或高度变化导致 Dialog 抬升后，等布局稳定再重采 Dialog，**禁止**只调 matrix 复用键盘前的 bitmap |
| 采样时隐藏浮层 | 截图前 `INVISIBLE` 掉 Dialog、Keyboard、Scrim 等，避免递归模糊与透视错位 |
| 采样时机克制 | 仅在首次稳定、IME 稳定、bounds/屏幕变化时采样；**不要**每次按键触发 blur（RK3566 易卡顿） |

---

## 视图层级

```
ImeHost
└── ImeKeyboardTouchHost
    ├── ImeKeyboardBackdropHost   ← 键盘毛玻璃（底层）
    └── ComposeView               ← 键盘按键（上层）

Dialog overlay
└── FrostCardView                 ← Dialog 毛玻璃（applyFrozenBackdrop / LOCAL capture）
```

---

## 采样时机（数据流）

```
Dialog attach
  → deferFrozenBackdropUntilIme（有键盘输入时不抢先采 Dialog）

Keyboard show / hide / 高度变化
  → 布局稳定（双 post 或 layout listener）
  → FrostOverlayHost.refreshFrozenBackdropAfterIme()
      ├─ DIALOG_CARD：按当前卡片 bounds 重采 → FrostCardView
      └─ IME_KEYBOARD：按键盘 bounds 重采 → ImeKeyboardBackdropHost.applyLocalBackdrop()

Dialog bounds 变化（抬升、footer 展开等）
  → notifyDialogCardBoundsChanged → 对应 surface 重采
```

开机自检等动态增高场景：默认走 `FrostOverlayHost` AUTO 路径；若需 footer 定稿后再采，可单独用 `deferFrozenBackdropUntilManualCapture` + `captureFrozenBackdropAtAnchor()`（仅自检 dialog 使用，勿泛化）。

---

## 关键模块

| 模块 | 职责 |
|------|------|
| `FrostOverlayHost` | 会话管理、双 surface 采样调度、`refreshFrozenBackdropAfterIme` |
| `FrostBackdropSurface` | `DIALOG_CARD` / `IME_KEYBOARD` 枚举 |
| `FrostBackdropCapture` | 按 anchor 区域截图，支持 `hiddenViews` 隐藏浮层 |
| `FrostBackdropSnapshot` | 截图 + 高斯模糊管线 |
| `FrostCardView` | Dialog 卡片展示冻结/LOCAL 背景 |
| `ImeKeyboardBackdropHost` | 键盘底层模糊展示 |
| `ImeKeyboardOverlay` | 组装 backdrop + Compose 键盘，触发 IME 后刷新 |
| `FrostUiDialogBridge` | Java 侧 IME 回调桥接到 `FrostOverlayHost` |

绘制根节点统一用 `FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot)`，**不要**对 `overlayRoot` 整树 `draw()`。

---

## 常见错误

1. **复用键盘前的 Dialog bitmap** — Dialog 抬升后背景内容与新位置错位（最常见 bug）。
2. **采样包含浮层** — 出现重影、递归模糊。
3. **matrix-only 刷新** — 有位移变化时必须 invalidate 并重采，不能只 `applyFrozenBackdropToOverlays`。
4. **工程师页 LOCAL target 抢会话快照** — `FrostCardView` 在 dialog overlay 内应优先会话 frozen bitmap，见 fix guide 中 `applyDialogSessionFrozenBackdropIfAvailable` 讨论。

---

## 验证

- 打开带键盘的输入对话框（如工艺参数名称、数值输入、WiFi 密码），检查 **各类键盘**（QWERTY、123、专用数字 B）面板均有模糊而非纯色底。
- 键盘弹出/收起前后 Dialog 背景不应漂移。
- logcat 过滤 `FrostBackdrop` 查看 `refreshFrozenBackdropAfterIme`、capture mode 与 generation。
