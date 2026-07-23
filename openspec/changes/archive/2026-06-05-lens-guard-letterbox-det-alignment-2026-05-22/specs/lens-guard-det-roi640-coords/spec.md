## ADDED Requirements

### Requirement: App SHALL push full-frame I420 without App-side crop or letterbox

The App SHALL pass I420 buffers to `nativePushFrame` at the decoded stream width and height (for example 1920×1080 or 1280×720). The App SHALL NOT center-crop, letterbox, or stretch frames to 640×640 before push in production builds.

The native engine SHALL perform center crop to 640×640, BGR→RGB, RKNN inference, post-processing (DFL, sigmoid, NMS), and add `crop_offset_x/y` so callbacks expose boxes in full-frame pixel space.

#### Scenario: Live stream at 1920x1080

- **WHEN** AI Vision forwards 1920×1080 I420 to Lens Guard
- **THEN** `nativePushFrame` SHALL receive `width=1920`, `height=1080`, and `data.length = width * height * 3 / 2`
- **AND** the App SHALL NOT pre-crop to the engine ROI (640, 220) in Java

#### Scenario: Live stream at 1280x720

- **WHEN** AI Vision forwards 1280×720 I420
- **THEN** `nativePushFrame` SHALL receive full-frame dimensions
- **AND** engine-internal crop offsets SHALL be `(w-640)/2` and `(h-640)/2` without App involvement

### Requirement: Pushed frames SHALL meet minimum 640 by 640 dimensions

Before calling `nativePushFrame`, the App SHALL ensure `width >= 640` and `height >= 640`. If either dimension is smaller, the App SHALL NOT push the frame for stain detection and SHOULD log a diagnostic warning.

#### Scenario: Sub-stream below 640 on one axis

- **WHEN** decoded I420 is 640×512
- **THEN** the App SHALL skip `nativePushFrame` for that frame (or equivalent guard)
- **AND** SHALL NOT rely on native inference for stain detection on that geometry

### Requirement: Detection box coordinates SHALL be full-frame pixels after engine crop offset restore

For `preview_det` and offline `nativeInferImageToJson` with `code == 0`, each `boxes[]` entry `x1,y1,x2,y2` SHALL be in the coordinate system of the full pushed frame or JPG. The engine SHALL have already applied crop offset restoration (training §3 / ROI640 parity).

The App SHALL draw overlays on the full preview or bitmap without adding crop offsets, letterbox pad remapping, or mapping boxes only within a center-640 sub-rectangle.

#### Scenario: Preview overlay on 1920x1080

- **WHEN** native returns `preview_det` boxes for a 1920×1080 stream
- **THEN** `AiVisionFragment` SHALL map coordinates across the full overlay view
- **AND** boxes outside the central 640×640 ROI SHALL still render correctly when stains appear in cropped-away regions (coordinates already full-frame)

#### Scenario: Offline JPG overlay

- **WHEN** offline JSON includes boxes for a sampled JPG
- **THEN** overlay normalization SHALL use the full JPG `imageWidth` and `imageHeight` only
- **AND** SHALL NOT apply client-side crop offset or letterbox inverse transform

### Requirement: App SHALL NOT recompute detection post-processing or stain level

The App SHALL consume `level`, `status`, and `message` from native. The App SHALL NOT run DFL, sigmoid, conf filter, NMS, or mask window aggregation in Java for production paths.

#### Scenario: Heavy stain callback

- **WHEN** `onCheckResult` reports `level >= 2`
- **THEN** the App MAY play alarm audio based on `message`
- **AND** SHALL NOT override `level` using client-side box filtering
