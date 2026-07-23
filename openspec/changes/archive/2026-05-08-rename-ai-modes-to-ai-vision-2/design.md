## Context

当前 Device detection 页面存在四类一致性问题：一是顶部入口文案仍为 `AI Modes`，与设备端 `AI Vision` 命名不一致；二是页面保留了顶部双开关区与右侧三按钮区等冗余控制块；三是该区域视觉风格与设备端在配色、留白和层级上不统一；四是右侧画面未明确为实时视频流承载区。该变更涉及 UI 文案、结构裁剪、样式对齐与视频流显示承载，不改变检测核心流程或后端协议。

## Goals / Non-Goals

**Goals:**
- 统一 Device detection 页面 AI 入口及标题文案为 `AI Vision`。
- 移除截图框选的冗余区域，保留核心信息展示与必要操作路径。
- 让页面 AI 区域视觉风格与设备端保持一致（颜色、圆角、间距、信息层级）。
- 保留左侧“工作模式信息区”用于展示当前工作参数与状态。
- 让右侧主画面支持并稳定显示实时视频流。
- 保持现有检测功能和数据流不变，避免引入行为回归。

**Non-Goals:**
- 不重构 AI 推理逻辑、设备通信协议或告警判定逻辑。
- 不引入新的业务流程、权限模型或后端 API。
- 不扩展到与截图无关的页面全面改版。

## Decisions

1. **文案统一采用 `AI Vision` 作为唯一展示词**
   - Rationale: 减少跨端术语差异，降低用户理解成本。
   - Alternative considered: 保留 `AI Modes` 并在设备端加别名；被否决，因为会持续制造双术语负担。

2. **采用“结构删除优先”策略处理框选区域**
   - Rationale: 用户明确要求“框选部分不要”，删除比隐藏更能避免误触、布局残留与维护负担。
   - Alternative considered: 仅设置 `visibility=gone`；被否决，因为会保留无用代码路径和状态耦合。

3. **样式对齐以设备端已有设计 token/规则为基准**
   - Rationale: 在不改业务逻辑前提下，最小代价获得一致的视觉语言。
   - Alternative considered: 单页局部微调；被否决，因为容易形成新的风格分叉。

4. **多语言资源同步更新**
   - Rationale: 工程当前存在多语言资源目录，文案统一必须覆盖默认/英文/中文资源。
   - Alternative considered: 仅改默认语言；被否决，因为会导致语言切换后不一致。

5. **页面分区策略：左信息、右视频**
   - Rationale: 用户明确要求左侧展示工作模式，右侧承载实时视频流，职责分区更清晰。
   - Alternative considered: 左右区域都可切换成信息/视频混合；被否决，因为会降低扫描效率并增加交互复杂度。

6. **实时流实现采用 RTSP + Media3 RTSP source**
   - Rationale: 设备侧摄像头以 RTSP 输出，应用端需由 Media3 ExoPlayer + RTSP source 直接消费。
   - Alternative considered: 仅保留基础 ExoPlayer 依赖；被否决，因为无法识别 RTSP 内容类型并会触发运行时崩溃。

## Risks / Trade-offs

- **[Risk] 布局删除引发约束链断裂或空白区域异常** → **Mitigation**: 同步清理关联容器和 margin，逐屏校验布局预览与运行态。
- **[Risk] 文案替换遗漏导致局部仍显示 `AI Modes`** → **Mitigation**: 通过全文检索和 UI 冒烟清单覆盖入口、标题、Tab 文案。
- **[Risk] 风格对齐主观性导致验收分歧** → **Mitigation**: 以设备端截图为基准，围绕颜色、圆角、间距、层级制定可观察验收点。
- **[Risk] 实时视频流接入后出现黑屏/卡顿** → **Mitigation**: 明确加载态与失败态占位，增加流初始化与重连日志，做基础性能冒烟验证。
- **[Risk] 缺少 RTSP source 依赖导致点击 AI Vision 直接崩溃** → **Mitigation**: 构建依赖强制包含 `media3-exoplayer-rtsp`，并将该项纳入发布前检查清单。

## 实时流落地清单（How-to）

- 流地址：使用设备配置中的 `CameraConfig.CAMERA_RTSP_URL`（`rtsp://...`）。
- 播放器能力：`PlayerView + ExoPlayer`，并确保应用依赖含 RTSP source。
- 生命周期：`onResume` 开始拉流，`onPause/onDestroyView` 暂停并释放，避免泄漏与重复初始化。
- 状态可视化：至少包含 `Loading`、`Unavailable/Failed`、`Reconnecting` 三种态。
- 验收基线：点击 `AI Vision` 不崩溃；PID 不重启；无 `No suitable media source factory` 崩溃栈；有稳定画面或明确状态提示。
