# boot-splash-display Specification

## Purpose
TBD - created by archiving change p1-linux-flutter-platform. Update Purpose after archive.
## Requirements
### Requirement: Boot splash logo appears before flutter-pi home frame

The system SHALL display a product boot logo on the MIPI panel within ~2 seconds of power-on, via SDK FIT `boot.its` resource logo and/or kernel early splash, and SHALL keep the logo visible until the flutter-pi Hello World home frame is rendered (`Freeing drm_logo`).

#### Scenario: Logo visible at early boot

- **WHEN** ynh960 device powers on with P1 firmware
- **THEN** a logo image is visible on the LCD before systemd reaches multi-user target

#### Scenario: No prolonged black screen before UI

- **WHEN** device boots from cold power to flutter-pi home frame
- **THEN** the panel does not remain black for more than ~2 seconds at any point before home frame

#### Scenario: Logo holds through flutter-pi EGL init

- **WHEN** `hmi.service` starts flutter-pi
- **THEN** boot logo remains on screen during EGL/Mali initialization until first Flutter frame commits

### Requirement: Splash matches ynh960 display geometry

Boot splash assets SHALL match ynh960 panel configuration: 800×1280 MIPI with 90° rotation consistent with `960_lcd_param_rk356x.txt` and flutter-pi orientation flags (`-o landscape_left`).

#### Scenario: Logo orientation correct

- **WHEN** boot splash is displayed on ynh960 production panel
- **THEN** logo is upright relative to the physical enclosure (not sideways or cropped)

#### Scenario: Handoff to flutter-pi without resolution flash

- **WHEN** flutter-pi starts after splash
- **THEN** transition does not cause a full-screen resolution mode change flash (minor flicker acceptable)

### Requirement: Splash does not use Weston or Plymouth

The P1 boot splash MUST NOT depend on Weston, Wayland compositor, or Plymouth. Only U-Boot resource logo, kernel DRM/FB early logo, or equivalent direct panel path is permitted.

#### Scenario: No weston during splash

- **WHEN** device displays boot splash
- **THEN** no Wayland or Weston process is running

### Requirement: U-Boot uses SDK prebuilt FIT chain

P1 SHALL use SDK `boot.its` FIT packaging (`RK_BOOT_FIT_ITS_NAME="boot.its"`) with Innohi/SDK prebuilt loader and U-Boot. Self-compiled U-Boot is out of P1 scope.

#### Scenario: boot.its FIT used on ynh960

- **WHEN** developer inspects `board/ynh960_defconfig`
- **THEN** `RK_BOOT_FIT_ITS_NAME="boot.its"` is set and `logo.bmp` is packaged into the resource partition

