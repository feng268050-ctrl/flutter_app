## Context

Product HMI (`app/lws_hmi` → `/opt/hmi`, `hmi.service`) embeds a four-tab Settings shell that mixes platform controls with welding-only Advanced / Custom Home / cloud / peripheral pages. Multi-app Make supports non-HMI `APP=<id>` → `/opt/<APP>`. Platform direction is a separate **OS Settings** Flutter app sharing OEM `board_profile` + `cyber_hal`, not product gpio/modbus, on the same rootfs.

**SoT for roles:** [`docs/settings-apps-roles.md`](../../../docs/settings-apps-roles.md). **SoT for build/IA tables:** [`docs/os-settings-app-plan.md`](../../../docs/os-settings-app-plan.md).

## Goals / Non-Goals

**Goals:**

- Scaffold and ship `app/os_settings` → `/opt/os_settings` with CyberUI multi-card untitled frost IA (list→push; same layout landscape and portrait).
- Replace `factory_test` auto-include / verify / docs with **`os_settings`**.
- Mutual-exclusion lifecycle with HMI (`Conflicts=`, switch scripts, safe CLI).
- Copy vs migrate vs OS-only ownership per roles doc; Bluetooth Brand+Model alias; Operating System Secrets Seal; OS version probes; Ethernet Wi‑Fi-parity IPv4/DNS; UI Scale physical-1:1 semantics; Cloud Environment tier.
- HMI Common cleanup: remove migrated entries; regroup Date & Time / locale / Display+Sound+Camera; hide LED row.

**Non-Goals:**

- Factory Test / 产测 App; gpio/modbus in OEM rootfs pack.
- OS Settings as default desktop or dual Flutter clients on one seat.
- Moving Advanced / Custom Home / product Cloud services / camera business / peripheral OTA into OS Settings.
- `cyber_hal` Android backends; full `migrate-secrets` wizard in OS Settings.
- Writing product `textSize` or any OS Settings prefs into `common-settings.json`.
- Hard-coding design-density rematch when `ui_scale=1.0` (rejected).

## Decisions

### 1. App id and install prefix

| Item | Choice |
|------|--------|
| Directory / `APP=` | `os_settings` |
| Device path | `/opt/os_settings` |
| Second-app slot | Replaces planned `factory_test`; no `app/factory_test` |

### 2. Lifecycle: static unit + Conflicts + switch helpers

| Component | Behavior |
|-----------|----------|
| `os-settings.service` | **static** (no `WantedBy=multi-user.target`); `Conflicts=hmi.service` |
| `hmi.service` | Keep multi-user enable; `Conflicts=os-settings.service` |
| `os-settings-launch.sh` | Same preflight as `hmi-launch.sh`; `BUNDLE=/opt/os_settings` |
| `/usr/bin/os-settings` | Refuse if HMI active; `--stop-hmi` then foreground |
| `switch-to-os-settings` / `switch-to-hmi` | `systemctl start` peer (Conflicts stops the other) |
| Ctrl+C on CLI | Does **not** auto-start HMI |

### 3. HMI entry / OS Settings Exit

- HMI: Device Info → **Device SN 5×** → `switch-to-os-settings`; failure Toast, stay in HMI.
- OS Settings: status-bar leading **Exit** → `switch-to-hmi`.
- Seat switch MUST NOT tear down Wi‑Fi / Ethernet / Bluetooth / proxy / SSH.

### 4. OS Settings IA + chrome

Untitled frosted cards (names MUST NOT appear as section headers):

1. Basic Info: About → Operating System → Storage  
2. Network: Wi‑Fi → Ethernet → Bluetooth → Proxy → SSH → **Cloud Environment**  
3. Date & Time  
4. Locale: Country/Region → Language → Unit  
5. Display & Sound: Display → Sound → Power Mode  
6. Input: Keyboard → Mouse → USB OTG  

Chrome: frosted plates + `SettingsNavRow` → push; same shell landscape/portrait.

### 5. Copy vs migrate vs OS-only

| Mode | OS Settings | HMI Settings |
|------|-------------|--------------|
| **Copy** | Full chrome/structure parity | Keep shortcut |
| **Migrate** | Own | Remove Settings entry (+ Demo orphans) |
| **OS-only** | Own | No Settings entry (may still **read** HAL) |

**Copy:** About identity, Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display (brightness / auto-sleep / wallpaper), Sound volume.  
**Migrate:** Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG, **Power Mode**.  
**OS-only:** UI Scale, Cloud Environment, About/OS/Storage inventory depth, Secrets Seal row.

Keyboard Apply restarts **`os-settings.service`**, never implicitly `start hmi`.

### 6. Ethernet = Wi‑Fi Details interaction

