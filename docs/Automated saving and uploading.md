# 自动化保存并上传漏检/误检图像方案

## 1. 目标

在无人工参与的情况下，由算法自动判断并保存以下图像：

- 自动疑似漏检图像；
- 自动疑似误检图像；
- 检测失败图像。

注意：

```text
被内部过滤掉的图像不等于漏检/误检图像，默认不保存、不上传。

```

---

## 2. 总体流程

```text
OpenCV 检测
  ↓
防误检后处理
  ↓
簇一致性校验
  ↓
漏检 / 误检 / 检测失败判断
  ↓
保存到 App 本地上传队列
  ↓
定期 HTTP 上传
  ↓
上传成功后删除本地任务

```

---

## 3. 状态定义

```kotlin
enum class StainAuditStatus {
    CLEAN,                          // 正常无污渍
    STAIN_CONFIRMED,                // 正常检出污渍

    INTERNAL_FILTERED,              // 内部过滤，不上传
    DETECT_FAILED,                  // 检测失败，上传

    AUTO_SUSPECTED_MISS,            // 自动疑似漏检，上传
    AUTO_SUSPECTED_FALSE_POSITIVE   // 自动疑似误检，上传
}

```

上传规则：


| 状态                              | 是否上传 | 说明        |
| ------------------------------- | ---- | --------- |
| `CLEAN`                         | 否    | 正常无污渍     |
| `STAIN_CONFIRMED`               | 否    | 正常检出      |
| `INTERNAL_FILTERED`             | 否    | 普通过滤帧，不上传 |
| `DETECT_FAILED`                 | 是    | 检测流程失败    |
| `AUTO_SUSPECTED_MISS`           | 是    | 自动判断为疑似漏检 |
| `AUTO_SUSPECTED_FALSE_POSITIVE` | 是    | 自动判断为疑似误检 |


V1 落地说明（与 `openspec/specs/stain-audit-auto-upload` 一致，并含磁盘收口）：

- **仅** native `code=-3` → `DETECT_FAILED` 入队；`code=-5` 不落盘上传。
- 与 Pictures 批量**同一 Work**：拷贝到 `files/ai_audit_inbox/<uuid>.jpg` 后 `AiUploadSingleImageWorker` → `postAiReport`（不走 `AiUploadDrainWorker` / `pending.json`）。
- 入队成功后立即删除 native `frame_*`；上传成功后 Worker 再删 inbox 副本。激光关 Grace / session stop 清理会话残留 `frame_*`。
- 入队节流默认 15s（`StainAuditUploadCoordinator.MIN_ENQUEUE_INTERVAL_MS`），节流丢弃的失败帧会删除其 `input_frame.jpg`。

---

## 4. 自动判断漏检

### 4.1 判断逻辑

使用「前后阳性夹中间阴性」的方式判断漏检：

```text
t1：检测到目标 A
t2：未检测到
t3：未检测到
t4：检测到目标 A

```

如果 `t1` 和 `t4` 属于同一个簇，则 `t2`、`t3` 可判定为：

```text
AUTO_SUSPECTED_MISS

```

---

### 4.2 必要条件

中间帧判定为漏检需要同时满足：

```text
1. 前后两帧都检测到目标；
2. 前后目标属于同一个簇；
3. 时间间隔在允许范围内；
4. 中间帧状态为 CLEAN / NO_TARGET；
5. 中间帧不是 INTERNAL_FILTERED；
6. 中间帧不是 OSD、边缘、已知干扰岛簇。

```

推荐参数：

```text
max_gap_frames = 5 ~ 15
max_gap_ms = 1000 ~ 3000
center_distance_threshold = 30 px
area_change_threshold = 50%

```

---

## 5. 被过滤帧处理

被过滤掉的帧默认不作为漏检上传。

示例：

```text
t1：检测到目标 A
t2：未检测到
t3：INTERNAL_FILTERED
t4：检测到目标 A

```

处理结果：

```text
t2 → AUTO_SUSPECTED_MISS，可上传
t3 → INTERNAL_FILTERED，不上传

```

原因：

```text
过滤帧可能是 OSD、边缘干扰、已知岛簇、小噪声等，
不能直接等同于漏检。

```

如后续需要分析“过滤过强导致漏检”，可单独增加状态：

