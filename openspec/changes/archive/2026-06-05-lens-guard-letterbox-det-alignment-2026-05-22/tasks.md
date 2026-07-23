## 1. 引擎交付物与配置

- [ ] 1.1 从 lensinspector 领取含 `det_raw_head`、**ROI 700→640** 后处理的新 `libai_<version>.zip`（三件套 + `config.yaml`）— **运维**：见 `docs/LENS_GUARD_ROI640_ALIGNMENT.md` §3
- [x] 1.2 更新 App ai-library manifest / `jniLibs` 与 bundled `assets/config.yaml`；确认 `algorithm.stain_score_mode: logits`
- [x] 1.3 升级步骤文档：`nativeDestroy` → `nativeCreate`；参考引擎 `check/ROI640_PARITY.md`

## 2. 推帧路径（禁止 App 二次几何）

- [x] 2.1 移除 `LensGuardManager` 对 `AiI420Letterbox640` 的生产调用；始终推**全帧** I420
- [x] 2.2 在 `deliverI420Payload` 增加 **width ≥ 1265 且 height ≥ 810** 校验（2026-05-22 ROI），不满足则跳过推帧并 WARN
- [x] 2.3 删除或废弃 `CameraConfig.PREF_AI_INPUT_LETTERBOX_640`、`DevActivity.toggleAiLetterbox640`、`AiI420Letterbox640.java`
- [x] 2.4 清理注释：引擎为**中心裁 640**（非 App letterbox）；回调坐标已为全图 xyxy

## 3. Overlay 与坐标契约

- [x] 3.1 确认 `parseBoxes` / `DetectionOverlayView` 按**全图**像素绘制，**不**加 crop_offset、**不**限制在中心 640 子区域
- [x] 3.2 确认离线 `toOverlayBox` 仅按 JPG 全宽全高归一化
- [x] 3.3 删除或修正代码/文档中「整帧 LetterBox 到 640」的错误表述

## 4. 文档对齐（2026-05-21 简版）

- [x] 4.1 更新 `LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`：预处理=中心裁 640 + 全图回调坐标；引用 `APP_ALIGNMENT_BRIEF.md`
- [x] 4.2 更新 `docs/LENS_GUARD_APP_INTEGRATION.md` 推帧/框坐标/最小尺寸小节
- [x] 4.3 新增 `docs/LENS_GUARD_ROI640_ALIGNMENT.md`（指针：引擎 `APP_ALIGNMENT_BRIEF.md`、`ROI640_PARITY.md`）

## 5. 可选诊断与 sibling 变更

- [x] 5.1 （可选）`LensGuardConfigParser` 解析 `stain_score_mode`，非 `logits` 时 WARN
- [ ] 5.2 与 `lens-guard-engine-alignment-2026-05-19` 合并台架：det-only + 离线 JNI + ROI640 overlay

## 6. 验收（APP_ALIGNMENT_BRIEF §6）

- [ ] 6.1 **1920×1080** 实机：`preview_det` 框在全图对准污点（含 ROI 外区域若存在检出）
- [ ] 6.2 **1280×720** 实机：同上
- [ ] 6.3 离线 AI Vision：JPG/推理 MP4 overlay 与全图对齐
- [ ] 6.4 确认 1920×1080 推帧；未对 <1265×810 推帧；logcat mask center 885/430
