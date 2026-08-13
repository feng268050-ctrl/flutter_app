## 1. OpenSpec rename

- [x] 1.1 Ensure canonical spec is `openspec/specs/p32-qemu-guest/spec.md`; remove `openspec/specs/p32-utm-guest/`
- [x] 1.2 Update `docs/p32-emulator.md` and delete obsolete `docs/p32-utm-guest.md` redirect

## 2. QEMU launcher

- [x] 2.1 Add `build_input_args()` in `scripts/run-emulator.sh`: default `EMULATOR_INPUT=touch` and `tablet` both attach `virtio-tablet-pci`; set cmdline `lws.emulator.input=touch|tablet` (touch enables guest bridge; tablet skips it). Do **not** use `virtio-multitouch-pci` as default — cocoa does not deliver host pointer to MTT
- [x] 2.2 Wire `${INPUT_ARGS[@]}` after GPU device (no unconditional duplicate tablet)
- [x] 2.3 Update `print_hw_map` / startup logs for touch-bridge vs tablet-pointer modes
- [x] 2.4 Pass `show-cursor=on` on cocoa/gtk display so Host pointer stays visible when Guest cursor is hidden

## 3. Guest touch bridge + compositor

- [x] 3.1 Ship `emulator-tablet-to-touch` (prebuilt + overlay libexec): grab virtio-tablet → uinput **LWS Emulator Touch** (BTN_TOUCH / MT) + **LWS Emulator Wheel** (`REL_WHEEL` / hi-res passthrough; no touch-flick)
- [x] 3.2 Add `emulator-tablet-to-touch.service` with `ConditionKernelCommandLine=lws.emulator=1` (and not `input=tablet`); preset enable; `hmi.service.d` **only** `After=` (never Condition/Requires on hmi)
- [x] 3.3 In `weston-hmi-config.sh`, hide Guest software cursor when emulator touch present and no USB pointer HID
- [x] 3.4 Enable `CONFIG_INPUT_UINPUT=y` in `overlay/kernel/rockchip/emulator-virtio.config`

## 4. Bring-up validation

- [x] 4.1 Boot emulator; SSH → `libinput list-devices` shows **LWS Emulator Touch** (and wheel device); tablet is grabbed
- [x] 4.2 Manual smoke: HMI tap, drag-scroll, long-press; host wheel/trackpad scroll smooth and direction matches host; no mouse-grab required
- [x] 4.3 Confirm stock `virtio-multitouch-pci` alone is insufficient on qemu-virgl+cocoa (document in design/docs)

## 5. Docs and OEM metadata

- [x] 5.1 Update `docs/p32-emulator.md`: touch = tablet + guest bridge + REL_WHEEL; `EMULATOR_INPUT=tablet` escape hatch; `show-cursor`
- [x] 5.2 Update `oem/screens/virt/screen.json` `touch_notes` to describe tablet + `emulator-tablet-to-touch`
- [x] 5.3 Align Makefile / make-commands wording if they still implied multitouch-only

## 6. Regression

- [x] 6.1 Confirm `EMULATOR_INPUT=tablet make emulator` restores absolute-pointer behavior (bridge no-ops)
- [x] 6.2 Confirm keyboard, audio, networking, and SSH hostfwd unchanged
- [x] 6.3 Confirm real hardware is unaffected (bridge Condition on emulator cmdline; hmi drop-in has no Condition)
