## Why

Monitor → Videos 在视频上传过程中使用系统级（System UI）进度弹窗，与整机 HMI 的视觉语言、遮罩与控件风格不一致，破坏沉浸感与品牌一致性。将上传进度反馈改为与应用内既有模式一致的自定义弹窗，可与其他设置类流程（如 WiFi 密码输入）对齐，并复用已验证的进度呈现方式。

## What Changes

- 移除或停止使用系统默认的上传/等待类 System UI 作为 Monitor → Videos 的上传进度反馈。
- 在应用内实现与 **WiFi 加密网络密码输入弹窗** 同一套容器与视觉规范（背景遮罩、圆角卡片、标题/说明排版、按钮或关闭规则等）的 **视频上传进度弹窗**。
- 弹窗内进度条在形态与交互上与 **OTA 升级流程中的进度条** 保持一致或共享同一实现/样式资源（SeekBar 样式、刻度语义、状态文案区域等按 OTA 现有模式对齐）。
- 上传完成、失败或取消时，弹窗的关闭与错误提示行为保持与当前业务逻辑等价（不削弱可发现性）。

## Capabilities

### New Capabilities

- `monitor-videos-upload-progress-dialog`: 定义 Monitor → Videos 场景下视频上传进行中时，应用内进度弹窗的展示条件、与 WiFi 密码弹窗的视觉一致性要求、进度条与 OTA 进度条的对齐方式，以及完成/失败/取消时的关闭与文案要求。

### Modified Capabilities

- （无）本变更为纯客户端 HMI 呈现；`device-ws-video-uploading` 等协议层规范不涉及 UI 形态，无需修改既有 spec 中的需求文本。

## Impact

- Android 应用模块中负责 Monitor / Videos 列表与上传入口的 Fragment、ViewModel 或 Service 层（当前触发 System UI 的位置）。
- 布局与主题资源：可能与 WiFi 密码对话框、OTA 升级 Activity 共享 `styles`、`drawable`、dimen 或抽取公共 dialog 容器组件。
- 字符串与无障碍：若新增标题/状态文案，需走现有 string 资源与 TalkBack 可读性约定。
