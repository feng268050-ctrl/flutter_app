## 1. OpenSpec rename

- [x] 1.1 Ensure canonical spec is `openspec/specs/p32-qemu-guest/spec.md`; remove `openspec/specs/p32-utm-guest/`
- [x] 1.2 Update `docs/p32-emulator.md` and delete obsolete `docs/p32-utm-guest.md` redirect

## 2. QEMU launcher

- [x] 2.1 Add `build_input_args()` in `scripts/run-emulator.sh`: default `EMULATOR_INPUT=touch` → `virtio-multitouch-pci` bound to virtio-gpu display/head; `EMULATOR_INPUT=tablet` → legacy `virtio-tablet-pci`
- [x] 2.2 Remove unconditional `-device virtio-tablet-pci` from QEMU argv; wire `${INPUT_ARGS[@]}` after GPU device
- [x] 2.3 Update `print_hw_map` / startup logs to describe touch vs tablet mode and multitouch device

## 3. Guest compositor / cursor

- [x] 3.1 In `weston-hmi-config.sh` (or documented launcher hook), hide persistent software cursor when `lws.emulator=1` and no USB pointer HID is present
- [x] 3.2 Verify USB mouse passthrough still shows cursor and receives pointer events when attached

## 4. Kernel / bring-up validation

- [x] 4.1 Boot emulator; SSH → confirm multitouch node via `libinput list-devices` / `evtest` (ABS range matches `EMULATOR_XRES/YRES`)
- [x] 4.2 Manual smoke: HMI tap, drag-scroll, long-press on a control; confirm no mouse-grab required
- [x] 4.3 If multitouch missing, append required `CONFIG_INPUT_*` / virtio-input options to `overlay/kernel/rockchip/emulator-virtio.config` and rebuild kernel

## 5. Docs and OEM metadata

- [x] 5.1 Update `docs/p32-emulator.md`: touch input default, `EMULATOR_INPUT=tablet` escape hatch, hw map line for multitouch
- [x] 5.2 Update `oem/screens/virt/screen.json` `touch_notes` to describe virtio multitouch (not tablet pointer)
- [x] 5.3 If Makefile `help` / `docs/make-commands.md` mention tablet pointer, align wording

## 6. Regression

- [x] 6.1 Confirm `EMULATOR_INPUT=tablet make emulator` restores prior absolute-pointer behavior for debugging
- [x] 6.2 Confirm keyboard, audio, networking, and SSH hostfwd unchanged
