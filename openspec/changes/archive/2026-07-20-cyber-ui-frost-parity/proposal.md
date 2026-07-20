## Why

`p3-0-cyber-ui` and `settings-audio-cyber-chrome` delivered the CyberUI **skeleton** (blur, card, status, click registry, volume/player chrome). Product Settings / Monitor / Engineer-style surfaces still depend on Material stand-ins for the rest of lws-ui FrostUI (`control/`, `border/`, full `dialog/`, `clock/`, richer `button/`). Closing that gap in one OpenSpec—with **explicit phases**—keeps P3.0 CyberUI on track without blocking on CyberIME and without a single mega-PR.

## What Changes

- Complete FrostUI → CyberUI port for **all remaining modules except CyberIME**, phased so each phase is independently shippable on ynh960.
- Expand `packages/cyber_ui` public `Cyber*` APIs to cover: design tokens / panel border, full button chrome, switches & checkboxes, slider family (incl. gestures where practical), segmented & stepper, capsule / hold-confirm / ripple, dialog overlay + capture-policy parity, and a stable **Cyber clock / glyph-frost** API (lift HomeClock composition).
- Incrementally replace App Material stand-ins in Settings / Monitor (and Demo where still relevant) as each Cyber control lands; keep click-sound wiring via existing registry.
- Document phase exit criteria (analyze + package tests + device smoke) so `/opsx:apply` can stop at a phase boundary.

**Phases (summary):**

| Phase | Focus |
|------:|-------|
| **A** | Tokens + panel border primitives (`FrostColors` / dimens / tone / border painters stand-ins) |
| **B** | Button parity + `CyberSwitch` + `CyberCheckbox` |
| **C** | `CyberSlider` core + volume/flanked alignment; Segmented + NumericStepper |
| **D** | Capsule slider, HoldConfirm, press/reversible ripple |
| **E** | Dialog OverlayHost + capture / freeze policy (lws-ui dialog parity) |
| **F** | Cyber clock / glyph-blur API; HomeClock migrates onto it |
| **G** | App adoption sweep (Settings Material → Cyber where counterparts exist); docs + archive |

## Capabilities

### New Capabilities

- `cyber-ui-tokens-border`: Shared glass tokens, dimens, tone, and panel border/fill primitives used by cards/dialogs/controls.
- `cyber-ui-controls`: Interactive control suite — switch, checkbox, slider, segmented, stepper, capsule, hold-confirm, ripple — with click-sound hooks.
- `cyber-ui-dialog-host`: Overlay host, panel shell, backdrop capture/freeze policy for dialogs/modals (beyond current skeleton).
- `cyber-ui-clock`: Public Cyber clock / glyph-frost API for Home (and reusable) time chrome.

### Modified Capabilities

- `cyber-ui`: Package MUST grow phase-by-phase until FrostUI (non-IME) surfaces have Cyber counterparts; bare `BackdropFilter` ban remains.
- `settings-ui`: As Cyber controls land, Settings SHALL prefer them over Material for matching rows (switches, segmented, sliders, dialogs).
- `product-home-ui`: Home clock SHALL eventually consume `cyber-ui-clock` instead of App-only glyph logic.
- `product-monitor-ui`: Monitor chrome MAY adopt Cyber controls/borders when available (status already on Cyber).

## Impact

- **Package:** Large additive surface under `packages/cyber_ui/` (phased commits).
- **App:** Progressive call-site migration; no route inventory change required.
- **Out of scope:** **CyberIME** (separate change); Android View interop (`frostui/*/interop` View wrappers); line-by-line Kotlin ports; per-SKU forks; warn-alarm sound loop (already separate from click SFX).
- **Depends on:** Existing blur / card / click / volume chrome from prior changes (keep and extend, do not rewrite).
- **Reference:** lws-ui `frostui/{border,button,control,dialog,clock,card,blur}` + `docs/frostui.md`.
