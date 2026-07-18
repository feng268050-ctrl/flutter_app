## ADDED Requirements

### Requirement: Board pack contents
Each supported motherboard SHALL have a board pack consumed by the image build and by the HAL, including at least: lunch/defconfig identity, kernel DTS/fragments as needed, board profile for HAL (**capability set**, **network role→iface map**, and optional pin/tty/audio/radio ids for advertised capabilities), and hooks for WiFiBT or other bringup plugins when not generic. Packs MUST NOT be required to include product RGB LED maps for the portable HAL.

#### Scenario: ynh960 is first pack
- **WHEN** building the current product image
- **THEN** the ynh960 board pack SHALL be selected by default (`BOARD=ynh960` or equivalent) and HAL SHALL find its profile on the rootfs, including role maps for the network interfaces that pack uses

### Requirement: Screen pack contents
When a product has a panel, it SHALL have a screen pack including LCD/MIPI parameter tables, generated or maintained panel DTSI as applicable, touch alignment notes, splash/logo sizing contract, and default flutter-pi / CyberUI orientation mapping. Headless products MAY omit a screen pack and MUST omit display-related HAL capabilities.

#### Scenario: Screen change without App fork
- **WHEN** a new screen pack is added for the same board family that has a display
- **THEN** product App Dart SHALL NOT require edits solely to change panel timings or default rotation (HAL/profile and launch scripts absorb the change)

#### Scenario: Headless omits screen pack
- **WHEN** a product has no display
- **THEN** the image MAY ship without a screen pack and HAL capability discovery SHALL not advertise backlight/orientation
### Requirement: Compile-time selection
For the small set of motherboards in scope, board and screen packs SHALL be selected at image build time (not runtime auto-detect of arbitrary hardware), unless a later change explicitly adds detection.

#### Scenario: Wrong pack not silently mixed
- **WHEN** an image is built for board A
- **THEN** board B’s DTS and HAL profile SHALL NOT be installed as the active pack on that image
