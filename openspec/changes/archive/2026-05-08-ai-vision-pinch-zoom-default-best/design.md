## Context

当前 AI Vision 右侧视频区域基于 `TextureView` + 实时流渲染，已具备稳定拉流、重连与状态叠层，但缺少手势缩放交互。现场用户需要在检测时快速放大细节，因此需要在不破坏既有拉流链路与叠层逻辑的前提下引入双指缩放，并定义 `default` 与 `best` 的状态切换规则。当前“best 阈值”和“最大倍率”尚未冻结，需要先支持配置位与占位默认值，等待测试确认后回填。

## Goals / Non-Goals

**Goals:**
- 在 AI Vision 视频区域实现双指放大/缩小（pinch zoom）交互。
- 首次进入页面时缩放状态固定为 `default`，倍率为 1x。
- 缩放达到阈值时状态切换为 `best`，并可实时反馈当前状态。
- 支持最大倍率限制与越界钳制，保证交互稳定可控。
- 与现有 RTSP 拉流、AI 状态叠层、检测框叠层兼容，不引入回归。

**Non-Goals:**
- 不在本次设计中定义最终业务阈值（`best` 触发倍率）与最终最大倍率（由测试结论决定）。
- 不改造推理协议或 Native 返回结构。
- 不引入新的后端接口或远程配置系统。

## Decisions

1. **基于 `TextureView.setTransform(Matrix)` 实现画面级中心数字缩放**
   - Rationale: 当前摄像头为定焦摄像头，本功能仅以视频区域中心为锚点放大/缩小已渲染视频画面，不控制摄像头光学焦距，也不支持手动拖动画面；现有页面已使用 `TextureView`，可在不替换播放组件的情况下实现缩放。
   - Alternatives considered:
     - 替换为 `GestureImageView` 类第三方控件：引入依赖与维护成本，否决。
     - 切回 `PlayerView` + ExoPlayer 手势：当前已迁移 EasyPlayer，链路不匹配，否决。

2. **手势模型采用手动双指距离计算**
   - Rationale: 目标屏幕上系统原始 `scaleFactor` 对收缩手势反馈不稳定，改为按每帧两指距离增量计算倍率，并通过较低灵敏度、死区过滤、最小更新步长与单步倍率上限限制缩放速度和噪声抖动，确保放大和缩小都可响应且不会过快。
   - Alternatives considered:
     - 自研多点触控解析：复杂度高、易出边界 bug，否决。

3. **状态判定策略：`zoom == 1x` 为 `default`，`zoom >= 1.60x` 为 `best`**
   - Rationale: 规则清晰，便于测试与产品沟通；首次跨过 `1.60x` 时将倍率停在阈值 500ms，并让右上角 `best` 标签轻微闪烁，帮助用户明确感知已进入 `best`。停顿期间持续刷新双指距离基准，避免停顿结束后画面突然跳变。
   - Alternatives considered:
     - 多档位（default/mid/best）：当前需求仅需两档，先不扩展。

4. **参数占位：阈值与最大倍率以本地常量承载，后续仅改常量回填**
   - Rationale: `bestThreshold` 当前为 `1.60x`，`maxZoom` 当前为 `2.0x`；仅在 `1.0x / 1.6x / 2.0x` 三个档位显示右上角状态（`DEFAULT / BEST / MAX`），其他倍率隐藏状态标签。
   - Alternatives considered:
     - 立即接入动态配置：范围过大，超出本次需求。

5. **双击恢复 default**
   - Rationale: 当当前倍率大于 `1.0x` 时，用户可双击视频区域快速回到中心 `default/1.0x`，减少连续收缩操作成本。

6. **首次进入 AI Vision 显示三页缩放教学**
   - Rationale: 首次进入时在视频区域覆盖教学层，三页分别演示双指张开放大、双指收拢缩小、双击恢复 `DEFAULT`。每页持续循环当前页动画，用户通过上一页/下一页/完成手动切换；教学未完成前不启动 RTSP 视频流，完成后记录本地偏好并开始拉流，避免教学层与实时画面相互干扰。

## Risks / Trade-offs

- **[Risk] 高倍率下手势抖动或越界** → **Mitigation**: 使用最小/最大倍率钳制与平移边界限制。
- **[Risk] 缩放后叠层（AI 文本/检测框）视觉错位** → **Mitigation**: 保持叠层在视频容器坐标系内统一绘制并回归验证。
- **[Risk] 默认阈值与真实业务预期不一致** → **Mitigation**: 将 `bestThreshold`、`maxZoom` 作为显式常量并标注待回填。

## Migration Plan

- 该变更为前端交互增强，无数据迁移需求。
- 发布策略：先灰度到目标设备验证（含多分辨率与连续缩放压力）。
- 回滚策略：保留 `default=1x` 行为，手势入口可通过开关快速禁用。

## Open Questions

- `bestThreshold` 最终倍率值是多少（待测试反馈）？
- `maxZoom` 最终上限倍率是多少（待测试反馈）？
- 是否需要双击快速切换 `default`/`best`（当前非必需）？
