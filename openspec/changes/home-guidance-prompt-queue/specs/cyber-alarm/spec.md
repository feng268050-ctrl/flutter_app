## MODIFIED Requirements

### Requirement: Warn presentation gated during boot self-check

While product boot self-check is active, the `cyber_alarm` coordinator MUST NOT call the presentation port to show new modal warn dialogs for Modbus-backed **or non-Modbus** alarm codes (gate supplied by App). Historical insert MAY still occur per existing package policy. After self-check completes, subsequent rising edges SHALL present normally via the App **global prompt queue**, and `flushPresentation` MAY enqueue parked eligible episodes onto that queue. Warn presentation MUST NOT be held for Home guidance / network / cloud enrollment after self-check.

The coordinator MUST NOT maintain a separate modal presentation FIFO for dialogs; serialization of visible prompts SHALL be owned by the App global prompt queue. A non-UI pending set for gate-parked codes MAY remain.

#### Scenario: Suppressed during self-check

- **WHEN** boot self-check overlay is active
- **AND** an alarm attribute becomes true
- **THEN** no modal warn dialog is shown for that onset
- **AND** after self-check ends, a later new rising edge or flush MAY show a dialog via the global prompt queue without waiting for guidance enrollment

#### Scenario: Camera C002 uses the same gate

- **WHEN** boot self-check presentation is gated
- **AND** camera health reports unhealthy
- **THEN** no C002 modal SHALL be shown via the presentation port
- **AND** gating SHALL use the same App `WarnGate` as Modbus-backed codes

#### Scenario: No second warn modal queue

- **WHEN** multiple alarm codes become eligible for presentation after the gate opens
- **THEN** their dialogs SHALL be ordered by the App global prompt queue
- **AND** the coordinator MUST NOT run a parallel `_showQueue` modal drain
