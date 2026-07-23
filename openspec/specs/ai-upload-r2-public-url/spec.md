## Purpose

Define the **normative object key** and optional **public HTTPS URL** construction for AI detection report images stored in Cloudflare R2 via the Worker `/v1/devices/:sn/ai-report` flow, as documented in repository `upload.md`. This is distinct from process-video presigned PUT (`device-r2-presigned-upload`).

## Requirements

### Requirement: Normative AI R2 object key

The object key for AI-uploaded images written by the Worker SHALL be:

`uploads/ai/{staging|release}/{type}/{yyyy-mm-dd}/{sn}/{uuid_filename}`

where:

- `{staging|release}` reflects the Worker deployment channel (not a client-supplied environment flag).
- `{type}` is the detection category from the upload API (currently `0` for the unified failure class).
- `{yyyy-mm-dd}` is the calendar date path segment, equivalent to formatting the date as `yyyy-MM-dd` (for example `2026-04-15`).
- `{sn}` is the device serial number.
- `{uuid_filename}` is a unique filename assigned by the Worker.

#### Scenario: Staging example key shape

- **WHEN** a staging Worker stores a failure-class image for SN `SN001` on `2026-04-15`
- **THEN** the object key SHALL be of the form `uploads/ai/staging/0/2026-04-15/SN001/{uuid_filename}`

### Requirement: Public HTTPS URL for development verification

Project documentation SHALL describe that, when the R2 bucket is bound to a public read host (for example `https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev`), a browser-readable URL MAY be formed as: public base host + `/` + object key, with no double slash and no trailing slash on the host.

#### Scenario: Full URL matches key

- **WHEN** the base host is `https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev`
- **AND** the object key is `uploads/ai/staging/0/2026-04-15/SN001/550e8400-e29b-41d4-a716-446655440000.jpg`
- **THEN** the full URL SHALL be `https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev/uploads/ai/staging/0/2026-04-15/SN001/550e8400-e29b-41d4-a716-446655440000.jpg`

### Requirement: Environment segment is not client-trusted

The path segment after `uploads/ai/` SHALL be either `staging` or `release` based on server-side deployment, not on an untrusted client field.

#### Scenario: Staging prefix

- **WHEN** the staging Worker writes the object
- **THEN** the key SHALL begin with `uploads/ai/staging/`

### Requirement: Worker D1 row metadata aligns with upload.md including model

Documentation and integration reviews SHALL treat `upload.md` section 5.2 as authoritative for D1 fields written by the Worker for `ai-report`, including `model` alongside `sn`, `type`, and `object_key`, consistent with the multipart `model` field in section 3.3.

#### Scenario: Model is persisted server-side

- **WHEN** a successful `ai-report` is processed by the Worker
- **THEN** D1 SHALL be capable of storing the `model` value (`lens` or `metal`) as listed in `upload.md` section 5.2