```text
AUTO_SUSPECTED_MISS_BY_FILTER

```

但不建议第一版加入。

---

## 6. 自动判断误检

### 6.1 判断逻辑

主检测输出阳性，但簇稳定性不成立，则判定为疑似误检。

```text
主检测：STAIN_CONFIRMED
但簇校验结果：
  只出现 1 帧
  或位置跳动大
  或面积变化异常
  或命中已知干扰岛簇
  或连续 N 帧无法复现

```

则输出：

```text
AUTO_SUSPECTED_FALSE_POSITIVE

```

---

### 6.2 必要条件

疑似误检应满足：

```text
1. 主检测已经输出阳性；
2. 后处理或簇追踪认为该目标不稳定；
3. 不是普通中间过滤样本；
4. 不是检测失败；
5. 有明确的误检原因。

```

---

## 7. 检测失败判断

检测失败表示算法无法给出可靠结论，不属于漏检或误检。

常见场景：

```text
ROI 定位失败
圆拟合失败
连通域数量异常
有效区域为空
图像质量异常
关键中间结果为空

```

输出状态：

```text
DETECT_FAILED

```

检测失败图像直接保存并上传。

---

## 8. 本地保存路径

原始输入图：

```text
{filesDir}/lens_guard/opencv_stain_detect/live_stain_detect_<ts>/input_frame.jpg

```

进入上传队列时复制到：

```text
{filesDir}/ai_upload/yyyy/mm/dd/lens/tasks/<uuid>/image.jpg

```

同时写入任务文件：

```text
{filesDir}/ai_upload/yyyy/mm/dd/lens/tasks/<uuid>/task.json

```

`task.json` 示例：

```json
{
  "uuid": "xxx",
  "type": 0,
  "reason": "auto_suspected_miss",
  "source": "opencv_stain_detect",
  "created_at": 1782812923000,
  "primary_result": "CLEAN",
  "status": "AUTO_SUSPECTED_MISS",
  "cluster_id": 12,
  "cluster_hit_frames": 3,
  "cluster_cx": 512.3,
  "cluster_cy": 286.7,
  "cluster_area": 1380,
  "retry_count": 0
}

```

---

## 9. HTTP 上传

上传接口：

```http
POST /v1/devices/{sn}/ai-report

```

表单字段：

```text
type  = 0
image = image.jpg
stat  = task.json 内容

```

说明：

```text
App 只负责调用 ai-report 接口。
R2 对象路径由 Worker 生成，App 不拼 R2 key。

```

最终 R2 示例：

```text
uploads/ai/staging/0/{date}/{sn}/{uuid}.jpg

```

---

## 10. 定期上传策略

使用后台任务定期扫描上传队列。

推荐策略：

```text
每 15 ~ 30 分钟扫描一次 ai_upload 队列；
仅在有网络时上传；
上传成功后删除 task 目录；
上传失败保留任务并增加 retry_count；
超过最大重试次数后标记 failed，但不立即删除。

```

---

## 11. 核心伪代码

```kotlin
val primary = primaryDetector.detect(frame)

val auditResult = clusterGuard.update(
    frame = frame,
    primaryResult = primary
)

when (auditResult.status) {
    DETECT_FAILED,
    AUTO_SUSPECTED_MISS,
    AUTO_SUSPECTED_FALSE_POSITIVE -> {
        uploadQueue.enqueue(
            sourceImage = inputFrameFile,
            type = 0,
            reason = auditResult.status.name.lowercase(),
            stat = auditResult.toJson()
        )
    }

    CLEAN,
    STAIN_CONFIRMED,
    INTERNAL_FILTERED -> {
        // 不保存、不上传
    }
}

```

---

## 12. 最终结论

本方案的核心是：

```text
主检测负责业务结果；
簇追踪负责一致性校验；
前后同簇阳性夹中间阴性，用于自动判断疑似漏检；
主检测阳性但簇不稳定，用于自动判断疑似误检；
检测流程异常，单独作为检测失败上传；
内部过滤帧默认不上传。

```

最终只上传三类图像：

```text
AUTO_SUSPECTED_MISS
AUTO_SUSPECTED_FALSE_POSITIVE
DETECT_FAILED

```

不上传：

```text
CLEAN
STAIN_CONFIRMED
INTERNAL_FILTERED

```

