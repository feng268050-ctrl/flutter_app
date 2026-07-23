## Context

`FrostedGlassDialog` currently owns the reusable parts of the visual style: a rounded BlurView card, `FrostedGlassPanelDrawable` for fill and border, and frosted-glass button drawables in the dialog layout. This works for dialogs but makes the same visual language difficult to apply to non-dialog cards or custom buttons without copying drawable setup.

The existing dialog contract should remain stable: `FrostedGlassDialog.prompt(...)` keeps its title/body/action slots, live activity backdrop blur, default text body, and custom body pattern. The change introduces shared components underneath that contract rather than adding new generic dialog modes.

## Goals / Non-Goals

**Goals:**

- Provide reusable `FrostedGlassCard` and `FrostedGlassButton` APIs for Android views in the HMI app.
- Centralize glass fill, rounded corners, border drawing, and button state styling so dialogs and non-dialog UI share the same tokens.
- Support explicit border highlight placement via `borderGradientCenter`.
- Refactor `FrostedGlassDialog` to use the shared card foundation while preserving existing prompt behavior.

**Non-Goals:**

- Do not introduce a new third-party UI framework or replace BlurView.
- Do not add progress, picker, QR, or other feature-specific modes to `FrostedGlassDialog`.
- Do not migrate every existing specialized dialog shell unless it is already FrostedGlass-styled or directly touched by this component extraction.
- Do not change dialog stacking, lifecycle, scrim behavior, or IME handling beyond adapting the card host.

## Decisions

1. Implement FrostedGlass components as Android view classes backed by shared drawables/resources.

   `FrostedGlassCard` should be a reusable container view that can be used in XML or code. It owns rounded clipping, glass fill, optional border drawing, padding/min-size defaults, and `borderGradientCenter`. Keeping this as a view-level component matches the current Java Android codebase and avoids introducing Compose or a separate UI framework.

   Alternative considered: keep only drawable helpers and require every caller to wire background, foreground, outline, and padding manually. That would reduce class count but keep the current duplication risk.

2. Keep border rendering in a configurable drawable.

   The current `FrostedGlassPanelDrawable` already handles aspect-ratio-aware sweep gradients and tokenized colors. It should be evolved or wrapped so `FrostedGlassCard` and `FrostedGlassButton` can select the highlight orientation instead of hard-coding top-left/bottom-right. This preserves the current visual quality while exposing the missing control.

   Alternative considered: use static XML gradients per orientation. XML gradients are simpler but do not track rounded-rect perimeter/corner positions as well as the current sweep-based implementation.

3. Model `borderGradientCenter` as a small enum with XML-friendly values.

   Supported values are `top-left-bottom-right`, `bottom-left-top-right`, `top-bottom`, and `left-right`. Code should use an enum to avoid stringly typed branching, with XML attrs mapping kebab-case values to enum constants.

   Alternative considered: expose arbitrary angle/color-stop inputs. That is more flexible but too broad for the requested design system and harder to keep visually consistent.

4. Make `FrostedGlassButton` button-specific, not a card alias.

   `FrostedGlassButton` should share the same border/fill primitives but provide button semantics: enabled/pressed/focused/selected states, primary/secondary styling, text appearance defaults, min touch target, and click feedback. It should remain usable from existing layouts that currently point at frosted-glass button drawables.

   Alternative considered: use `FrostedGlassCard` for buttons plus a click listener. That loses accessibility/button state behavior and makes callers rebuild common button affordances.

5. Refactor dialogs by composition.

   `FrostedGlassDialog` and FrostedGlass-style dialog wrappers should continue to manage overlay lifecycle, scrim, blur target, slots, and IME coordination. The visual card portion should be delegated to `FrostedGlassCard`, allowing `FrostedGlassOverlayHost` to configure width and blur while avoiding direct `setBackground(new FrostedGlassPanelDrawable(...))` setup.

   Alternative considered: rewrite `FrostedGlassDialog` as a subclass of `FrostedGlassCard`. The dialog is an overlay coordinator, not a card, so composition keeps responsibilities clearer.

6. Use localized border rendering for rounded capsule buttons only.

   `FrostedGlassButton` in default `rounded` shape (no explicit `borderRadius`) MUST opt into `localizedBorder` on `FrostedGlassPanelDrawable`. Diagonal centers (`top-left-bottom-right`, `bottom-left-top-right`) render as a soft-shadow base plus paired corner radial highlights so highlights stay on the intended corners without bleeding onto opposite corners on wide capsule buttons. Axis-aligned centers (`top-bottom`, `left-right`) render with a localized linear gradient so the full highlighted edge stays bright; a center radial highlight was rejected because it only lit the middle of each edge.

   `FrostedGlassCard` and other non-button consumers continue to use the existing sweep/linear border shaders.

   Alternative considered: one shader path for all orientations. Sweep/linear gradients are acceptable on cards but produced broken or mis-centered highlights on capsule buttons, especially for diagonal centers.

7. Model button variants as three emphasis levels with distinct tokens.

   - `default`: neutral translucent glass fill and border, white text.
   - `primary`: flat opaque orange fill (no vertical glass fade), orange-tinted border tokens, white text.
   - `secondary`: same neutral glass as `default`, destructive red-tinted text (`#FFFF5A52`), no separate red glass fill.

   Alternative considered: keep the legacy dialog orange pill drawable for `primary`. That diverged from the shared card glass language and was replaced.

8. Standardize adopted button chrome on `top-left-bottom-right`.

   Dialog confirm actions and Safety Tips agree actions use `primary` with `top-left-bottom-right`. Dialog cancel/close actions use `default` with the same border orientation for visual consistency during rollout.

## Risks / Trade-offs

- Existing dialog appearance drifts during extraction -> compare the refactored `FrostedGlassDialog` against the current default prompt and custom-body dialogs, especially corner radius, border brightness, blur clipping, and button spacing.
- XML attrs may be over-generalized -> keep the first pass limited to requested controls plus common card/button sizing and visual toggles already needed by current resources.
- Border orientation names can be misinterpreted -> document that each value names the highlighted edge/corner pair and the border transitions toward mid/shadow regions between those centers.
- Button styling could diverge from existing primary/secondary drawables -> migrate the current resource colors and dimensions into the shared implementation before adding new visual variants.
- Localized diagonal highlight tuning can overshoot brightness -> keep radial stops and `softShadowColor()` blend ratio conservative; axis-aligned localized borders use separate linear stops from diagonal radials.
- Capsule button border review depends on emulator sync -> use the project `make sync` rule with a fixed `ADB_SERIAL` during visual iteration.

## Migration Plan

1. Add shared FrostedGlass component attrs, enum mapping, and drawable support for configurable border gradient centers.
2. Introduce `FrostedGlassCard` and `FrostedGlassButton` with XML and code configuration APIs.
3. Update `FrostedGlassDialog` layout/overlay styling to use `FrostedGlassCard` for the card chrome and shared button primitives for action controls.
4. Smoke test simple prompts, custom body dialogs, numeric/text input wrappers, and a blocking progress wrapper to confirm dialog behavior is unchanged.
5. Leave unrelated specialized dialog shells in place unless they already consume FrostedGlass dialog/card resources and can be safely swapped without behavior changes.
