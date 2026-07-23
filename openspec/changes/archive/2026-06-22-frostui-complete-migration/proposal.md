# FrostUI 全面迁移与一致性审计

## Why

Card/Button 已迁移到 frostui，但仍有 legacy 绘制、dialog 门面、重复 token、个别页面未换组件、包结构不一致等问题。需要逐项核对 API/样式/引用/包路径，并完成剩余迁移。

## Scope

- **已 OK**：`FrostCardView`、`FrostButtonView`、Switch/Checkbox/Segment/CapsuleSlider/Slider（高级设置）、Home 时钟、Blur 捕获目标
- **待办**：FrostCardView 内 legacy drawable、dialog 栈、NumericStepper 样式字段、视频页 SeekBar、Picker 样式、QuickAction 命名、token 去重、点击音包位置等

## Non-goals（本 change 不做）

- 业务 dialog 语义重写（仅迁移到 frostui API）
- 资源文件全量 `frosted_glass_*` → `frost_*` 重命名（可后续独立 change）
