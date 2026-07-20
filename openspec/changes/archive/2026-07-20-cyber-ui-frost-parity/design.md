## Context

CyberUI today (`packages/cyber_ui`) covers blur sampling, card, status, thin button, dialog skeleton, click registry, volume slider, and audio player card. lws-ui FrostUI still has large modules without Flutter counterparts:

- `border/` — colors, dimens, panel painters  
- `button/` — variants, press feedback (beyond thin TextButton)  
- `control/` — switch, checkbox, slider, segmented, stepper, capsule, hold-confirm, ripple, volume (volume chrome partially done)  
- `dialog/` — overlay host, capture freeze, prompt  
- `clock/` — glyph blur renderer  

CyberIME stays out. This change is the **phased completion plan** for the rest.

## Goals / Non-Goals

**Goals:**

- One OpenSpec tracks the full remaining Frost→Cyber port (minus IME).
- Phases A→G are ordered by dependency; each phase has shippable widgets + tests + optional App wiring.
- Preserve registry injection pattern (App owns ALSA/assets; Cyber calls `playClick()` only).
- Token/visual parity with lws-ui where practical; Flutter idioms over Kotlin clones.

**Non-Goals:**

- CyberIME / keyboard overlays.  
- Android `*View` interop layers.  
- Pixel-perfect identical shaders if RK3566 cost is too high (document downgrades).  
- Rewriting already-shipped blur/card/click/volume APIs unless a phase requires a small extension.

## Decisions

### D1 — Single change, phased tasks

**Choice:** One change `cyber-ui-frost-parity` with tasks grouped by phase; implementers may `/opsx:apply` and stop after a phase (leave later checkboxes open) or finish all.

**Alternatives:** One change per phase → fragments tracking; user asked for one OpenSpec.

### D2 — Phase order (dependency)

```text
A tokens/border
  → B button + switch/checkbox
  → C slider + segmented + stepper
  → D capsule + hold-confirm + ripple
  → E dialog host/capture
  → F clock API
  → G App adoption + docs
```

Audio player / volume chrome already exist; Phase C aligns `CyberSlider` underneath `CyberVolumeSlider` if needed.

### D3 — Gesture depth

**Choice:** Phase C ships usable drag sliders; long-press-drag / segment-drag from Frost MAY land in Phase C follow-up tasks or Phase D if they share gesture code. HoldConfirm is Phase D.

### D4 — Dialog capture

**Choice:** Phase E brings OverlayHost + freeze-page-backdrop-during-overlay semantics aligned with lws-ui; extend existing `CyberBlurBackdropScope` rather than a second capture system.

### D5 — Clock

**Choice:** Phase F extracts glyph-frost + appearance tokens into cyber_ui; App `HomeClock` becomes a thin consumer. True glyph-clipped live blur remains best-effort with documented limits on RK3566.

### D6 — App migration timing

**Choice:** Light wiring allowed inside the phase that introduces a control (e.g. one Settings switch); Phase G is the systematic Settings/Monitor sweep.

## Risks / Trade-offs

- **[Risk]** Scope creep across phases → Mitigation: phase exit = package tests green + README module map updated; App sweep deferred to G.  
- **[Risk]** Realtime blur + heavy borders on RK3566 → Mitigation: intensity caps, fake-glass fallback, optional firstFrame for dense lists.  
- **[Risk]** Gesture parity incomplete → Mitigation: document “v1 gestures” vs Frost long-press-drag; ship safe Material-like drag first.  
- **[Trade-off]** One large OpenSpec vs many small ones → single tracker as requested.

## Migration Plan

1. Implement Phase A → merge/push-app smoke.  
2. Continue B…F similarly.  
3. Phase G migrates Settings call sites; archive when product accepts.  
Rollback: unused Cyber widgets can remain unused; App keeps Material until wired.

## Open Questions

1. Whether Engineer-mode-specific Frost layouts need Cyber in this change or wait for P4 business pages (default: **controls only**, no Engineer page rewrite).  
2. How much reversible-ripple visual fidelity is required on flutter-pi (default: **simplified** ripple in D, full parity optional later).
