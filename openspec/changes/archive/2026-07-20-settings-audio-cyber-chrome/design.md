## Context

`p3-0-cyber-ui` delivered `CyberClickSoundRegistry` + a single `assets/audio/click.mp3` backend. Settings Sound Effect is still a stub; Volume uses Material `Slider`; Demo uses ad-hoc play/stop UI. lws-ui already separates **UI kit (Frost)** from **App audio (GlobalSoundManager + DB prefs)** — CyberUI should mirror that split.

### How lws-ui registers and calls click SFX

```text
LaserApplication.onCreate
  → FrostUiDialogBridge.register()
       → FrostUiClickSoundRegistry.register(GlobalSoundManager::playClickSound)
  → SoundEffectSettings.warmCache(app)   // load soundEffect 0..2 from DB

Frost controls (FrostButton, Switch, Segmented, …)
  → if playClickSound / clickSoundEnabled
       → FrostUiClickSoundRegistry.playClick()   // no-op if unregistered
            → GlobalSoundManager.playClickSound()
                 → refreshActiveEffect(SoundEffectSettings.getIndex)
                 → SoundPool.play(clickSampleIds[activeEffectIndex])
                   // samples: click_mp3_2, click_mp3, click_mp3_1  (Effect 1/2/3)

CommonSettingsFragment.bindSoundEffect
  → RadioGroup index → GlobalSoundManager.openEffect(index)
       → SoundEffectSettings.setIndex + ensureInitialized + preview sample
```

Key properties to preserve on Linux:

1. **Registry in CyberUI** — widgets never import HAL/ALSA.
2. **App owns samples + index** — three assets; persisted index selects which sample `playClick` uses.
3. **Selecting an effect previews it** (`openEffect` / `previewEffect`).
4. **Debounce** (~150 ms) optional but recommended on Linux backend.

Volume / player are separate: Frost volume is a flanked slider; `FrostAudioPlayerCard` is transport+seek chrome. Both call into App/media callbacks, not SoundPool click samples.

## Goals / Non-Goals

**Goals:**

- Persist Effect 1/2/3 (index 0–2) and drive `CyberClickSoundRegistry` playback.
- Settings Volume page uses Cyber volume chrome bound to `MediaAudioController`.
- `CyberAudioPlayerCard` for Demo (shanghai_tan) with App-owned playback.
- Document registry wiring parity with `FrostUiDialogBridge`.

**Non-Goals:**

- Warn/alarm loop (`warn_mp3` / `GlobalSoundManager.warnSound`).
- Full FrostSlider long-press-drag / hold-confirm parity in v1.
- Moving media volume persistence out of `cyber_hal`.
- Fourth “Off” sound-effect option (unless product later requires it).

## Decisions

### D1 — Keep CyberUI registry; App selects sample by index

**Choice:** Extend App backend (`AppMediaClickSound` or successor) to load three assets and play `assets[index]`. Index from a small App prefs module (`SoundEffectStore`), not from cyber_ui.

**Alternatives:** Put index inside CyberClickSoundRegistry → couples package to product prefs.

### D2 — Prefs path for sound-effect index

**Choice:** App-owned file under `/var/lib/hmi/` (or existing product prefs pattern if one exists), default `0`. Warm-cache at bootstrap before registering click backend (mirror `SoundEffectSettings.warmCache`).

**Alternatives:** SQLite Room like Android — heavier than needed on Buildroot; SharedPreferences plugin — avoid new Flutter plugin if a simple JSON/text file matches other HMI prefs.

### D3 — Click playback vs media player contention

**Choice:** Prefer a **dedicated short-clip play path** (spawn mpg123/aplay for click only, or SoundPool-equivalent) so UI clicks do not `LOAD` into the remote media player session used by shanghai_tan. If dedicated path is too costly in v1, document that click may interrupt media and file a follow-up.

**Alternatives:** Always use `MediaAudioController.playAsset` — simple but fights Demo/player.

### D4 — Cyber volume chrome

**Choice:** `CyberVolumeSlider` / `CyberIconFlankedSlider` wrapping a Material or thin Cyber slider + leading/trailing icons; Settings Volume page replaces bare `Slider`. Levels still `getVolumePercent` / `setVolumePercent`.

### D5 — CyberAudioPlayerCard

**Choice:** Presentation widget: play/pause, ±seek buttons, seek bar, elapsed/duration labels. Callbacks: `onPlayPause`, `onSeek`, etc. **Settings Volume** wires `MediaAudioController` for play-test (`shanghai_tan` or short clip). Seek may be best-effort if Linux player lacks precise seek (document limitation). Do **not** re-add volume/player to Demo (forbidden by `p2-device-demo-ui`).

### D6 — Settings Sound Effect UI

**Choice:** Segmented control (or equivalent) with labels Effect 1/2/3; on change persist + preview. Align index mapping with lws-ui `CLICK_RAW` order:

| Index | Asset (lws-ui) | Label |
|------:|----------------|--------|
| 0 | `click_mp3_2.mp3` | Effect 1 |
| 1 | `click_mp3.mp3` | Effect 2 |
| 2 | `click_mp3_1.mp3` | Effect 3 |

## Risks / Trade-offs

- **[Risk]** Click via media controller interrupts music → Mitigation: dedicated click process/path (D3).
- **[Risk]** Seek unsupported on mpg123 remote → Mitigation: disable seek or approximate; card still shows transport.
- **[Risk]** Prefs not restored before first tap → Mitigation: synchronous warm-read at register time.
- **[Trade-off]** Minimal CyberSlider vs full Frost gesture set → ship usable Settings first.

## Migration Plan

1. Add three click assets; map indices; update click backend.
2. Sound-effect store + Settings page + preview.
3. Cyber volume chrome → Volume settings (+ optional `CyberAudioPlayerCard` play-test).
4. `make build-app` / `make push-app`; verify Effect switch + volume + play-test.

Rollback: revert App settings pages to Material; keep assets unused.

## Open Questions

1. Exact prefs path under `/var/lib/hmi/` vs reuse an existing settings JSON file — decide during apply by scanning App restore patterns.
2. Whether Volume play-test embeds full `CyberAudioPlayerCard` or a simpler play/stop row — prefer card if layout fits; else thin transport.
