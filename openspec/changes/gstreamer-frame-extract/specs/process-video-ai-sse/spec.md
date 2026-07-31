## MODIFIED Requirements

### Requirement: Media-timeline sampling drives offline JPG infer

Process-video sessions SHALL sample at 500 ms intervals (first sample at 500 ms; 0 ms never sampled), extract a JPEG via the product **GStreamer frame-extract** path (rootfs GStreamer; not App-bundled ffmpeg), and invoke daemon `offline_infer_opencv_stain_jpg`. Results SHALL append to an in-memory timeline and fan out on the session SSE hub.

#### Scenario: Sample on grid

- **WHEN** the playback clock reaches a new sample bucket
- **THEN** the session MUST extract one frame via GStreamer frame-extract and request offline JPG infer
- **AND** publish a `running` event with that sample's media timestamp