- First group: Ethernet **switch** + **cable link** status under it (not a separate top-level section).
- Shared **IPv4 Address** + **DNS** groups (Automatic/Manual segmented control; Manual → inline IME edit / DNS add) — abstract/reuse with Wi‑Fi Details (`SettingsIpv4DnsGroups` or equivalent).
- Others: MAC, link speed.
- **Rejected:** “Configure IP” group that navigates to DHCP vs Manual as a separate interaction.

HAL: `EthIpv4Config` supports `dnsMode` / `dnsServers` alongside address mode; persist under existing eth IPv4 prefs.

### 7. UI Scale semantics (`display.conf` `ui_scale`)

- Default / identity: **`ui_scale=1.0` means physical 1:1** — `matchEmbedderDensity` MUST NOT apply FittedBox rematch (simulator included).
- Non-`1.0` values are a **pure multiplier** on the embedder MediaQuery.
- Written only from **OS Settings** Display; both seats read and apply.
- Independent of HMI product **Text size** (`common-settings.json` `textSize`).
- Host/QEMU: operators **manually** set ~**113%** (`≈1.13`) when approximating the former ynh960 hard-coded rematch (~`1.358×1280/1536`). MUST NOT hard-code that factor in App code.

### 8. Persistence boundary

| Store | Owner | Used by OS Settings? |
|-------|-------|----------------------|
| `/var/lib/hal/*.conf` + network/BT paths | HAL / system | Yes (primary) |
| `/var/lib/network/cloud.conf` | Shared cloud API env tier (`environment_tier`); HAL origin catalog/probe uses this | Yes (Cloud Environment page) |
| `/var/lib/hmi/common-settings.json` | HMI `textSize` only | **No** |

Leftover JSON `language` / `unit` / `country` MUST be ignored; locale SoT is `locale.conf`.

### 9. HMI Common Settings IA (product subset)

Order of untitled cards:

1. Network (Wi‑Fi, Proxy, Cloud services)  
2. **Date & Time** (before Country/Region)  
3. Locale (Country/Region, Language, Unit)  
4. **Display + Sound + Camera** (one card)  
5. Misc  

- **RGB LED** nav row **hidden** (implementation may retain page code behind a flag); not deleted from the product codebase in this change.
- Power Mode / Ethernet / BT / SSH / Keyboard / Mouse / USB OTG absent.

### 10. Display / Sound split depth

| Topic | HMI | OS Settings |
|-------|-----|-------------|
| Brightness / auto-sleep / wallpaper | Yes | Yes |
| UI Scale | No | Yes |
| Text size | Yes (`common-settings.json`) | No |
| Volume | Yes | Yes |
| Sound effect picker + MP3 install | Yes | No (volume only; uses HMI-installed sample) |

### 11. HAL extensions for OS + Storage

- PlatformVersions / SysInfo probes; soft-fail → `—`.
- Secrets Seal: `software` \| `op-tee` read-only.
- OS Settings loads OEM `BoardProfile` only — **no** product gpio/modbus.

### 12. Bluetooth alias

`setAlias("{Brand} {Model}")` when stack starts / identity readable; safe placeholder if incomplete.

### 13. Build / verify / docs

`ensure-rootfs-apps` + `verify-rootfs-overlay` for `/opt/os_settings`; AGENTS / README / make-commands updated.

### 14. Phased delivery

A scaffold + lifecycle → B Basic Info → C Network → D Date/locale → E Display/Sound/Power → F Input migrate → G cleanup → **H follow-ups** (Ethernet IPv4/DNS parity, Power Mode migrate, HMI Common regroup, UI Scale identity, Cloud Environment).

## Risks / Trade-offs

- [Two Flutter clients fight the seat] → Bidirectional `Conflicts=`.
- [Copied pages drift] → Shared chrome/packages when practical; copy-first OK.
- [ui_scale=1.0 looks “smaller” on boards that relied on old rematch] → Document ~113% for parity; factory may bake `ui_scale` per panel.
- [Language/Unit dual App; Power Mode OS-only] → Shared HAL; HMI re-reads on seat return.
- [Keyboard Restart starts wrong unit] → Restart OS Settings only.
- [common-settings.json confusion] → Explicit ban for OS Settings; textSize HMI-only.

## Migration Plan

1. Land scaffold + overlay; SSH `systemctl start os-settings` for bring-up.
2. Ship pages; migrate HMI removals after OS Settings parity.
3. Regroup HMI Common; hide LED; remove Power Mode entry.
4. Ethernet UX alignment + UI Scale identity without hard-coded rematch.
5. Rootfs `make build-rootfs` when `app/os_settings` exists; field via normal `upgrade`.
6. Rollback: omit HMI entry; leave `/opt/os_settings` unused.

## Open Questions

- Whether Phase G deletes the entire P2 Demo route — delete when empty; not a blocker.
- Whether RGB LED is permanently removed later vs re-shown — currently **hidden only**.
- Optional Home-page OS Settings shortcut — not used; entry remains Device SN 5×.
