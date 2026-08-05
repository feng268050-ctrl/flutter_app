## 1. Host TSV / table contract

- [x] 1.1 Change device-table producers (`flash-usb.sh`, `usb-ssh-devices.sh`, `ssh-devices.sh`, `emulator-devices.sh`, Windows PowerShell path) to emit MODE / SN / LocationID / IFACE / IP / USB (drop ChipID field)
- [x] 1.2 Update `device_table_print` / parsers / consumers that assume a ChipID column
- [x] 1.3 Update host tests that assert ChipID column or seven-field TSV (e.g. `scripts/tests/debug-app.test.sh`)

## 2. Selection: SN only

- [x] 2.1 Remove `device_select_chip_id` / `CHIP_ID=` matching from `usb-ssh-common.sh`, `device-target.sh`, `usb-ssh-devices.sh`, `ssh-devices.sh`, `flash-usb.sh`
- [x] 2.2 If `CHIP_ID=` is set, fail with a hint to use `SN=`
- [x] 2.3 Narrow `SN=` matching to the SN column only (keep LocationID / EMU special cases that already exist)
- [x] 2.4 Update `write-identity.sh`, `set-product-prop.sh`, `del-product-prop.sh` (and similar) to stop documenting/accepting `CHIP_ID=` as a selector

## 3. Identity probe (keep chip id underneath)

- [x] 3.1 Keep remote SN probe + `read-serial --chip-id` for SN fallback and HAL; stop returning ChipID as a separate host-table field (probe may still compute chip internally for fallback)
- [x] 3.2 Confirm HAL `ProductInfo.chipId` / `SysInfoSnapshot.chipId` / KEK paths unchanged

## 4. Docs

- [x] 4.1 Update README, AGENTS.md, `docs/make-commands.md`, `docs/hal-portability.md`, Makefile `help` — remove ChipID column and `CHIP_ID=` operator guidance; document SN-only selection

## 5. Verification

- [x] 5.1 Run affected host script tests
- [x] 5.2 Manual: `make devices` shows no ChipID; Loader / USB-SSH rows show SN only; `CHIP_ID=…` fails with hint; `SN=…` still selects
