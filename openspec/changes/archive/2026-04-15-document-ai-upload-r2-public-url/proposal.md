## Why

`upload.md` 定义了 AI 检测上报与 Worker 侧 R2 对象键规则；开发联调需要 **R2 公共可读 URL** 的拼法。规范已与协作方统一为单一对象键形态，避免与 Worker、文档多方表述分叉。

## What Changes

- **规范对象键（唯一真值）**：`uploads/ai/{staging|release}/{type}/{yyyy-mm-dd}/{sn}/{uuid_filename}`
- 在需求/对齐层面记录 **R2 开发用公共基址**：`https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev`
- **完整 HTTPS**：基址无尾 `/` + `object_key`（单斜杠拼接）；`{yyyy-mm-dd}` 路径段与常见 `yyyy-MM-dd` 日期格式化结果一致（如 `2026-04-15`）

## Capabilities

### New Capabilities

- `ai-upload-r2-public-url`: 定义 AI 上报图片在 R2 上的公共可读 URL 构成约定（开发联调用），对象键与 `upload.md` 4.1 节一致。

### Modified Capabilities

- （无：`device-r2-presigned-upload` 仍为工艺视频 presign，与本链路独立。）

## Impact

- 文档：`upload.md` 增补 R2 公共 URL 与上述对象键对齐。
- 应用代码：按需后续实现；对象键以 Worker 写入为准。
- 协作：公共 `r2.dev` 与桶绑定、读权限由运维/Worker 侧配置。
