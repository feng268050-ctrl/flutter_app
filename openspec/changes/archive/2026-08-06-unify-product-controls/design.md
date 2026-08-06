## Context

Product HMI already depends on `cyber_ui` (`CyberCheckbox`, `CyberSwitch`, `CyberSlider`) and app wrappers (`HmiButton`, `TipDialogHost`, CyberIME). Adoption is incomplete: cream tip dialogs still use Material `Checkbox`; boot self-check uses `CyberCheckbox` at ad-hoc 38; Engineer device bar uses Material `SwitchListTile`; Process Library / IP Camera Settings / shared Wi‑Fi list still use Material buttons/dialogs/`TextField`.

## Goals / Non-Goals

**Goals:**

- Single product checkbox face: `CyberCheckbox` + `CyberDimens.checkboxLargeSize` (28) on all listed product surfaces.
- Manual gas switch uses `CyberSwitch`.
- Process Library confirms/edits, IP Camera Settings CTAs, and Wi‑Fi network list actions use `HmiButton` + product dialog host (not Material `AlertDialog` / filled/text buttons for those roles).
- Process Library edit fields use CyberIME.

**Non-Goals:**

- Demo pages (`lib/ui/demo/**`).
- Replacing `ProcessModeOutlineButton` process side keys.
- Changing cream `showLightPrompt` barrier/frost for Engineer tip / Laser Enable (only the checkbox widget).
- Replacing SnackBar with a global tip/toast system.
- Adding a third checkbox dimens tier.

## Decisions

1. **Checkbox size = large (28) only for product toggles**  
   Boot self-check drops 38 rather than promoting 38 into dimens. Rationale: one large tier already matches Settings / Engineer panel / Safety Tips; optical “bigger on boot” was undocumented one-off.  
   Alternative considered: `checkboxXLargeSize = 38` — rejected to avoid proliferating tiers.

2. **Cream tips keep `showLightPrompt`, swap widget to `CyberCheckbox`**  
   `CyberCheckbox` fill is product green (`#34C759`); side/unchecked chrome is acceptable on cream. If contrast fails in QA, allow a thin cream-theme wrapper that still uses `CyberCheckbox` internals — do not keep raw Material `Checkbox`.

3. **Manual gas: `CyberSwitch` in existing row layout**  
   Replace `SwitchListTile` trailing control with `CyberSwitch` (and label via existing typography), not full Settings switch-row chrome, to minimize layout churn on Engineer/Quick bars.

4. **Dialogs: TipDialogHost / existing product confirms, not AlertDialog**  
   Process Library delete/save/confirm → `TipDialogHost.showDarkPrompt` (or shared `HmiDialogActions`) + `HmiButton`. Upload progress on Videos may stay a progress dialog if already product-frosted; this change’s button/dialog work targets Process Library edit/confirm, IP Camera Settings CTAs, and `wifi_network_views`.

5. **Process Library TextField → CyberIME**  
   Prefer `showCyberImeInputDialog` for discrete fields (parity with Engineer rename) or in-dialog `CyberImeTextField` if multi-field form must stay open. Match `engineer_mode_page` rename pattern where possible.

## Risks / Trade-offs

- **[Risk] CyberCheckbox on cream looks wrong** → Mitigation: visual QA on Engineer tip + Laser Enable; adjust unchecked border via CyberCheckbox API only if needed.  
- **[Risk] CyberIME changes Process Library edit UX (modal IME vs inline)** → Mitigation: prefer modal input dialogs already used elsewhere; keep form structure if multi-field requires inline CyberImeTextField.  
- **[Risk] Wi‑Fi / IP Camera layout shifts with HmiButton sizes** → Mitigation: use `HmiButtonSize.medium` / existing Settings CTA patterns; widget tests for presence/labels.

## Migration Plan

1. Land checkbox + switch (smallest, high visibility).  
2. Process Library dialogs + IME.  
3. IP Camera Settings + Wi‑Fi list buttons.  
4. Analyze + targeted widget tests; `make build-app` / `make push-app`.

Rollback: revert the change commit; no rootfs/schema migration.

## Open Questions

- None blocking; cream `CyberCheckbox` contrast to confirm during apply QA.
