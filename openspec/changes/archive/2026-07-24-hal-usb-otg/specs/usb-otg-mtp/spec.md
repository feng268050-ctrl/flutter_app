## ADDED Requirements

### Requirement: MTP mode exposes userdata storage directory

When OTG **`mode=mtp`** is applied and the port is in peripheral role with host attachment as required by the MTP stack, the image SHALL run a USB **MTP** responder whose shared filesystem root is **`/userdata/storage`**. If that directory does not exist, the apply path SHALL create it before starting MTP. Access SHALL be **read-write**. The device-side directory MUST remain a normal mounted path (Android MTP model): the implementation MUST NOT require unmounting `/userdata/storage` solely to export via MTP.

#### Scenario: First apply creates storage dir

- **WHEN** `mode=mtp` is applied and `/userdata/storage` is missing
- **THEN** the directory is created and MTP can expose it

#### Scenario: Host can browse storage via MTP

- **WHEN** mode is `mtp`, the OTG cable is attached to a PC with an MTP client, and MTP has started
- **THEN** the host MTP client can list and read/write files under the exported storage root corresponding to `/userdata/storage`

### Requirement: MTP mutually exclusive with plug-ssh gadget

Entering **`mtp`** SHALL tear down USB plug-ssh / `g_ether` (or equivalent ECM debug gadget). Entering **`debug`** SHALL stop the MTP responder. Entering **`host`** SHALL stop both gadget functions so the UDC can operate as USB host.

#### Scenario: Switch from debug to mtp

- **WHEN** plug-ssh is active and the operator sets `mode=mtp`
- **THEN** `g_ether` / usb0 debug SSH is torn down and MTP is started

#### Scenario: Switch to host stops MTP

- **WHEN** MTP is active and the operator sets `mode=host`
- **THEN** the MTP responder is stopped and OTG host role can enumerate peripherals
