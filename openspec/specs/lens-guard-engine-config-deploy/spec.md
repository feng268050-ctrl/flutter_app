# lens-guard-engine-config-deploy Specification

## Purpose
TBD - created by archiving change lens-guard-letterbox-det-alignment-2026-05-22. Update Purpose after archive.
## Requirements
### Requirement: Deployed config.yaml SHALL match engine raw-det ROI640 defaults

After ai-library or bundled asset deployment, `files/lens_guard/config.yaml` SHALL reflect the engine-delivered template including:

- `models.det.enabled: true` and `models.cls.enabled` per product (default `false` for det-only)
- `algorithm.stain_score_mode: logits` for embedded `det_raw_head.rknn` (required; see `APP_ALIGNMENT_BRIEF` §3)
- `algorithm.stain_conf_thresh` and `algorithm.stain_nms_thresh` (production examples 0.65 / 0.55; training parity comparison may use 0.25 / 0.35)
- `stain_detection.mask_radius_px` and `mask_ref_width` (example 280 @ 1920 reference width)

The App SHALL pass this file path to `nativeCreate` and restart the native session after OTA replacement.

#### Scenario: Fresh asset deploy after OTA

- **WHEN** a new ai-library zip is imported containing an updated `config.yaml`
- **THEN** `AssetDeployer` SHALL copy it to `files/lens_guard/config.yaml`
- **AND** Lens Guard SHALL call `nativeDestroy` then `nativeCreate` before resuming inference

#### Scenario: logits mode required for raw head

- **WHEN** the deployed config sets `stain_score_mode` to a value other than `logits` while using `det_raw_head`
- **THEN** engineering validation SHALL treat inference as misconfigured
- **AND** the App MAY log a warning when parsing config for support diagnostics

### Requirement: libai.so upgrade SHALL include matching runtime trio

The App packaging pipeline SHALL ship `libai.so`, `libc++_shared.so`, and `librknnrt.so` from the same engine build. Partial replacement SHALL be avoided.

#### Scenario: Engine library upgrade on device

- **WHEN** operators replace the ai-library bundle
- **THEN** all three native libraries SHALL be updated together
- **AND** `config.yaml` from the same zip SHALL be deployed in the same maintenance window

#### Scenario: Field overlay validation resolutions

- **WHEN** validating after upgrade per `APP_ALIGNMENT_BRIEF` §6
- **THEN** overlay checks SHALL be performed at least on **1280×720** and **1920×1080** streams
- **AND** boxes SHALL align with stains on the **full** preview, not only within the central 640×640 ROI

