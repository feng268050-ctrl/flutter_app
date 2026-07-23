# AI Vision 双链路 RK3566 压测 Checklist (Task 4.3)

## 1. 前置条件

| 项 | 要求 |
|----|------|
| 设备 | RK3566 平板（非模拟器） |
| 构建 | `isNativeAiVisionStreamDetectEnabled()` = **true**（双链路压测）；焊接并行测 `isNativeWeldStreamDetectEnabled()` 可单独开 |
| Field test 日志 | `isAiVisionDualLinkFieldTestLoggingEnabled()` = **true**（同时启用 `AiVisionResolutionProfile`） |
| MediaMTX | 本机 relay 就绪，`rtsp://127.0.0.1:8554/camera/pr1` 有流 |
| OpenCV session | stain detect session active |
| IPC 子码流 | 1080p 或 720p H.264 Baseline（见 `docs/dual-stream-workflow.md`） |

```bash
make sync
# 改 flag 后重新 sync
```

## 2. 自动化采集（推荐）

```bash
# 终端 1：设备上打开 Monitor → AI Vision（不选过程视频），保持 live 预览 ≥5 分钟
ADB_SERIAL=<rk3566-serial> DURATION_SEC=300 \
  ./scripts/field-test/ai-vision-dual-link-stress.sh

# 输出目录 build/field-test/ai-vision-dual-link-*/ 含：
#   logcat.txt, top-samples.txt, meminfo.txt, thermal.txt, summary.txt
```

手动解析已有 logcat：

```bash
adb -s <serial> logcat -d | ./scripts/field-test/parse-ai-vision-dual-link-logcat.sh
```

## 3. 指标与通过标准

| 指标 | 采集 | 通过标准 |
|------|------|----------|
| Java 播放首帧 | `AiVisionDualLink` / `VIDEO_DISPLAYED firstFrameMs` | < **3000 ms** |
| 播放硬解 | `decodeType=1` (MediaCodec) | **必须**为 1 |
| 播放分辨率 | `LIVE_VIDEO_SIZE` | 与 IPC 子码流一致 |
| Native 首样本 | `detect_first_sample sinceSessionMs` | < **3000 ms** |
| Native decode | `StreamDetect` `decode_ms` | 记录基线；无持续 >500ms 尖峰 |
| Native detect | `detect_ms` / `e2e_ms` | 记录基线；500ms 调度稳定 |
| 双链路间隔 | `dual_link_first_sample_gap_ms` | 记录；无 >5s 异常 |
| Overlay 同步 | `overlay_sync busToOverlayMs verdict=pass` | **≤300 ms**（100–300 ms 容忍） |
| CPU | `top-samples.txt` | 连续 5 min 无 ANR；UI 可接受 |
| 内存 | `meminfo.txt` | 无持续增长泄漏 |
| 温升 | `thermal.txt` | 产品可接受（记录 ℃） |
| UI 流畅度 | 目视 | 连续平移/缩放无严重卡顿 |

## 4. 场景矩阵

| # | 场景 | 步骤 | 期望 |
|---|------|------|------|
| S1 | 双链路并行 | 进入 AI Vision live | `duplicate_rtsp=ai_vision_preview` + 两路首帧日志 |
| S2 | 播放持续 | 预览 5 min + 手势缩放 | 播放不中断；`decodeType=1` |
| S3 | Detect 失败隔离 | 模拟 PR1 断流（停 MediaMTX 或拔网） | Java 播放继续；overlay stale/错误态 |
| S4 | 离开 tab | `onPause` | native stop；无 PR1 Java detect client 复活 |
| S5 | 焊接并行（可选） | Engineer 激光 ON + AI Vision tab | coordinator holder 日志符合设计 |

## 5. 关键 logcat 过滤

```bash
adb logcat -s AiVisionDualLink AiVisionFragment StreamDetect StreamDetectOverlay
```

## 6. Sign-off 记录

填写 [`ai-vision-dual-link-field-test-record.md`](./ai-vision-dual-link-field-test-record.md)，结论：

- **PASS** — 可进入 4.5 field test 归档 / 6.2 E2E
- **FAIL** — 走 [4.4 过渡策略](./ai-vision-dual-link-checklist.md#过渡策略-44)（保持 native flag false，仅 Java 播放）

## 过渡策略 (4.4)

压测不通过时：保持 `isNativeAiVisionStreamDetectEnabled()` **false**（默认即 4.4 fallback）；AI Vision 仅 Java PR1 播放，stain overlay 隐藏；焊接路径可单独评估 `isNativeWeldStreamDetectEnabled()` C++ 单链路。
