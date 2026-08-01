## 1. HAL — Auto Join

- [x] 1.1 Extend `WifiSavedNetwork` with auto-join (or disabled) and map it in `savedNetworks()` / wpa D-Bus list
- [x] 1.2 Add `WifiController.setAutoJoin(ssid, enabled)` (Linux: SetNetwork disabled + SaveConfig; stub + tests)
- [x] 1.3 Unit-test leave/list helpers for Auto Join persistence shape

## 2. HAL — DNS Automatic / Manual

- [x] 2.1 Extend `WlanIpv4Config` (or adjacent model) with `dnsMode` + `dnsServers` list; keep pref serialize backward compatible
- [x] 2.2 Update `NetworkdIpv4Apply.renderNetworkFile` for Manual DNS under DHCP (`UseDNS=no` + `DNS=`) and Automatic clear-override
- [x] 2.3 Wire Linux `getIpv4Config` / `setIpv4Config` (or documented getter/setter) to apply multi-server DNS on wlan0 only
- [x] 2.4 Unit-test networkd render strings for Automatic vs Manual DNS × DHCP/static

## 3. App — Wireless Network list

- [x] 3.1 Add pure partition helper (My Networks vs Other Networks) using `savedNetworks()` + scan; cover with unit tests
- [x] 3.2 Restructure `WifiSettingsPage` into switch/connected, My Networks, Other Networks (Bluetooth-style section labels)
- [x] 3.3 Add l10n keys for My Networks / Other Networks (and empty states if needed); run `make l10n`

## 4. App — Wi-Fi Details regroup + inline edit

- [x] 4.1 Regroup `WifiDetailsPage`: Auto Join (no header), IPv4 Address, DNS, others + Forget
- [x] 4.2 Implement Configure IP Automatic/Manual with Date & Time-style Manual row editing → HAL apply
- [x] 4.3 Implement Configure DNS Automatic/Manual, DNS Servers list, plus-to-add (and remove) when Manual
- [x] 4.4 Bind Auto Join switch to HAL for current SSID
- [x] 4.5 Remove primary navigation to `WifiIpSettingsPage`; delete or stop shipping that page; update Demo / tests
- [x] 4.6 Add remaining l10n (Configure IP/DNS, Automatic/Manual, Auto Join, section headers); `flutter analyze` on touched paths

## 5. Verification

- [x] 5.1 Host: HAL unit tests + App partition / analyze
- [x] 5.2 Device smoke after `make build-app` / `make push-app`: My/Other lists, Auto Join, Manual IP, Manual DNS add, reboot prefs

## 6. Multi-profile connect (My Networks real)

- [x] 6.1 Stop `RemoveAllNetworks` on connect; replace only matching SSID; restore sibling Auto Join after SelectNetwork
- [x] 6.2 Same restore path for `selectSaved`; unit-test `WifiMultiProfilePolicy`; update design/spec comments
