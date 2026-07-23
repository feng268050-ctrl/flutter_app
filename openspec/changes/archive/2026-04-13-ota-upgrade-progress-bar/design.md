## Context

`UpgradeActivity` downloads the OTA ZIP on a worker thread (`writeZipToLocal`), then posts unzip/parse on the main thread. Controller firmware runs asynchronously (`DeviceUpgradeEvent`); APK handling runs in `controllerBardUpgradeEnd`. The layout uses a disabled `SeekBar` (`updating_start_power`, max 100) and a static **Updating** label. Progress updates today do not cover download or firmware time.

## Goals / Non-Goals

**Goals:**

- Show **byte-accurate** progress during HTTP download when `Content-Length` is a positive value.
- Show **localized** status lines: download phase and post-download phase, with **Chinese** as default strings and **English** provided via `values-en` (or equivalent).
- After download, **reset** progress to **0** and show the **system upgrade** copy until the controller step completes; then **50%**; after APK step completes, **100%**.
- When **silent APK install** runs on success, **hold** the upgrade-success UI for **≥ 3s**, then **start the app’s main/launcher activity** (same package, new task / clear-top as appropriate) so the user **re-enters the application immediately** with the updated APK—not only closing `UpgradeActivity`.

**Non-Goals:**

- Per-percent Modbus/firmware transfer progress (protocol does not expose a single UI-safe percentage in this change).
- Changing semver rules, manifest format, or silent-install semantics.
- Redesigning the whole upgrade screen beyond progress + status text.

## Decisions

1. **Download progress calculation**  
   - **WHEN** `HttpURLConnection.getContentLengthLong()` (or equivalent) returns **> 0**, progress SHALL be `min(100, (bytesWritten * 100) / contentLength)` updated on the **main** thread (throttle to e.g. every 1–2% or every 64–256 KiB to avoid churn).  
   - **WHEN** length is unknown (**≤ 0** or chunked), keep progress at **0** (or a documented indeterminate treatment) until the stream completes, then jump to **100%** for the download phase only if we need a clear “download done” signal—or immediately transition to phase 2 at **0%** without falsely claiming 100% from bytes. **Preferred:** unknown length → bar stays **0** during download, still show **downloading** copy; on complete, **reset to 0** and enter phase 2 (no fake 100% from bytes).

2. **Phase model (user-facing)**  
   - **Phase A — Download:** progress **0–100** maps to bytes/length when known; status **正在下载升级包** / **Downloading update package**.  
   - **Phase B — System upgrade:** on successful ZIP write (and before/unzip as needed), **set progress to 0**, status **升级系统中** / **Upgrading system**.  
   - **Milestone 1:** when controller firmware step **finishes** (including **606** skip path that continues to APK), set progress to **50%**.  
   - **Milestone 2:** when `controllerBardUpgradeEnd` finishes the APK branch (after install or skip), set progress to **100%**.

3. **UI wiring**  
   - Replace or supplement the static **Updating** `TextView` with a bound field (e.g. `tv_upgrade_status`) updated from `UpgradeActivity`.  
   - Keep `SeekBar` **disabled** for user interaction; programmatic `setProgress` only.

4. **Threading**  
   - All `setProgress` / `setText` on **main** thread; background thread reports counters via `Handler` / `runOnUiThread`.

5. **Success dwell and app restart after silent install**  
   - **WHEN** `YNHAPI.installApkSilently` (or equivalent) is invoked from the OTA success path, the implementation SHALL **not** call `finish()` immediately after showing success.  
   - Use a **main-thread** `Handler.postDelayed(..., 3000)` (or `View.postDelayed`) after presenting **Upgrade completed / Upgrade successful** (existing or string resources), then **launch the normal app entry** (reuse existing constants such as `SystemSettingConstant.APP_PACKAGE_NAME` / `APP_MAIN_ACTIVITY`, or `PackageManager.getLaunchIntentForPackage`, aligned with how `installApkSilently` is already parameterized) with flags that yield a **clean restart** (e.g. `FLAG_ACTIVITY_NEW_TASK` | `FLAG_ACTIVITY_CLEAR_TASK` where applicable), **then** `finish()` `UpgradeActivity`.  
   - Remove any pending callbacks in `onDestroy` to avoid leaks or late navigation after destroy.  
   - **IF** the OS or installer **kills or replaces the process** before 3s or before `startActivity`, behavior is **best-effort**; do not delay invoking install solely to satisfy the dwell.

## Risks / Trade-offs

- **[Risk]** Missing `Content-Length` → no smooth download bar. **→ Mitigation:** documented behavior; optional later enhancement (indeterminate drawable).  
- **[Risk]** Throttling too aggressive → bar looks stuck on large files. **→ Mitigation:** time-based or byte-based minimum update interval.  
- **[Risk]** Unzip is fast; users may see a quick 0% in phase B before controller events. **→ Mitigation:** acceptable; copy explains “upgrading system.”  
- **[Risk]** Silent install triggers immediate process replacement. **→ Mitigation:** 3s dwell + explicit relaunch when the process survives; OS-forced exit remains a known limitation.  
- **[Risk]** Wrong launch flags leave an extra activity on the back stack. **→ Mitigation:** match existing `MainActivity` / splash entry patterns used elsewhere after install.

## Migration Plan

Ship with app update; no server or manifest migration. Rollback: revert `UpgradeActivity` + layout + strings.

## Open Questions

- Whether to show **both** CN and EN on one screen for factory builds (out of scope unless product asks); default is **locale-based** resources.
