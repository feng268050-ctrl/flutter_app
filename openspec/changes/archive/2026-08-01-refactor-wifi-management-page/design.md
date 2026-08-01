## Context

Wireless Network UI today (`WifiSettingsPage`) shows (1) WLAN switch + connected row and (2) a single unlabelled scan list. Details (`WifiDetailsPage`) is one flat read-only group plus buttons into `WifiIpSettingsPage`. HAL already exposes `savedNetworks()`, `forget`, and a single `WlanIpv4Config` (DHCP/static with one DNS string). Date & Time Settings is the interaction reference: Automatic off → rows become tappable and apply immediately. Bluetooth Settings already uses a section label + group pattern for “Other Devices.”

Constraints: Flutter 3.24.4; CyberUI Settings chrome; AppLocalizations; wlan0 only (no eth0); no NetworkManager. Connect keeps multiple saved SSIDs (My Networks); only one BSS is associated at a time via SelectNetwork.

## Goals / Non-Goals

**Goals:**
- Three-group Wi‑Fi list UX: control/connected → My Networks → Other Networks
- Details groups: Auto Join (no header), IPv4 Address, DNS, others
- Inline Manual IP/DNS editing on Details (Date & Time pattern); plus affordance to add DNS servers
- HAL support for Auto Join and DNS Automatic/Manual (multi-server) on wlan0
- Multi-profile save: connect adds/updates one SSID without wiping other remembered networks

**Non-Goals:**
- Concurrent associations to multiple BSSs / simultaneous dual-SSID links
- HTTP Proxy / IPv6 / Private Wi‑Fi Address (Apple extras)
- Redesigning Ethernet Configure IP beyond what Wi‑Fi already shares conceptually
- Android Wi‑Fi backends
- Changing factory/rootfs Wi‑Fi stack packages

## Decisions

### D1 — Partition scan vs saved on the list page

**Choice:** Pure UI helper (extend or sibling of `WifiApList`): My Networks = unique SSIDs from `savedNetworks()` (optionally enrich with current scan signal); Other Networks = scanned SSIDs whose SSID is not in the saved set; exclude current SSID from Other if already shown as connected in group 1 (same rule as today’s `WifiApList.available`).

**Why:** HAL already lists saved networks; no new persistence. Matches Bluetooth paired vs nearby.

**Alternatives:** Only show saved SSIDs that are also in scan (rejects offline remembered networks) — worse for “My Networks.” Merge connected into My Networks only — rejected; keep connected in group 1 for parity with current / Android-like “current network” chrome.

### D2 — Details absorbs IP Settings

**Choice:** Primary editing lives on `WifiDetailsPage`. Remove navigation to `WifiIpSettingsPage` as the primary path; delete the page or keep only if Demo still references it (prefer delete + update Demo).

**Why:** User-requested iOS-style single Details surface; avoids two sources of truth for mode/fields.

**Alternatives:** Keep IP Settings as a sub-page opened from Configure IP — rejected (extra hop vs Date & Time inline).

### D3 — Configure IP labels map to existing modes

**Choice:** UI strings **Automatic** / **Manual** map to `WlanIpv4Mode.dhcp` / `staticMode`. Segmented control or nav picker consistent with CyberUI on other settings; prefer `CyberSegmentedControl` or two-option row matching existing Settings patterns. When Manual, IP / Subnet / Gateway rows are `SettingsNavRow` (tappable → CyberIME dialog → `setIpv4Config`). When Automatic, those rows show live link values and are non-editable (like Date & Time when Automatic sync is on).

**Why:** Reuses HAL path; only label/UX change.

### D4 — DNS mode is first-class and independent of IP mode

**Choice:** Extend wlan IPv4 preference model with `dnsMode` (`automatic` | `manual`) and `dnsServers` (`List<String>`, persist as space- or comma-joined in existing pref file for migration). Automatic: networkd DHCP `UseDNS=yes` and omit static DNS lines (or clear manual DNS). Manual: write `DNS=` entries and for DHCP mode set `UseDNS=no` so lease DNS does not override. Plus button appends a server via CyberIME; each server row removable when Manual.

**Why:** Matches requested DNS group; today’s single `dns` field only applies in static mode and cannot express Automatic while Manual IP (or vice versa).

**Alternatives:** Keep DNS only under static IP — rejected by product request. Separate DNS-only config file — unnecessary vs extending `WlanIpv4Config` serialize format with new keys (`dns_mode`, `dns=` multi).

### D5 — Auto Join via wpa `disabled`

**Choice:** Extend `WifiSavedNetwork` with `autoJoin` (true when network not disabled). Add `WifiController.setAutoJoin(ssid, enabled)` → D-Bus SetNetwork `disabled` 0/1 + SaveConfig. Details switch binds to the currently associated SSID’s saved entry; if no matching saved network, treat as on and persist on first toggle by updating that network id.

**Why:** Standard wpa semantics for “don’t auto-reconnect.”

**Alternatives:** App-only flag in prefs — rejected (would not survive connect policy / reboot wpa behavior).

### D6 — Section chrome

**Choice:** Use `SettingsSectionHeader` (or Bluetooth-style uppercase label padding) for **My Networks**, **Other Networks**, **IPv4 Address**, **DNS**, and **others** (localized). Auto Join sits in a headerless `SettingsGroup` alone (or first group with only the switch).

**Why:** Matches Ethernet “Configure IP” and Bluetooth “OTHER DEVICES” patterns already in-tree.

### D7 — Apply timing

**Choice:** Mode switches and field edits apply immediately via HAL (Date & Time), not a bottom Confirm button on Details. Show busy/error inline on failure.

**Why:** User cited Date & Time; removes Apply-only flow from IP Settings.

## Risks / Trade-offs

- [DHCP + manual DNS needs networkd drop-in change] → Extend `NetworkdIpv4Apply.renderNetworkFile` with UseDNS=no + DNS=; unit-test render strings; verify on device with `resolvectl` / link DNS.
- [Auto Join D-Bus property availability] → Confirm `fi.w1.wpa_supplicant1.Network` Properties include `Disabled`; fall back to CLI `set_network` if needed.
- [Saved list empty until first connect] → My Networks group still renders empty state; do not invent fake rows.
- [Breaking Details UX / Demo] → Update Demo Wi‑Fi section and any tests that push `WifiIpSettingsPage`.
- [Multi DNS vs single string consumers] → Keep serializer backward compatible: old `dns=` single value → one-element list + infer manual when non-empty under static.

## Migration Plan

1. Ship HAL model + networkd/wpa APIs behind existing controller interface; stub controller updated for tests.
2. Ship Details regroup + inline editors; stop linking IP Settings.
3. Ship list My Networks / Other Networks + l10n.
4. Device smoke: save two SSIDs, toggle Auto Join, Manual IP, Manual DNS add/remove, reboot persistence.
5. Rollback: revert App UI alone still works with old HAL if new keys ignored; prefer coordinated App+HAL push via `make build-app` / `push-app`.

## Open Questions

- Exact English/Chinese copy for section headers (**My Networks** / **Other Networks** / **IPv4 Address** / **DNS** / **others**) — default to user-provided English; localize in ARBs during implement.
- Whether “others” header is visible or only an unlabeled trailing group — default **visible localized header** for consistency with IPv4/DNS unless design review prefers unlabeled.
- Max DNS servers (suggest 3, iOS-like) — default cap at 3 in UI.
