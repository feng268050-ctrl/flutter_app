# 程序异常排查（摘要）

> 原文：[`../app_examine.md`](../app_examine.md)

## 一句话

记录 lws-ui 历史上 **UI 闪退、ANR、启动卡死** 等问题的根因与修复，供回归时对照。

---

## UI 闪退：LruCache 写入 null

**现象**：Fast Mode / Engineer Mode 点击 `Laser Enable` 后闪退。

**根因**：`putSerializableNoNotice(key, null)` — `LruCache.put(key, null)` 会崩溃。

**修复**：
- Fast / Engineer 两处改为 `remove(key)`
- `MemoryCacheManager.putSerializableNoNotice()` 全局兜底：`null` → `remove(key)`

---

## ANR：AI Vision 退出（2026-05-11）

**现象**：`DeviceMonitoringActivity` ANR，主线程卡在 `AiVisionFragment.onPause()` → `playerClient.stop()` → 无超时 `Thread.join()`。

**根因**：RK MediaCodec native 初始化阻塞时，`interrupt()` 无法打断，`join()` 拖死主线程。

**修复**：
- `AiVisionFragment`：后台线程 stop；`playerGeneration` 过滤旧回调
- `EasyPlayerClient.stop()`：`VIDEO_CONSUMER` / `AUDIO_CONSUMER` 最多等 1000ms
- `FrameInfoQueue.clear()`：唤醒等待线程

**验证**：退出后 log `Stopping EasyPlayerClient asynchronously`，无 ANR。

---

## 启动卡死：GPIO native 路径

**现象**：启动阶段 native 卡死/崩溃。

**根因**：`SignalLightController` GPIO 初始化链路，非 RKNN 本身。

**修复方向**：GPIO 失败降级不阻断主流程。

**临时绕过**：`adb shell setprop debug.lws.skip_gpio_init 1`

---

## 其他已知问题

| 现象 | 说明 |
|------|------|
| 图片推理 `-1007` | `nativeInferImageAndSave` JNI 缺失 |
| 返回码 `1` 但 Java 只认 `0` | 契约不一致，应统一成功=0、失败<0 |
