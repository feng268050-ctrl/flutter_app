## 1. Board helper and wipe contract

- [ ] 1.1 Add `/usr/libexec/board/factory-reset.sh` (selective wipe; preserve `properties.ini`; never touch VS 1/20/21/22/23; stop seats; sync; reboot)
- [ ] 1.2 Wire `/usr/bin/factory-reset` via `post-build.sh`
- [ ] 1.3 Journal-log phases; fail closed when `/userdata` missing when required

## 2. Product HMI Settings (required user feature)

- [ ] 2.1 Add **恢复出厂设置** / Erase All Data in product HMI Settings with two-step confirm (user-facing copy: data/settings cleared; provisioning + cloud kept; no firmware rollback)
- [ ] 2.2 Invoke board helper on confirm; cancel is a no-op
- [ ] 2.3 Localize; update `docs/settings-apps-roles.md` as **HMI user feature** (not 产线)
- [ ] 2.4 `flutter analyze` / widget test for confirm/cancel when practical

## 3. Optional mirrors / platform hygiene

- [ ] 3.1 Optional: same control in OS Settings (same helper; not framed as 产线)
- [ ] 3.2 Align flash-time operator-prefs cleanup with wipe contract if touching flash scripts (preserve `properties.ini` + VS slots)
- [ ] 3.3 Do **not** add `make factory-reset` or host SSH wipe SOP

## 4. Docs

- [ ] 4.1 `docs/storage-layout.md`: user factory-reset vs upgrade/OTA vs flash; preserved `properties.ini` + VS 22

## 5. Verification

- [ ] 5.1 User path: HMI 恢复出厂设置 → operator prefs/DBs gone; `properties.ini` + ID 22/23/SN kept; no re-activation
- [ ] 5.2 Regression: `make upgrade` still preserves userdata
- [ ] 5.3 Confirm UX does not present the action as a 产线 procedure
