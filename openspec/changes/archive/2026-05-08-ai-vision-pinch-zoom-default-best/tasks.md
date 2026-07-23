## 1. 手势缩放基础能力

- [x] 1.1 在 AI Vision 视频区域接入双指缩放手势识别（ScaleGestureDetector）
- [x] 1.2 基于 Matrix/Transform 实现视频画面缩放，并确保 default=1x 初始化
- [x] 1.3 增加缩放倍率边界钳制（min=1x，max=待定占位常量）

## 2. default / best 状态策略

- [x] 2.1 增加 `bestThreshold` 占位常量并实现状态切换逻辑（default → best）
- [x] 2.2 在 AI Vision 右侧叠层显示当前缩放状态（default/best）
- [x] 2.3 预留并记录“best 阈值 / 最大倍率”回填点，便于测试后快速修改

## 3. 兼容性与稳定性验证

- [ ] 3.1 验证缩放过程中 RTSP 拉流不中断，重连逻辑不回归
- [ ] 3.2 验证 AI 状态叠层与检测框叠层在缩放场景下持续可用
- [ ] 3.3 在目标设备完成手势交互回归（首次进入 default、阈值切 best、上限钳制生效）
