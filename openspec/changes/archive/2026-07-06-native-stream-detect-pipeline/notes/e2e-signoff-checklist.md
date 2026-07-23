# E2E Sign-off Checklist (Tasks 6.1, 6.2, 6.4)

## 6.1 Weld native pipeline (RK3566 or emulator + relay)

**Flags:** `isNativeWeldStreamDetectEnabled() = true`

| Step | Expected | Pass? |
|------|----------|-------|
| Laser OFF → ON | `NativeStreamDetect` acquire weld; `session_start` | |
| 500 ms samples | `StreamDetect: sampled frame_id=` | |
| Burst | Saturated frame → 100 ms burst → restore 500 ms | |
| Stain alert | `OpencvStainDetectCoordinator` / L001 path | |
| Zero point | `ZeroPointDetectCoordinator` bus subscriber | |
| Laser OFF | pipeline stop; no leak after 30 s | |
| SSE client | `CameraAiHttpPublisher` start/running/stop | |

Logcat: `adb logcat -v time -s StreamDetect:I OpencvStainDetect:I ZeroPointDetect:I CameraAiHttp:I`

## 6.2 AI Vision dual-link (RK3566 only)

**Flags:** `isNativeAiVisionStreamDetectEnabled() = true`, field-test logging on

Use [`ai-vision-dual-link-checklist.md`](./ai-vision-dual-link-checklist.md) + stress script.

| Step | Expected | Pass? |
|------|----------|-------|
| Playback | `VIDEO_DISPLAYED decodeType=1` | |
| Dual-link | `duplicate_rtsp=ai_vision_preview` | |
| Detect | native `sampled` + overlay ≤300 ms | |
| Detect fail | playback continues | |
| 4.4 fallback | flags off → playback only, overlay hidden | |

If 6.2 FAIL → ship 4.4 fallback (default flags).

## 6.4 Deploy sign-off

```bash
ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync
# RK3566: ADB_SERIAL=<serial> make sync
```

| Item | Value |
|------|-------|
| Branch / commit | |
| Device | |
| `make sync` result | |
| Sign-off | |

Mark 6.1 / 6.2 / 6.4 in `tasks.md` when rows above are filled.
