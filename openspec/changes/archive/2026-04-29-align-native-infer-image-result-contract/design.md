## Context

- `nativeInferImageAndSave` 用于单张图片诊断推理并写回结果图；YOLO 端已改为：**只要整条管线成功即返回 `0`**，检测等级（`CLEAN` / `LIGHT` / `HEAVY` 等）不再编码为函数返回码。
- App 侧 `LensGuardManager` 以 `NativeBridge.guardedInferImageAndSave` 的整型码判断成败，并可能将“业务检测结论”误等同于错误码。
- 需要与 native 对齐：错误码表、成功后的文件兜底校验、检测结论的独立通道（listener 或侧车 JSON）。

## Goals / Non-Goals

**Goals:**

- 统一 **成功 = `0`**；负值仅表示 **阶段失败**（参数、读图、推理、写盘）。
- App 提供 **稳定、可 localized 的错误文案**（`switch`/映射表），避免把原始负整数直接暴露给业务层 UI（除非 debug）。
- 成功返回 `0` 后仍 **校验结果图文件** 存在且非空（防御性；与 native 是否写盘一致）。
- 明确检测结论的 **一种或多种** 交付方式：优先复用 **现有 EventBus / listener**；可选 **同目录 `*_result.json`** 与结果图同名前缀。

**Non-Goals:**

- 不在这份设计里规定具体 UI 文案或完整 JSON schema 的每一个字段（由 spec 锁定 SHALL）；不强制同时实现 callback 与 JSON，只要满足 spec 中“至少一种”即可。
- 不在此变更中重写整段 RKNN 推理管线，仅调整 JNI 合同与 App 集成层。

## Decisions

1. **返回码表（native → Java）**  
   - `0`：成功（含任意合法检测等级下的成功落盘）。  
   - `-1`：参数/句柄无效。  
   - `-2`：读图失败。  
   - `-3`：推理失败。  
   - `-4`：保存结果图失败。  
   其他负值保留为 `NativeBridge` 层已定义的会话类错误（如 -100x），与 `guarded*` 的包装一致；文档中说明“诊断优先看 `RKNN_DIAG` 与负错误码映射”。

2. **检测结论出口**  
   - **方案 A（推荐）**：复用已有 `onCheckResult` / 等价事件，携带 `level`、`status`（`CLEAN`/`LIGHT`/`HEAVY` 等）、`message`。  
   - **方案 B（可选）**：在结果目录写出 `xxx_result.json`（与 `xxx_result.jpg` 对应），包含 `level`、`status`、`message`、`detections` 等。  
   实现顺序：先 A（与现有架构一致），B 作为增强或离线分析。

3. **App 错误文案**  
   集中 `nativeInferErrorMessage(int code)`（或同义私有方法），`-1`…`-4` 映射到固定英文/中文 key，避免散落字符串；未知码回退到通用句 + 数字。

4. **与旧 binary 混用**  
  通过版本与发布说明要求：**App 与 libai 同步升级**；可选在 `ensureLoaded` 后读 native 版本属性（若已有）做 mismatch 日志。

## Risks / Trade-offs

- [旧 libai 仍返回历史码] → 发版说明 + 版本门禁；测试矩阵覆盖新老组合或仅支持同 tag。  
- [仅 JSON 无 callback] → UI 不刷新直至轮询文件；优先 listener 路径。  
- [双通道同时存在] → 需约定优先级（通常事件优先，JSON 为落盘真源）。

## Migration Plan

1. 先合入 **native** 与 **App** 同一次发布或先 native 后 App（仅当 native 已向后兼容；本契约为 **BREAKING** 时须同事务发布）。  
2. 设备侧清缓存/重装或 OTA 全量；验证 `inferJpgAndSaveResult` 与 instrumented 测试。  
3. 回滚：回退到上一对 `libai` + App，或临时 feature flag（若引入）。

## Open Questions

- native 是否已在某 tag 稳定输出 `onCheckResult` 字段；若未实现，由 YOLO 在何 milestone 提供。  
- `*_result.json` 是否必须与本变更同事务交付，或列为 follow-up。
