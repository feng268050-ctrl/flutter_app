## ADDED Requirements

### Requirement: Event-driven USB HID keyboard presence

The system SHALL expose USB HID keyboard **presence** (1 mm host expansion path; not Micro-USB OTG gadget) via a reusable probe/monitor API that emits a Stream (or change notifications) when keyboards appear or disappear. Linux SHALL use **udev** (or equivalent kernel device events) as the primary source. Periodic Timer scans of `/dev/input` via Process or busy directory listing MUST NOT be the primary presence path.

#### Scenario: Plug updates presence

- **WHEN** a USB HID keyboard is plugged into the host expansion path while the monitor is subscribed
- **THEN** presence status becomes present/available without a Demo tap

#### Scenario: Unplug updates presence

- **WHEN** that keyboard is unplugged
- **THEN** presence status becomes absent without a Demo tap

#### Scenario: Initial snapshot on subscribe

- **WHEN** a listener subscribes while a keyboard is already present
- **THEN** the first event/snapshot reports present
