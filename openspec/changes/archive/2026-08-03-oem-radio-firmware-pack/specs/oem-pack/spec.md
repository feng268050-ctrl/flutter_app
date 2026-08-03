## ADDED Requirements

### Requirement: build-oem includes board radio firmware when present

When a board pack contains `radio/firmware/`, `make build-oem` SHALL install that tree into the OEM image under the board path so runtime bring-up can read it from `/oem` without relying on rootfs multi-vendor firmware dumps.

#### Scenario: Radio subtree packed into oem.img

- **WHEN** the board pack includes `radio/manifest.json` and `radio/firmware/` and `make build-oem` runs
- **THEN** those paths MUST appear under the corresponding `/oem/boards/<board_id>/radio/` in the oem image
