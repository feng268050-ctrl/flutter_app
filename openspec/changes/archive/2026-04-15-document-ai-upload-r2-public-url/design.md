## Context

AI 上报图片写入 R2 后，开发侧通过 R2 **public bucket 域名**（`pub-...r2.dev`）验证对象是否存在。对象键已与协作方统一为含 `{type}` 与日期分段的路径。

## Goals / Non-Goals

**Goals:**

- 公共 URL = `https` + 固定 pub host + `/` + **唯一对象键**。
- 对象键规范：`uploads/ai/{staging|release}/{type}/{yyyy-mm-dd}/{sn}/{uuid_filename}`（日期段为日历日，如 `2026-04-15`）。

**Non-Goals:**

- 不改动工艺视频 presign 链路。
- 不在本文档内实现 App multipart 上传代码。

## Decisions

1. **公共基址**：`https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev`（开发联调；生产策略另定）。

2. **对象键**：保留 `{type}` 段（当前接口层 `type` 多为 `0`），与 `upload.md` 4.1 一致；Worker 不信任客户端环境，但 `type` 来自表单与业务分类。

3. **日期段命名**：文档占位写 `{yyyy-mm-dd}`，实现上等价于 ISO 日期 `yyyy-MM-dd` 的路径字符串。

## Risks / Trade-offs

- [风险] 公共读暴露对象 — Mitigation：开发桶或限时公开；生产改用私有 + 签名 URL 若需要。

- [风险] 与 Worker 实现不一致 — Mitigation：以 Worker 实际写入的 `object_key` 为准，文档随发布同步。

## Migration Plan

- `upload.md` 已含对象键规则；补充 public URL 小节并保持示例一致。

## Open Questions

- 生产环境是否改用自定义域名替代 `pub-...r2.dev`。
