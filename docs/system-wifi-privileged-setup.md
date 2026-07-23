# System WiFi Privileged Setup

This module uses privileged `WifiManager` APIs for silent connect/disconnect/forget.
To make it work in production, the app must run as a privileged system app.

## Prerequisites

- App manifest declares `android.permission.NETWORK_SETTINGS`.
- APK is platform-signed (for this project, the signing key is `platform.jks`).
- APK is installed in privileged app path (for example `/system/priv-app/<app>/`).
- A privileged permission allowlist XML grants `NETWORK_SETTINGS` to this package.

## Runtime expectation

- Privileged build: WiFi operations run fully in-app without suggestion API/system approval UI.
- Non-privileged build: operations fail with explicit user-facing error, no fake success.

## Validation checklist

- Privileged build can connect to WPA/WPA2 network from app WiFi list.
- Privileged build can forget currently connected network from WiFi details page.
- Privileged build does not launch `ACTION_WIFI_ADD_NETWORKS` or suggestion prompts.
- Non-privileged build shows actionable failure message for connect/forget attempts.
- No crash/regression in WiFi list rendering and WiFi details page.
