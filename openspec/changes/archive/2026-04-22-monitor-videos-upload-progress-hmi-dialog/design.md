## Context

- **当前实现**：`VideoUploadProgressDialog`（`app/.../common/utils/VideoUploadProgressDialog.java`）通过 `AlertDialog.Builder` 设置 `setTitle`、`setView(R.layout.dialog_video_upload_progress)` 与 `setNegativeButton(取消)`。内容区使用 `?android:attr/progressBarStyleHorizontal` 的默认 `ProgressBar`。调用方包括 Monitor 的 `ProcessVideoFragment`、`CameraController`、`DevActivity` 等。
- **目标参照**：WiFi 密码弹窗在 `WifiActivity.showPasswordDialog` 中构建——仅 `setView(dialog_wifi_password)`、无框架标题栏，内容根布局为深色面板（`#2C2D45`）、圆角外边距与 `ll_border` 输入区；窗口宽度在 `dialog.getWindow().setAttributes` 中设为 **1280** 以贴合 HMI。
- **进度条参照**：`activity_upgrade.xml` 中升级进行阶段使用 **不可交互的 `SeekBar`**，`android:progressDrawable="@drawable/advanced_seekbar_progress"`，配合 `thumbTint` / `progressTint` / `progressBackgroundTint` 与下方状态 `TextView`（24sp 白色文案）。

## Goals / Non-Goals

**Goals:**

- 上传进度反馈在视觉上归入与 WiFi 密码弹窗同一 HMI 家族：深色卡片、居中标题区、与整机分辨率协调的窗口宽度，避免 Material 默认对话框标题栏与按钮条外观。
- 进度控件在 drawable 与尺寸语义上与 OTA 升级阶段一致（复用 `advanced_seekbar_progress` 与同档 min/max height、背景 tint），状态文案区域与 OTA 状态行对齐（字号、颜色）。
- 保留现有 `updateProgress(int, CharSequence)` 与取消语义：取消仍须可用且继续触发现有 `OnCancelUploadListener`。

**Non-Goals:**

- 不改变上传管线、WorkManager/前台任务、`video.uploading` WebSocket 上报或 `ProcessVideoViewModel` 的进度数值来源。
- 不修改 WiFi 密码弹窗的 IME-only 提交规范（`wifi-password-connect-dialog` spec 仍独立）。
- 不要求将 OTA 的 `SeekBar` 抽取为独立库模块；仅在实现上优先复用布局属性与 drawable。

## Decisions

1. **对话框容器**：继续基于 `AppCompat AlertDialog`，但改为与 WiFi 一致的无标题内容驱动布局——不在 Builder 上使用 `setTitle`；标题放入自定义布局内的 `TextView`（可使用现有 `R.string.uploading_in_progress` 或等价资源）。窗口背景使用透明或全透明以露出与 WiFi 一致的 dim，必要时对 `dialog.getWindow()` 设置与 WiFi 类似的固定宽度（如 1280dp）及 `setBackgroundDrawableResource`/`setDimAmount`，以代码为准对齐 `WifiActivity.dialogOpen` 行为。
2. **取消操作**：WiFi 弹窗无底部主按钮；上传场景必须保留取消。在自定义布局底部增加 HMI 风格次要操作（例如与升级页 `Later`/边框按钮风格一致的 `TextView` 或 `Button`，或卡片内右侧文字链），并移除或隐藏框架自带的 `setNegativeButton`，避免「系统按钮条 + 自绘卡片」混搭。
3. **进度控件**：将水平 `ProgressBar` 替换为与 `activity_upgrade.xml` 同配置的 **`SeekBar`（`enabled=false`，同 `progressDrawable` 与 tint）**，在 Java 侧用 `setProgress` 更新；若需兼容旧布局 id，可在迁移期保留同名 id 映射到 `SeekBar` 或统一重命名并一次性更新 `VideoUploadProgressDialog`。
4. **布局组织**：扩展或替换 `dialog_video_upload_progress.xml`，使根容器背景、padding、标题与消息 `TextView` 的字号颜色向 `dialog_wifi_password.xml` 与 OTA 状态行靠拢；优先复用 `@drawable/ll_border` 或同一背景色常量，减少重复硬编码（可抽到 `colors.xml` / theme 若已存在同名语义）。

**Alternatives considered**

- **全屏 Fragment 替代 Dialog**：一致性强但改动调用面大，非本需求必要。
- **保留 `ProgressBar` 仅换皮肤**：`advanced_seekbar_progress` 针对 `SeekBar`/`LayerDrawable` 已在 OTA 验证，直接对齐 `SeekBar` 风险更低。

## Risks / Trade-offs

- **[Risk] 固定 1280 宽度在小屏或分屏上溢出** → **Mitigation**：与 WiFi 一致采用当前项目已接受的固定宽度策略；若存在 `smallestWidth` 分支，沿用 WiFi 或 Window 已有工具方法。
- **[Risk] 去掉框架 NegativeButton 后用户找不到取消** → **Mitigation**：卡片内取消控件使用与字符串资源 `cancel_text` 绑定的明显标签，并保持 `setCancelable(true)` / 返回键行为与现网一致。
- **[Trade-off] SeekBar 不可用时无障碍朗读** → **Mitigation**：对标题与消息区保留 `contentDescription` 或在消息中保留百分比文字（调用方已拼接）。

## Migration Plan

1. 在 `VideoUploadProgressDialog` 与对应布局上完成 UI 替换；各调用方无需改接口即可获益。
2. 手动验证：Monitor → Videos 触发上传、相机上传路径、Dev 调试上传路径；取消与完成、进程被杀后 dialog 生命周期。
3. 无服务端或数据迁移；回滚为恢复旧布局与 Builder 配置。

## Open Questions

- 是否在首版将「取消」做成与 OTA「Later」相同的 `@drawable/upgrade_btn_later_bg` 样式，还是仅用描边文字按钮；实现阶段按现有 drawable 复用难度选择即可。
