## MODIFIED Requirements

### Requirement: Weston image bridges splash after DRM takeover

When the firmware stamp is `/etc/display-stack=weston` (default product rootfs), after Weston enables the output the kernel `drm_logo` is replaced. The image SHALL paint the product logo via Weston **desktop-shell** `background-image` (`/usr/share/hmi/boot-splash.png`, same canvas as `board/logo`) until the Flutter Wayland client presents, so the panel is not left black or empty-colored without the logo mark.

#### Scenario: Weston handoff shows logo

- **WHEN** a Weston-stamped rootfs boots and Weston enables `DSI-1` before Flutter first present
- **THEN** the product splash artwork remains visible (desktop-shell background), not only a solid fill
