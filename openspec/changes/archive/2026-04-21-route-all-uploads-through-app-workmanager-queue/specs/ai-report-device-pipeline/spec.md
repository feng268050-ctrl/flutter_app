## ADDED Requirements

### Requirement: App-side ai-report uploads SHALL run through persistent WorkManager queue

For device-side product behavior, AI image uploads to `POST /v1/devices/:sn/ai-report` SHALL be initiated by App queue enqueue (`AiUploadCoordinator.enqueue` or equivalent queue API), and the actual HTTP execution SHALL be performed by the persistent WorkManager drain worker. Any direct HTTP call path outside this queue (for example ad-hoc curl/manual POST) SHALL NOT be treated as compliant App pipeline behavior.

#### Scenario: Queue entry drives upload worker

- **WHEN** an AI failure sample is produced by the app pipeline
- **THEN** the app SHALL persist task metadata into `files/ai_upload/...` queue layout and SHALL rely on WorkManager drain to execute the upload request

#### Scenario: Manual direct POST is non-normative for app pipeline validation

- **WHEN** a developer manually posts an image to `/v1/devices/:sn/ai-report` outside the app queue path
- **THEN** that request MAY prove network/server reachability but SHALL NOT be accepted as evidence that app queue behaviors (retry, cleanup, state transitions) are working
