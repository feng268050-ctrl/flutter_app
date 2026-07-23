## Why

WiFi details and the forget-network confirmation dialog use different button treatments (border `TextView`, `cnc_exit_dialog_btn_style`) than the primary action pattern used elsewhere—most visibly the AGREE control on Safety Operation Tips. That inconsistency makes the Network Settings flow feel visually disconnected from the rest of the app.

## What Changes

- Restyle the **Forget This Network** control on the WiFi details screen so it matches the Safety Operation Tips **AGREE** button (same background drawable, dimensions, text size/color treatment, and `backgroundTint` handling as appropriate).
- Restyle the **Confirm** and **Cancel** actions in the forget-network confirmation dialog to the same AGREE-style primary button pattern (including spacing between the two actions where needed).
- Keep existing behavior (tap targets, string resources, dialog logic); changes are layout/style only unless Java code must align with enabled/disabled coloring used on AGREE.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `wifi-network-details`: Extend requirements so forget-network and confirmation actions use the same documented primary button styling as Safety Operation Tips AGREE (visual consistency requirement).

## Impact

- **Layouts**: `activity_wifi_details.xml` (`btn_forget`), `dialog_wifi_forget_confirm.xml` (confirm/cancel).
- **Reference**: `activity_safety_tips.xml` / `activity_use_safety_tips.xml` (`btn_agree` with `@drawable/btn_icon_selector`, dimensions, text styling).
- **Java** (if needed): `WifiDetailsActivity` and any dialog setup that programmatically sets colors on forget/confirm/cancel to mirror `SafetyTipsActivity` / `UseSafetyTipsActivity` patterns for the AGREE button.
