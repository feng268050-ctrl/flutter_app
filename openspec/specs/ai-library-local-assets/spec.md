# ai-library-local-assets Specification

## Purpose
TBD - created by archiving change ai-library-optimization. Update Purpose after archive.
## Requirements
### Requirement: ai-library directory SHALL have committed README

The repository MUST include `ai-library/README.md` (committed even though `ai-library/` binary contents remain gitignored). The README MUST document: required local files for `make ai`, auto-generated cache directories that MUST NOT be committed, and common build commands including `make ai` and `SKIP_RKNN_CONVERT=1 make ai`.

#### Scenario: Required ONNX input documented

- **WHEN** a developer clones the repo and reads `ai-library/README.md`
- **THEN** they MUST find `det_raw_head.onnx` listed as required for RKNN conversion
- **AND** MUST find the output path for `det_raw_head.rknn` after conversion

#### Scenario: Cache directories marked do-not-commit

- **WHEN** the README describes `_cache/calib/` and `_cache/onnx2rknn/`
- **THEN** it MUST state these are auto-generated and MUST NOT be committed to git

