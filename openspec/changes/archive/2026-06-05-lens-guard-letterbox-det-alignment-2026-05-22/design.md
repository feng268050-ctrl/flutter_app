## Context

- **引擎简版**（`APP_ALIGNMENT_BRIEF.md`，2026-05-21）：训练/部署均为 **中心裁剪 640×640**（非整帧 letterbox）；`det_raw_head.rknn` P2/P3/P4、33600 anchors、stride `[4,8,16]`；后处理在 libai（反量化 → DFL → sigmoid → 640 画布 bbox → **加回 crop_offset** → NMS）。详见 `训练推理后处理对齐说明.md` §3/§8.3/§9、`check/ROI640_PARITY.md`。
- **App 现状**：`parseBoxes` / 离线 overlay 已倾向全图像素映射；`LensGuardManager` 可选 `AiI420Letterbox640`（默认关）与引擎几何**冲突**（禁止对全帧 letterbox）。`updateFrameSize` 仅校验 `> 0`，未强制 **≥ 640**。
- **历史误读**：本 change 初稿按「整帧 LetterBox」编写；以 2026-05-21 简版为准修正。

## Goals / Non-Goals

**Goals:**

- 推帧：全分辨率 I420，**w ≥ 640 且 h ≥ 640**；引擎内中心裁 + 坐标还原。
- Overlay：使用 native 全图 xyxy，**不**加 `crop_offset`、**不**按「中心 640 局部坐标」绘制。
- 关闭 App 侧 letterbox/裁切入帧路径。
- 同步 `config.yaml`（`stain_score_mode: logits` 等）与文档。

**Non-Goals:**

- 不实现 native 裁剪/DFL/NMS/等级。
- 不新增 JNI。
- 不替代 det-only / 离线 JNI（sibling change）。

## Decisions

### 1. 禁用 App 侧 I420 letterbox；引擎负责中心裁 640

**选择**：生产路径不向 `nativePushFrame` 推送 640×640 letterbox I420；移除 `AiI420Letterbox640` 调用与 Dev 开关。

**理由**：简版 §2 明确禁止对全帧 letterbox/拉伸作模型输入；引擎已中心裁。

### 2. Overlay：全图 xyxy，App 不加 crop 偏移

**选择**：实时 `parseBoxes`、离线 `toOverlayBox` 仅按帧/JPG 宽高映射；引擎已执行步骤 12「加回 crop_offset」。

**理由**：§1 结论：框已是整帧像素；§2 禁止按「仅中心 640 坐标系」画框。

### 3. 推帧最小尺寸 w,h ≥ 640

**选择**：`LensGuardManager` 在 `deliverI420Payload` 若 `width < 640 || height < 640` 则跳过推帧并打 WARN（或文档化子码流须 ≥640×640）。

**理由**：简版 §2 输入要求宽、高均 ≥ 640。

**备选**：仍推小帧由引擎处理 — **拒绝**：与引擎契约不一致。

### 4. config 与升级

**选择**：三件套 + `config.yaml` 同包升级；`stain_score_mode: logits`；destroy/create 重启会话。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 子码流 640×512 等 <640 高 | 配置 IPC ≥640×640 或跳过 AI 推帧并日志说明 |
| Dev 曾开 `ai_input_letterbox_640` | 默认关 + 发布说明 |
| 旧文档写 letterbox | 按 2026-05-21 简版统一改为 center crop + 全图回调 |

## Migration Plan

1. 升级含 ROI640 / raw-head 后处理的 `libai` zip + `config.yaml`。
2. App：关 Java letterbox、加 ≥640 校验、更新文档。
3. `nativeDestroy` → `nativeCreate`。
4. 台架：**1920×1080**、**1280×720** 全图 overlay 对准污点。

## Open Questions

- 1280×720 下 `crop_y=40`：App 无需感知，仅验收全图框对齐。
- 是否在 UI 提示「分辨率过低无法检测」— **建议**：仅日志 + 可选 Dev 提示。
