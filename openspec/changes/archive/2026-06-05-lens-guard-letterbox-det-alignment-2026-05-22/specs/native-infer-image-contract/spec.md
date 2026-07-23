## ADDED Requirements

### Requirement: nativeInferImageToJson box coordinates SHALL use full JPEG pixel space

When `nativeInferImageToJson` returns JSON with `code == 0`, each optional `boxes[]` entry SHALL use `x1`, `y1`, `x2`, `y2` in the pixel coordinate system of the input JPEG (full width and height), after the engine applies the same center-crop ROI and crop-offset restoration as live inference.

The App SHALL parse and render these coordinates on the full bitmap without applying crop offsets or letterbox adjustments in the client.

#### Scenario: Offline JPG at 1920x1080

- **WHEN** offline inference runs on a 1920×1080 sampled JPG
- **THEN** returned box coordinates SHALL align with stains when drawn on the full image
- **AND** `AiVisionFrameInference` SHALL store `imageWidth` and `imageHeight` matching that JPG
