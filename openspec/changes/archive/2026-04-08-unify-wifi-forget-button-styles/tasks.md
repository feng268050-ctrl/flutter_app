## 1. Reference and layout updates

- [x] 1.1 Compare `activity_safety_tips.xml` (AGREE: `btn_agree`) with `activity_wifi_details.xml` (`btn_forget`) and align background drawable, `backgroundTint`, text color, and text size per `design.md`.
- [x] 1.2 Update `activity_wifi_details.xml`: switch `btn_forget` to a `Button` (or equivalent) with AGREE-matched attributes; set width/height so localized **Forget This Network** text does not clip.
- [x] 1.3 Update `dialog_wifi_forget_confirm.xml`: remove `cnc_exit_dialog_btn_style` from cancel/confirm; apply the same AGREE-style attributes to both buttons; keep spacing between buttons.

## 2. Code and verification

- [x] 2.1 Review `WifiDetailsActivity.java` for any programmatic styling on `btn_forget`, `btn_forget_confirm`, or `btn_forget_cancel`; align with `SafetyTipsActivity` only if needed for consistency (e.g. tint or text color overrides).
- [x] 2.2 Build the app and visually verify WiFi details and the forget dialog on the target device or emulator (forget flow still works; buttons match AGREE appearance).
