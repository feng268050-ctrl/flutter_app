## MODIFIED Requirements

### Requirement: Temporal summary drives offline AI Vision lens alerts only

Production weld **L001** alerts MUST continue to ignore offline stain detect messages per existing `StainDetectAlertMapper.isOfflineStainDetectMessage` rules. Live-weld heavy contamination SHALL trigger immediate L001 presentation per `production-lens-det-dirty-alerts`, not a deferred post-laser-stop queue.

#### Scenario: Offline process video summary does not arm production L001 alone

- **WHEN** temporal box reduction on process video yields a heavy summary
- **AND** the event is classified as offline / non-live-weld
- **THEN** production L001 pending MUST NOT be set solely from that event
- **AND** AI Vision MAY still show its own lens dirty dialog
