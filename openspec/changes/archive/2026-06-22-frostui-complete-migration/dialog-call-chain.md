# Dialog 栈迁移对照（E.1 / E.5）

**目标命名**（对齐 `FrostButton` / `FrostButtonView`）：公开 API 为 **`FrostDialog`**，内核在 `frostui.dialog`；legacy **`FrostedGlassDialog`** 已删除。

当前：`FrostDialog` 为 app 层 Java 入口；overlay / 快照 / prompt 实现在 `frostui.dialog`。

## 注册入口

`Application` 启动时调用 `FrostUiDialogBridge.register()`，向 frostui 注入：

| Registry | 实现 |
|----------|------|
| `FrostBackdropBlurRegistry` | `BlurUtils.blurBitmap`（RenderScript Gaussian，对话框冻结快照） |
| `FrostUiClickSoundRegistry` | `GlobalSoundManager::playClickSound` |
| `FrostPanelShellResources.shellBorderProvider` | `PanelShellDrawables.workStatusShellBorder` |
| `FrostPanelShellResources.shellFallbackProvider` | `PanelShellDrawables.workStatusShellFallback` |
| `FrostOverlayHostRegistry.panelShellInstaller` | `FrostPanelShell.install` |
| `FrostOverlayHostRegistry.frozenBackdropApplier` | `FrostCardView.applyFrozenBackdropIfAvailable` |
| `FrostCardBlurRegistry.*` | `FrostOverlayHost` 冻结快照 / overlay 计数 |

## 调用链（Prompt）

```
FrostDialog.prompt()
  → FrostOverlayHost.showPrompt()            [frostui]
    → FrostPromptDialogController            [frostui Compose]
    → layout: dialog_frost_prompt.xml → FrostCardView
```

## 调用链（Light 大面板）

```
FrostDialog / MachineStatusOverlay / WarnDialogUtil
  tone(FrostTone.LIGHT)
  → FrostOverlayHost.show(...)               [frostui]
    → layout: dialog_frost_light_overlay.xml
    → FrostPanelShell.install()              [frostui]
      → FrostBackdropSnapshot.captureAndBlur(EXTREME)
      → WorkStatusDialog* drawables          [app，经 FrostPanelShellResources]
      → shell border/fallback: PanelShellDrawables [frostui.border]
```

## 已走 frostui 的能力

- Overlay 生命周期、冻结 backdrop、IME 后刷新：`FrostOverlayHost`
- 全屏/卡片快照 + stack blur：`FrostBackdropSnapshot`
- Prompt Compose 内容：`FrostPromptDialogController`
- Light shell 编排：`FrostPanelShell`
- Shell 绘制：`PanelShellDrawables` / `PanelFillDrawable` / `PanelBorderDrawable`

## 仍留 app 层（可选后续 rename）

- `Frost*Dialog.java` 专用对话框（Date/Time/Number/WiFi 等）— 类名已 `Frost*`，spec 措辞待 H.4
- `FrostPopupMenu`（app 层；类名待后续 rename）

## Tone / Token

| Legacy（已删） | frostui canonical |
|----------------|-------------------|
| `FrostedGlassTone` | `FrostTone` |
| `FrostedGlassBlurIntensity/Tint` | `FrostBlurIntensity` / `FrostBlurTint` |
| `FrostedGlassBorderGradientCenter` | `BorderGradientCenter` |
| `FrostedGlassPanelDrawable` | `PanelFillDrawable` / `PanelBorderDrawable` / `PanelCompositeDrawable` |
