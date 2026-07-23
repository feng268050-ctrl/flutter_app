## MODIFIED Requirements

### Requirement: 640x640 is inference input transform, not camera output default

The system MUST treat 640×640 as a **native engine** ROI transform (center crop of the pushed full frame to model input), not as a default camera output resolution and not as an App-side letterbox or resize before `nativePushFrame`.

The App SHALL push decoded sub-stream I420 at native resolution when both width and height are at least 640. App-side letterbox-to-640 before `nativePushFrame` SHALL be disabled in production.

#### Scenario: Model input adaptation inside native

- **WHEN** the Lens Guard engine runs stain detection on a live frame at 1920×1080
- **THEN** center crop to 640×640 with offsets (640, 220) SHALL occur inside native code
- **AND** display/render resolution SHALL keep camera aspect ratio on the preview surface

#### Scenario: Legacy App letterbox preference off

- **WHEN** `CameraConfig.isAiInputLetterbox640Enabled` is false (default after this change)
- **THEN** `LensGuardManager` SHALL forward full-frame I420 without `AiI420Letterbox640`
- **AND** detection overlays SHALL use full-frame box coordinates from native without client crop offset
