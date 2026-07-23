## MODIFIED Requirements

### Requirement: OpenCV stain detect one-shot inference mirrors RKNN entry points

The App SHALL expose OpenCV stain detect through one-shot APIs:

- `AiManager.opencvStainDetectFromI420` for direct I420 buffers (live PR1, AI Vision live, process video)
- `AiManager.opencvStainDetectFromJpg` for offline image paths

Each call SHALL invoke the corresponding `NativeBridge.nativeOpencvStainDetectFrom*` JNI on a background executor, using the active **`opencvStainDetectHandle`** from `AiManager`, and SHALL NOT block the UI or Modbus threads.

#### Scenario: I420 live sample invokes native OpenCV stain detect

- **WHEN** a sampled I420 frame is submitted to `opencvStainDetectFromI420`
- **AND** `AiManager.isOpencvStainDetectSessionActive()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromI420` with a non-zero session handle and a non-empty `outputDir`
- **AND** MUST return a parsed `OpencvStainDetectResult` on completion

#### Scenario: Offline JPG invokes native OpenCV stain detect

- **WHEN** `opencvStainDetectFromJpg` is called with a readable JPEG path
- **AND** `AiManager.isOpencvStainDetectSessionActive()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromJpg`
- **AND** MUST set `source` to `StainDetectSource.OFFLINE` (`offline_stain_detect`)

#### Scenario: OpenCV session not available

- **WHEN** `AiManager.isOpencvStainDetectSessionActive()` is false
- **THEN** OpenCV stain detect MUST fail fast with `success == false`
- **AND** MUST NOT invoke native OpenCV stain detect JNI
