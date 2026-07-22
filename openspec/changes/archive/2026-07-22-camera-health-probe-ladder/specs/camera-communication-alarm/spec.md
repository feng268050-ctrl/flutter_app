## ADDED Requirements

### Requirement: C002 health probes must not displace MediaMTX stream clients

Camera communication C002 SHALL continue to follow HAL `IpCameraHealth` only. Probe implementations used to drive that health MUST NOT steal the camera’s exclusive `/PR0` or `/PR1` consumers from the product MediaMTX upstream. A false unhealthy caused by the probe itself competing for PR0/PR1 is a defect.

#### Scenario: Probe under live relay does not force C002

- **WHEN** MediaMTX is successfully relaying camera PR0 (or PR1)
- **AND** the camera host remains reachable
- **AND** HAL health probing is running
- **THEN** C002 MUST NOT rise solely because the health probe opened a competing PR0/PR1 session
