## Why

开机自检今天按 **进程一次**（`BootSelfCheckGate.isCompletedInProcess`）门控，所以每次 `hmi.service` 重启、`push-app`、或调试重启都会再次弹出。产品语义应是 **本机上电/重启后第一次打开 HMI 时显示**；同一次系统启动内再次拉起 HMI 不应再打扰操作员。

## What Changes

- 将自检触发门控从 **once-per-process** 改为 **once-per-boot**（系统启动周期内最多显示一次）。
- 在同一次开机内：`systemctl restart hmi`、崩溃重启、热推 app 后再次进入 Home **不再**显示自检对话框。
- 真正断电再上电或整机 reboot 后，若 Misc「Show Startup Self-Check」仍启用，则下一次首次进入 Home **再**显示。
- 进程内二次进入 Home 仍跳过（保留现有 in-process 门闩，避免同进程重复）。
- Misc 偏好关闭 /「不再显示」行为不变。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `product-boot-self-check`: 触发语义从「每进程首次 Home」改为「每系统启动首次 Home」；补充同 boot 内 HMI 重启跳过场景。

## Impact

- App：`BootSelfCheckGate` / `BootSelfCheckCoordinator`（及对应单元测试）；可能新增 boot 级 marker 读写（建议落在已有 `/run/hmi/` tmpfs，随 reboot 清空）。
- Spec：`openspec/specs/product-boot-self-check/spec.md` 需求文案与场景更新。
- Overlay / Buildroot：预期无改动（`/run/hmi` 已由 `hmi-launch.sh` 创建）。
- 操作员：日常 `make push-app` / 重启 `hmi.service` 不再反复看到开机自检。
