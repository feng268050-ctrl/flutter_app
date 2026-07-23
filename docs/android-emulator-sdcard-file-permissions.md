# 模拟器：`/storage/emulated/0` 下视频 `EACCES` / `chmod` 不生效

## 现象

- 应用打开 `/storage/emulated/0/...` 下某 MP4 报 **`EACCES` / `Permission denied`**（例如 `FileInputStream`、`MediaMetadataRetriever`）。
- 在 **`adb shell`** 里对 **`/storage/emulated/0/...`** 执行 **`chmod` / `chown`**，`toybox chmod` 显示成功，但 **`ls -la`** 仍显示旧权限/旧属主（例如仍为 `600`、`u0_a125`）。

## 原因（简要）

共享外部存储路径常经 **FUSE** 暴露；在部分模拟器/API 上，**对 `/storage/emulated/0/...` 直接改 inode 元数据不可靠或不反映到底层文件**，表现为「命令成功、列表不变」。

## 推荐做法（快速解）

1. **在底层路径上改权限/属主**（与 `/storage/emulated/0` **同相对路径**）：
   - **`/data/media/0/<与 sdcard 相同的路径>`**  
   - 例：  
     - 逻辑路径：`/storage/emulated/0/lws/movie/2026-04-17/xxx.mp4`  
     - 底层路径：`/data/media/0/lws/movie/2026-04-17/xxx.mp4`

2. **`adb root`**（模拟器一般可用）后执行：

   ```bash
   adb -s emulator-5554 root
   adb -s emulator-5554 shell chown <uid>:<gid> /data/media/0/lws/movie/2026-04-17/xxx.mp4
   adb -s emulator-5554 shell chmod 644 /data/media/0/lws/movie/2026-04-17/xxx.mp4
   ```

   - **`<uid>`**：目标应用 `userId`（`adb shell dumpsys package <包名> | grep userId`），需与文件属主一致，否则 **`600`** 下其他 UID 仍无法读。

3. **再确认** 用户可见路径：

   ```bash
   adb -s emulator-5554 shell ls -la /storage/emulated/0/lws/movie/2026-04-17/xxx.mp4
   ```

   此处应已变为期望的 **`rw-`** 与属主（如 **`u0_a135`**）。

## 与「仅缺 Android 运行时权限」的区别

- **`READ_MEDIA_VIDEO` / `READ_EXTERNAL_STORAGE`**：解决的是 **系统媒体访问策略**。
- **`600` + 属主为其他应用 / shell**：属于 **POSIX 权限**，需在设备上 **chmod/chown**（并优先在 **`/data/media/0`** 上操作）。

二者可能同时存在；先 **`ls -la`** 看属主与 mode，再决定改权限还是只申请运行时权限。

## 相关表（元数据重跑）

若需重跑 Worker 元数据上传，将 **`t_params_process_video.syncStatus`** 置为 **`0`**（`VideoSyncStatus.NOT_INITIATED`），且 **`videoId`** 非空；数据库文件见 `DatabaseConstant.DATABASE_NAME`（默认 **`lws_ui`**），包名 **`com.lasercyber.lws.ui`** 下 **`run-as` + `sqlite3`** 即可。
