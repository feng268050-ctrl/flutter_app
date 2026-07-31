## ADDED Requirements

### Requirement: Offline OpenCV stain JPG command

The AI daemon cmd channel SHALL accept `offline_infer_opencv_stain_jpg` with `image_path` and optional `output_dir`, returning an ack that includes `summary_json` on success. The App supervisor SHALL expose a Dart API for this command used by process-video sampling.

#### Scenario: Offline JPG infer ack

- **WHEN** the App sends `offline_infer_opencv_stain_jpg` with a readable JPEG path
- **THEN** the daemon MUST respond with an ack whose `ok` reflects analysis success
- **AND** on analysis completion MUST include `summary_json` for overlay mapping
