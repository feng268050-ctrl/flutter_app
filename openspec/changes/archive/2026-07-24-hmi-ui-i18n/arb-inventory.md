# ARB key inventory (implemented HMI ↔ lws-ui)

Generated during `hmi-ui-i18n` apply. Parent catalogs: ~493 message keys in `app_en.arb` / `app_zh.arb`.

| HMI surface | lws-ui namespaces copied | Notes |
|-------------|--------------------------|-------|
| Settings shell tabs | `device_information`, `common_settings`, `advanced_settings`, `custom_home_page` + HMI `settingsTab*` | Migrated |
| Language / Units | `language_*`, `unit_*`, `mm_unit`, `in_unit` + HMI BCP-47 extras | Migrated; + `zh-TW` endonym |
| Common Settings groups | `common_settings_group_*`, network/wifi/bt/proxy | Migrated chrome; some sub-page body strings still EN |
| Advanced Settings | `advanced_settings*`, `advanced_setting_*` | Section headers/hints migrated; some threshold titles still EN |
| Device Info | `device_*`, firmware/OTA keys | Rows partially migrated |
| Wi‑Fi / Bluetooth / proxy | `wifi_*`, `bluetooth_*`, `http_proxy_*` | Titles migrated; deep dialog copy partial |
| Boot self-check | `boot_self_check_*` + shared status labels | Migrated |
| Monitor | `device_monitor_*`, `work_title`, `machine_title`, `alarm_title` + HMI gauge labels | Migrated |
| Home | settings/monitor/AI + mode labels | Migrated; Text overlays for Quick/Engineer |
| Alarms | `*_alarm_title` / `*_alarm_content` | `ProductAlarmL10n`; few codes missing ARB |
| Process library | HMI `homeQuickModeLabel` / `homeEngineerModeLabel` | Titles only in this slice |

HMI-only keys (no lws-ui counterpart) live in the same parents (e.g. `languageAppliesToUi`, `offLabel`, USB OTG mode labels).
