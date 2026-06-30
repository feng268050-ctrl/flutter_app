## ADDED Requirements

### Requirement: Boot splash logo appears before flutter-pi home frame

The system SHALL display a product boot logo on the MIPI panel within 2 seconds of power-on, via U-Boot and/or kernel early splash, and SHALL keep the logo visible until the flutter-pi Hello World home frame is rendered.

#### Scenario: Logo visible at early boot

- **WHEN** ynh960 device powers on with P1 firmware
- **THEN** a logo image is visible on the LCD before systemd reaches multi-user target

#### Scenario: No prolonged black screen before UI

- **WHEN** device boots from cold power to flutter-pi home frame
- **THEN** the panel does not remain black for more than 2 seconds at any point before home frame

### Requirement: Splash matches ynh960 display geometry

Boot splash assets SHALL match ynh960 panel configuration: 800×1280 MIPI with 90° rotation consistent with `960_lcd_param_rk356x.txt` and flutter-pi orientation flags.

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
