## Context

Safety Operation Tips (`activity_safety_tips.xml`) defines the **AGREE** action as a `Button` using `@drawable/btn_icon_selector`, explicit size `163dp × 58dp`, `android:backgroundTint="@null"`, `android:textColor="#FFFFFF"`, and `android:textSize="24sp"`. The WiFi details screen uses a large `TextView` with `@drawable/ll_border` for **Forget This Network**, and the forget confirmation dialog uses `cnc_exit_dialog_btn_style` for **Cancel** and **Confirm**.

## Goals / Non-Goals

**Goals:**

- Align forget-network UI controls with the AGREE button’s drawable, typography, and color treatment so Network Settings matches the established primary action pattern.
- Keep all existing behavior (navigation, confirmation copy, forget/cancel logic, failure handling).

**Non-Goals:**

- Redesign Safety Operation Tips or the AGREE checkbox flow.
- Introduce new themes or app-wide style resources unless needed to avoid duplication (prefer matching existing AGREE XML attributes first).

## Decisions

1. **Source of truth**  
   Treat `activity_safety_tips.xml` (and the parallel `activity_use_safety_tips.xml` if identical) as the canonical AGREE markup. Copy the same `android:background`, `backgroundTint`, text color, and text size onto the WiFi forget and dialog buttons.

2. **Forget This Network control**  
   Prefer `Button` over `TextView` so platform tinting behavior matches AGREE. Use the same selector background; adjust width/height only as needed for the longer label (e.g. `wrap_content` with horizontal padding or a larger min width), while keeping the same height as AGREE unless product requires otherwise.

3. **Dialog actions**  
   Apply the same AGREE-style attributes to both **Cancel** and **Confirm** as requested. Keep horizontal spacing between buttons (e.g. existing `layout_marginLeft` on the second button) so layout does not collapse.

4. **Programmatic colors**  
   If Java currently sets text or background colors on these controls, align with `SafetyTipsActivity` patterns only where the AGREE button uses runtime colors (e.g. disabled gray `#919191` vs white `#FFFFFF`). If forget actions have no disabled state, default to the enabled AGREE appearance.

**Alternatives considered**

- **Shared style resource (`styles.xml`)** — Reduces duplication long-term but touches more files; defer unless duplicate attributes become noisy.
- **Secondary (outline) style for Cancel** — Rejected for this change because the request explicitly matches both actions to AGREE.

## Risks / Trade-offs

- **Longer label vs fixed AGREE width** — **Forget This Network** may need more horizontal space than **AGREE**; using a single fixed width could clip text. **Mitigation:** Use `wrap_content` with min dimensions or a width that fits localized strings; verify in default and Chinese layouts.
- **Two primary-styled actions in one dialog** — Both buttons look equally prominent. **Mitigation:** Accept per product request; if UX feedback later prefers hierarchy, revisit with a secondary style for Cancel.

## Migration Plan

Not applicable (in-app layout/style update only). Rollback: revert layout and any related Java color changes.

## Open Questions

- None for implementation; confirm visually on target device resolution after layout change.
